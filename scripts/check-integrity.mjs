#!/usr/bin/env node
/**
 * MasterMind integrity check — makes it impossible for the indexes to lie.
 * Zero deps. Exits 1 on any failure (CI-friendly). Run: `node scripts/check-integrity.mjs`.
 *
 * Verifies, per the project's own "a router that lies" warning (skills/README.md):
 *   1. every skills/<name>/ has a SKILL.md with valid frontmatter (name matches dir,
 *      description present & ≤1024 chars, only allowed keys — per the Agent Skills spec)
 *   2. skills/README.md lists exactly the skill dirs (no missing, no extra)
 *   3. no index (skills/README.md, README.md) cites a `mastermind-*` skill with no dir
 *   4. no broken brain-root / engineering / core / fields cross-references in the docs
 *   5. active-field.md declares a level
 *   6. help/SKILL.md's "<n> skills · <n> agents" header matches what actually ships
 *   7. every field-pack file (except field.md) carries `route_when`, and every pack
 *      ships field.md + audit-rules.md — otherwise the router skips it silently
 *   8. active-field.md's declared "Field pack:" points at a pack dir that exists and is
 *      well-formed (field.md + audit-rules.md, same bar as check 7)
 *   9. every SOURCE.md with a destructive re-vendor procedure carries a preserve list, every
 *      listed path exists, and the list and the procedure agree in both directions
 *  10. .githooks/ (this repo's live guards) matches skills/quarantine/assets/ (what we ship),
 *      so a security fix cannot land in one copy and leave the other vulnerable
 *  11. every published ABOUT.md reconciles with the instructions it describes: it pairs with a
 *      real SKILL.md / agent file, carries the frontmatter the library pages render, states when
 *      the thing fires, names only capabilities that exist, and does not contradict that file
 *      about how it is invoked
 */
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join, resolve } from 'node:path'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const ALLOWED_FM_KEYS = new Set(['name', 'description', 'license', 'allowed-tools', 'metadata'])
const errors = []
const fail = (m) => errors.push(m)
const read = (p) => readFileSync(join(ROOT, p), 'utf8')
// The isolated per-project brain ships the engine, not the repo: no README.md, no
// .claude-plugin/, no cli/. `init` runs this script from inside that brain, so a hard read of a
// repo-only file crashed the very check it was told to run. Absent means "not applicable here";
// present means checked exactly as before, so the dev gate is unchanged.
const readIfPresent = (p) => (existsSync(join(ROOT, p)) ? readFileSync(join(ROOT, p), 'utf8') : null)

// --- parse the simple `key: value` frontmatter block at the top of a file ----
function frontmatter(text) {
  const m = text.match(/^---\n([\s\S]*?)\n---/)
  if (!m) return null
  const fm = {}
  for (const line of m[1].split('\n')) {
    const km = line.match(/^([A-Za-z][\w-]*):\s?(.*)$/)
    if (km) fm[km[1]] = km[2]
  }
  return fm
}

// --- 1. skills exist & have valid frontmatter --------------------------------
const skillDirs = readdirSync(join(ROOT, 'skills'), { withFileTypes: true })
  .filter((d) => d.isDirectory())
  .map((d) => d.name)
  .sort()

for (const dir of skillDirs) {
  const rel = `skills/${dir}/SKILL.md`
  if (!existsSync(join(ROOT, rel))) {
    fail(`skill "${dir}" has no SKILL.md`)
    continue
  }
  const fm = frontmatter(read(rel))
  if (!fm) {
    fail(`${rel}: missing/malformed frontmatter`)
    continue
  }
  for (const k of Object.keys(fm)) {
    if (!ALLOWED_FM_KEYS.has(k)) fail(`${rel}: unexpected frontmatter key "${k}"`)
  }
  if (fm.name !== dir) fail(`${rel}: name "${fm.name}" ≠ directory "${dir}"`)
  if (!fm.description) fail(`${rel}: missing description`)
  else if (fm.description.length > 1024) fail(`${rel}: description > 1024 chars`)
}

