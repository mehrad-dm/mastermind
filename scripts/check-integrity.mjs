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
 *   4. no broken ~/.mastermind / engineering / core / fields cross-references in the docs
 *   5. active-field.md declares a level
 *   6. help/SKILL.md's "<n> skills · <n> agents" header matches what actually ships
 *   7. every field-pack file (except field.md) carries `route_when`, and every pack
 *      ships field.md + audit-rules.md — otherwise the router skips it silently
 *   8. active-field.md's declared "Field pack:" points at a pack dir that exists and is
 *      well-formed (field.md + audit-rules.md, same bar as check 7)
 *   9. every SOURCE.md with a destructive re-vendor procedure carries a preserve list, every
 *      listed path exists, and the list and the procedure agree in both directions
 *  10. .githooks/ (this repo's live guards) matches skills/lab/assets/ (what we ship),
 *      so a security fix cannot land in one copy and leave the other vulnerable
 */
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join, resolve } from 'node:path'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const ALLOWED_FM_KEYS = new Set(['name', 'description', 'license', 'allowed-tools', 'metadata'])
const errors = []
const fail = (m) => errors.push(m)
const read = (p) => readFileSync(join(ROOT, p), 'utf8')

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
const skillsReadme = read('skills/README.md')
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
  for (const m of read(file).matchAll(/`(mastermind-[a-z-]+)`/g)) {
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
// `.githooks/` is this repo's live guard; `skills/lab/assets/` is what we install for
// users. a fix landed in the shipped `pre-push` and left `.githooks/` stale, so
// the guard protecting this public repo kept the bug the CHANGELOG said was fixed —
// while both docs claimed otherwise. A security fix applied to one copy is not a fix.
//
// `pre-commit` legitimately diverges by one repo-only block (ROUTER freshness), so the
// comparison drops it. Anything else differing is drift, not a decision.
const REPO_ONLY = /^# ---- Router freshness[\s\S]*?^fi\n\n/m
for (const hook of ['pre-commit', 'pre-push']) {
  const live = join(ROOT, '.githooks', hook)
  const shipped = join(ROOT, 'skills', 'lab', 'assets', hook)
  if (!existsSync(live) || !existsSync(shipped)) {
    fail(`${hook}: missing from .githooks/ or skills/lab/assets/ — both copies must exist`)
    continue
  }
  const norm = (p) => readFileSync(p, 'utf8').replace(REPO_ONLY, '')
  if (norm(live) !== norm(shipped)) {
    fail(
      `.githooks/${hook} differs from skills/lab/assets/${hook} — the guard protecting ` +
        `this repo is not the guard we ship. Sync them (a fix must land in both).`
    )
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