// --- 2 & 3. index parity -----------------------------------------------------
// skills/README.md is the AUTHORITATIVE index: every skill dir must appear (incl. vendored).
// Parse the actual index ROWS, not a substring of the whole file: skill names like `qa`,
// `build`, `route`, `learn`, `debug`, and `report` are ordinary English words that appear in
// the surrounding prose, so `includes(dir)` passed even with the skill's row deleted — the
// exact drift this check exists to catch. Compare sets both ways so "no extra" is real too.
const skillsReadme = readIfPresent('skills/README.md') ?? ''
const listedSkills = new Set(
  [...skillsReadme.matchAll(/\[`([a-z0-9-]+)`\]\(\.\/([a-z0-9-]+)\/SKILL\.md\)/g)].map((m) => m[2])
)
for (const dir of skillDirs) {
  if (!listedSkills.has(dir)) fail(`skills/README.md: skill "${dir}" not listed (the index must be complete)`)
}
for (const listed of listedSkills) {
  if (!skillDirs.includes(listed)) fail(`skills/README.md: lists "${listed}" — no such skill dir`)
}
// The root README is a curated overview, not a complete index — it deliberately lists only
// some skills, so its completeness is NOT enforced (skills/README.md is the authoritative
// index, guarded above). What we do guard: no index cites a `mastermind-*` skill that has no
// dir. Only backticked refs count, so a URL slug like foglamp.dev/scan/mastermind-xyz is fine.
for (const file of ['skills/README.md', 'README.md']) {
  const text = readIfPresent(file)
  if (text === null) continue
  for (const m of text.matchAll(/`(mastermind-[a-z-]+)`/g)) {
    if (!skillDirs.includes(m[1])) fail(`${file}: lists "${m[1]}" — no such skill dir`)
  }
}

// --- 4. no broken cross-references in the docs --------------------------------
const docFiles = []
;(function walk(d) {
  for (const e of readdirSync(join(ROOT, d), { withFileTypes: true })) {
    if (e.name === 'node_modules' || e.name === 'lab' || e.name.startsWith('.git')) continue
    const p = `${d}/${e.name}`
    if (e.isDirectory()) walk(p)
    else if (e.name.endsWith('.md')) docFiles.push(p.replace(/^\.\//, ''))
  }
})('.')

const REF = /(?:~\/\.mastermind\/)?((?:engineering\/|core\/|fields\/)[\w./-]+\.md)/g
for (const f of docFiles) {
  for (const m of read(f).matchAll(REF)) {
    let ref = m[1]
    if (ref.startsWith('core/') || ref.startsWith('fields/')) ref = `engineering/${ref}`
    if (!existsSync(join(ROOT, ref))) fail(`${f}: broken reference → ${m[0]}`)
  }
}

// --- 5. active-field declares a level ----------------------------------------
// Match the explicit `**Level:** N` declaration, not "level N" anywhere — the "Level history"
// section always contains old levels, so a loose match passed even with the real one deleted.
if (!/^-?\s*\*\*Level:\*\*\s*\d+/m.test(read('engineering/active-field.md'))) {
  fail('engineering/active-field.md: no current level declared (expected a `**Level:** N` line)')
}

// --- 6. the help menu's headline counts are true ------------------------------
// help/SKILL.md prints "<n> skills · <n> agents" to the user. Hand-syncing it on every
// skill addition guarantees it eventually lies, so assert it instead of trusting it.
const agentCount = readdirSync(join(ROOT, 'agents'), { withFileTypes: true })
  .filter((e) => e.isFile() && e.name.endsWith('.md')).length
const helpHeader = read('skills/help/SKILL.md').match(/(\d+)\s+skills\s+·\s+(\d+)\s+agents/)
if (!helpHeader) {
  fail('skills/help/SKILL.md: no "<n> skills · <n> agents" header line to verify')
} else {
  const [, s, a] = helpHeader
  if (+s !== skillDirs.length) fail(`skills/help/SKILL.md: claims ${s} skills, found ${skillDirs.length}`)
  if (+a !== agentCount) fail(`skills/help/SKILL.md: claims ${a} agents, found ${agentCount}`)
}

// --- 7. every field-pack knowledge file is routable ---------------------------
// build-router.mjs silently skips any field file without `route_when`, so a pack that
// forgets it produces zero router nodes and no warning. This must mirror the router's
// view exactly, so it uses the same `frontmatter()` anchoring (string-start `---`, tag
// read from inside the block) rather than a looser text match — a check that disagrees
// with the thing it guards is worse than no check. It walks nested dirs because the
// router does too (`ui-ux-pro-max/SKILL.md` is a live node one level down).
//
// NON_ROUTABLE lists the docs that are deliberately unrouted: a pack's own table of
// contents and its provenance notes. It is an explicit allowlist so that adding a new
// unrouted doc is a decision someone makes, not something that happens by accident.
const NON_ROUTABLE = new Set(['field.md', 'SOURCE.md', 'README.md'])
const fieldsDir = join(ROOT, 'engineering', 'fields')
const packs = readdirSync(fieldsDir, { withFileTypes: true })
  .filter((d) => d.isDirectory())
  .map((d) => d.name)
  .sort()

const walkMd = (dir) =>
  readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walkMd(join(dir, e.name)) : e.name.endsWith('.md') ? [join(dir, e.name)] : []
  )

for (const pack of packs) {
  const packDir = join(fieldsDir, pack)
  const files = walkMd(packDir)
  const top = files.filter((p) => dirname(p) === packDir).map((p) => p.split('/').pop())

  if (!top.includes('field.md')) fail(`engineering/fields/${pack}/: no field.md (the pack's table of contents)`)
  if (!top.includes('audit-rules.md')) {
    fail(`engineering/fields/${pack}/: no audit-rules.md — code-reviewer would have no framework rules`)
  }
  for (const abs of files) {
    if (NON_ROUTABLE.has(abs.split('/').pop())) continue
    const rel = abs.slice(ROOT.length + 1)
    const fm = frontmatter(read(rel))
    if (!fm || !('route_when' in fm)) {
      fail(`${rel}: no \`route_when\` frontmatter — build-router.mjs will skip it silently`)
    }
  }
}

// --- 8. active-field.md points at a pack that actually exists -----------------
// The pointer is the one line that decides which pack loads at runtime. A stale or
// misspelled path passes every other check silently — check 4 only validates `.md`
// references, and check 7 only audits packs it finds on disk, never the one we claim to
// use — and the model then fails to load a field pack with no diagnostic at all.
// Keyed narrowly on the `- **Field pack:** \`<path>\`` bullet under "Current field", which
// is the file's only declarative statement of the active pack. Prose elsewhere mentions
// `engineering/fields/<name>/` as a placeholder and `_template` as an example; neither is a
// declaration, and neither matches this shape.
// Field-less is a valid state: MasterMind ships no pack (only _template), and `init` builds one
// per project. When "Current field" is **none** (or Level 0), there is deliberately no pack to
// point at — so a missing/backtick-less Field pack line is correct, not a failure. Only when a
// real field IS declared do we require the pointer to resolve to a pack on disk.
const activeField = read('engineering/active-field.md')
const fieldless =
  /Current field:\s*\*\*\s*none/i.test(activeField) || /^\s*[-*]\s*\*\*Level:\*\*\s*0\b/m.test(activeField)
const packRef = activeField.match(/^\s*[-*]\s*\*\*Field pack:\*\*\s*`([^`]+)`/m)
if (fieldless) {
  // no field by design — nothing to resolve
} else if (!packRef) {
  fail('engineering/active-field.md: no `- **Field pack:** `<path>`` line — nothing declares the active pack')
} else {
  const packPath = packRef[1].replace(/\/$/, '')
  if (!existsSync(join(ROOT, packPath)) || !statSync(join(ROOT, packPath)).isDirectory()) {
    fail(`engineering/active-field.md: field pack "${packRef[1]}" does not exist — the active field cannot load`)
  } else {
    for (const required of ['field.md', 'audit-rules.md']) {
      if (!existsSync(join(ROOT, packPath, required))) {
        fail(`engineering/active-field.md: active pack "${packRef[1]}" is missing ${required}`)
      }
    }
  }
}

// --- 9. a SOURCE.md preserve list is honored ----------------------------------
// A vendored dir's SOURCE.md documents a re-vendor that `rm -rf`s the directory, so any
// MasterMind-authored file in it survives only if it is named in that file's preserve list
// AND copied aside by the documented procedure. an earlier pass edited `data/motion.csv` — vendored,
// unlisted — and the edit would have been destroyed on the next re-vendor; human review
// caught it, no check did.
//
// We cannot diff against upstream offline, so this cannot detect "file X was edited but not
// listed" — the exact shape of that bug. What it CAN make impossible is the list rotting:
// a preserved path that was renamed or deleted, a listed path the procedure never copies
// aside, or a path the procedure copies aside that the prose never explains. Each of those
// breaks the re-vendor just as silently.
for (const rel of docFiles.filter((p) => p.endsWith('SOURCE.md'))) {
  const text = read(rel)
  const dir = dirname(rel)
  if (!/rm\s+-rf/.test(text)) continue // non-destructive procedure: nothing can be lost

  // the preserve list: backticked paths in the bullets that follow the "must survive" claim.
  const section = text.split(/^.*must survive.*$/im)[1]
  const listed = section
    ? [...section.split(/^#/m)[0].matchAll(/^\s*[-*]\s*\*\*`([^`]+)`\*\*/gm)].map((m) => m[1].replace(/\/$/, ''))
    : []
  if (!listed.length) {
    fail(`${rel}: re-vendor \`rm -rf\`s this directory but no preserve list found — expected bullets of the form "- **\`path\`** — why" after a line saying what must survive`)
    continue
  }
  // What the procedure actually rescues: paths in a `cp … $P/<path> … /tmp…` copy-aside line.
  // Both directions check against THIS set, not a loose "mentioned somewhere" — a path named
  // only in the later `diff` line isn't backed up.
  const rescued = [...text.matchAll(/^\s*cp\b[^\n]*?\$\{?P\}?\/([^"'\s]+)["']?\s+\/tmp\S*/gm)].map((m) =>
    m[1].replace(/\/$/, '')
  )
  for (const p of listed) {
    if (!existsSync(join(ROOT, dir, p))) fail(`${rel}: preserved path "${p}" does not exist — the re-vendor would restore nothing`)
    if (!rescued.includes(p)) fail(`${rel}: preserved path "${p}" is never copied aside by the re-vendor block — the list and the procedure have drifted`)
  }
  for (const p of rescued) {
    if (!listed.includes(p)) fail(`${rel}: re-vendor copies "${p}" aside but it is not in the preserve list — undocumented, so the next editor won't know it's ours`)
  }
}

// --- 10. the repo's own guards match the guards it ships ----------------------
// `.githooks/` is this repo's live guard; `skills/quarantine/assets/` is what we install for
// users. a fix landed in the shipped `pre-push` and left `.githooks/` stale, so
// the guard protecting this public repo kept the bug the CHANGELOG said was fixed —
// while both docs claimed otherwise. A security fix applied to one copy is not a fix.
//
// `pre-commit` legitimately diverges by one repo-only block (ROUTER freshness), so the
// comparison drops it. Anything else differing is drift, not a decision.
// Sections that belong to THIS repository and must not travel with the shipped asset. The
// shipped guard is about leaking secrets in any project; these are about MasterMind's own
// checks, which only exist here. Marked explicitly so a new one is a marker, not a new regex.
const REPO_ONLY = [
  /^# ---- Router freshness[\s\S]*?^fi\n\n/m,
  /^# >>> repo-only:[\s\S]*?^# <<< repo-only[^\n]*\n/m,
]
// Parity is a REPO invariant: `.githooks/` only exists in this checkout. A project's isolated
// brain ships the assets and no `.githooks/`, so demanding both copies there reported two
// failures for a correctly-installed brain. Skip the pair when the live side is absent.
const hasLiveHooks = existsSync(join(ROOT, '.githooks'))
for (const hook of hasLiveHooks ? ['pre-commit', 'pre-push'] : []) {
  const live = join(ROOT, '.githooks', hook)
  const shipped = join(ROOT, 'skills', 'quarantine', 'assets', hook)
  if (!existsSync(live) || !existsSync(shipped)) {
    fail(`${hook}: missing from .githooks/ or skills/quarantine/assets/ — both copies must exist`)
    continue
  }
  // Both sides get identical treatment: strip the repo-only sections, then collapse runs of
  // blank lines, since removing a block leaves behind the blank line that separated it.
  const norm = (p) =>
    REPO_ONLY.reduce((acc, re) => acc.replace(re, ''), readFileSync(p, 'utf8'))
      .replace(/\n{2,}/g, '\n')
      .trimEnd()
  if (norm(live) !== norm(shipped)) {
    fail(
      `.githooks/${hook} differs from skills/quarantine/assets/${hook} — the guard protecting ` +
        `this repo is not the guard we ship. Sync them (a fix must land in both).`
    )
  }
}

// The menus users read must name skills that exist. Six dead names (perf, spec, spike, lab,
// doubt, map) survived a rename in help/SKILL.md and the kernel; every one failed when typed.
const realNames = new Set([
  ...readdirSync(join(ROOT, 'skills'), { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name),
  ...readdirSync(join(ROOT, 'agents')).filter((f) => f.endsWith('.md')).map((f) => f.replace(/\.md$/, '')),
])
const RETIRED = ['perf', 'spec', 'spike', 'lab', 'doubt', 'map']
for (const menu of ['skills/help/SKILL.md', 'CLAUDE.md', 'skills/README.md', 'README.md']) {
  const file = join(ROOT, menu)
  if (!existsSync(file)) continue
  const text = readFileSync(file, 'utf8')
  for (const dead of RETIRED) {
    const re = new RegExp('(\\*\\*|`)' + dead + '(\\*\\*|`)')
    if (re.test(text) && !realNames.has(dead))
      fail(`${menu} still advertises the retired name "${dead}" — it fails when typed`)
  }
}

// --- 11. the published article reconciles with the real instructions ----------
// scripts/build-library.mjs generates every public library page from ABOUT.md and never reads
// SKILL.md, so nothing connected the article the site publishes to the instructions the model
// actually follows. Two documents can only be reconciled where both make a checkable statement,
// so this asserts the ones that exist: they must come in pairs, the article must carry the
// frontmatter the page renders, it must say when the thing fires, it must not name a capability
// that was renamed away, and it must not contradict the source about how it is invoked.
const aboutPairs = [
  ...skillDirs.map((n) => ({ kind: 'skill', name: n, about: `skills/${n}/ABOUT.md`, source: `skills/${n}/SKILL.md` })),
  ...readdirSync(join(ROOT, 'agents'))
    .filter((f) => f.endsWith('.md'))
    .map((f) => f.replace(/\.md$/, ''))
    .map((n) => ({ kind: 'agent', name: n, about: `agents/about/${n}.md`, source: `agents/${n}.md` })),
]

// ABOUT.md is repository-only: it generates the public library pages and is not copied into an
// installed brain, because nothing reads it at runtime. So when NONE of them are present, this
// is an installed brain and there is nothing here to reconcile. When SOME are missing, that is
// a genuine gap in the repository and every one of them is reported below.
const anyAbout = aboutPairs.some((a) => existsSync(join(ROOT, a.about)))
if (!anyAbout) {
  console.log('  · ABOUT pages are repository-only; skipping that check in an installed brain')
}

for (const { kind, name, about, source } of (anyAbout ? aboutPairs : [])) {
  if (!existsSync(join(ROOT, about))) {
    fail(`${about}: missing. build-library.mjs publishes a page per ${kind} from this file`)
    continue
  }
  if (!existsSync(join(ROOT, source))) {
    fail(`${about}: describes "${name}", but ${source} does not exist, so the article has no instructions behind it`)
    continue
  }
  const text = read(about)
  const meta = frontmatter(text) ?? {}
  for (const key of ['title', 'blurb']) {
    if (!meta[key]) fail(`${about}: no \`${key}\` in frontmatter, so the library page would publish a blank ${key}`)
  }
  if (!/^#+\s.*when it fires/im.test(text)) {
    fail(`${about}: no "When it fires" section, so the page makes no invocation claim, so nothing reconciles it with ${source}`)
  }
  // A rename that misses the article ships a dead name to the site, where nobody typing it gets
  // anything back. Checked against the same retired list the menus are checked against.
  // Matched only in the markup that means "this is a capability name": `` `lab` ``, `**lab**` or
  // `/lab`, so the real `lab/` directory, which kept its name when the skill became `quarantine`,
  // does not read as a dead skill.
  for (const dead of RETIRED) {
    if (realNames.has(dead)) continue
    if (new RegExp('\\*\\*' + dead + '\\*\\*|`' + dead + '`|(?:^|\\s)/' + dead + '(?![\\w/-])', 'm').test(text))
      fail(`${about}: names the retired "${dead}", which is not a skill or agent on disk`)
  }
  // Invocation shape. A skill can be typed as a slash command; an agent cannot, because it is an
  // isolated-context role the model hands work to, so "/agent-name" teaches an invocation that
  // does not exist.
  for (const m of text.matchAll(/(?:^|[\s(])\/([a-z][a-z-]{2,})\b/g)) {
    if (!realNames.has(m[1])) continue
    if (kind === 'agent')
      fail(`${about}: presents "/${m[1]}", but agents are not slash commands, they run in an isolated context`)
    else if (m[1] !== name)
      fail(`${about}: presents "/${m[1]}" on the page for "${name}": the slash name must be the skill's own`)
  }
  // Opt-in is the one behaviour claim both files state plainly, and the one that would embarrass
  // us: an article promising a skill fires by itself when the instructions say it must be asked for.
  if (kind === 'skill') {
    const desc = frontmatter(read(source))?.description ?? ''
    const optIn = /\bONLY when\b|off by default|never produce one unprompted|explicitly asks/i.test(desc)
    const claimsAuto =
      /\byou (?:don't|do not|never) (?:need to |have to )?type\b|applies automatically|fires on its own|without you asking/i.test(text)
    if (optIn && claimsAuto)
      fail(`${about}: claims it fires without being asked, but ${source} marks it opt-in: the page and the instructions disagree`)
  }
}

// The wrong-log is the calibration record, so a count of it must be exact. `mastermind wrong-log`
// anchors on the entry format; anything else counting the file (a grep, a human, me) counts every
// line containing the marker. Those two numbers must be the same number, and they were not: the
// header sentence quoted the marker while explaining it, so prose inflated the count. Keep them
// equal — if a line carries the marker, it is an entry.
const journal = readIfPresent('journal.md')
if (journal !== null) {
  const lines = journal.split('\n')
  const entries = lines.filter((l) => /^\d{4}-\d{2}-\d{2}\s*·\s*wrong\s*·/.test(l.trim()))
  const mentions = lines.filter((l) => l.includes('\u00b7 wrong \u00b7'))
  if (entries.length !== mentions.length) {
    const stray = mentions.filter((l) => !entries.includes(l)).map((l) => l.trim().slice(0, 60))
    fail(`journal.md: ${mentions.length} lines carry the miss marker but only ${entries.length} `
      + `are entries — prose inflates every count of the log: "${stray[0]}…"`)
  }
}

// The markdown menus above are matched on `**name**`/`` `name` `` markup. The plugin manifests
// advertise the same menu as a bare comma-separated list inside a JSON string, so neither the
// file list nor the markup pattern covered them — and a description naming `spec` and `doubt`
// shipped for two releases. Parse the list instead of pattern-matching it: every token must be
// a skill or agent that exists on disk.
for (const manifest of ['.claude-plugin/marketplace.json', '.claude-plugin/plugin.json']) {
  const file = join(ROOT, manifest)
  if (!existsSync(file)) continue
  const blob = JSON.stringify(JSON.parse(readFileSync(file, 'utf8')))
  const listed = blob.match(/(?:Skills|skills & agents):([^.]+)/)?.[1]
  if (!listed) continue
  for (const token of listed.split(/[,+]/).map((t) => t.trim().replace(/^agents:\s*/, '')))
    if (/^[a-z][a-z-]{2,}$/.test(token) && !realNames.has(token))
      fail(`${manifest} advertises "${token}", which is not a skill or agent on disk`)
}

// One sentence describes this product, and it lives in four places that ship separately (npm,
// the plugin manifest, the marketplace listing, the GitHub About). They drifted: the About was
// still advertising Copilot support removed in 0.27. Keep them one string.
const CANON = 'A markdown brain that gives your AI coding tools judgment and rigor'
for (const f of ['.claude-plugin/plugin.json', '.claude-plugin/marketplace.json', 'cli/package.json', 'cli/README.md']) {
  const file = join(ROOT, f)
  if (!existsSync(file)) continue
  // Compare with whitespace and case normalised: the same sentence is line-wrapped in prose
  // and capitalised differently mid-sentence, and neither is drift.
  const text = readFileSync(file, 'utf8')
  const flat = (v) => v.replace(/\s+/g, ' ').toLowerCase()
  if (!flat(text).includes(flat(CANON)))
    fail(`${f}: description drifted from the canonical one-liner ("${CANON}…")`)
  for (const dead of ['Copilot', 'Gemini']) {
    if (new RegExp(`"[^"]*${dead}[^"]*"`).test(text))
      fail(`${f}: still advertises ${dead} — supported tools are Claude Code, Cursor and Codex`)
  }
}

// --- report ------------------------------------------------------------------
if (errors.length) {
  console.error(`\n✗ MasterMind integrity: ${errors.length} issue(s)\n`)
  for (const e of errors) console.error('  • ' + e)
  console.error('')
  process.exit(1)
}
console.log(`✓ MasterMind integrity: ${skillDirs.length} skills, indexes and references consistent.`)
