#!/usr/bin/env node
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join, resolve } from 'node:path'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const ALLOWED_FM_KEYS = new Set(['name', 'description', 'license', 'compatibility', 'allowed-tools', 'metadata', 'disable-model-invocation'])
const errors = []
const fail = (m) => errors.push(m)
const read = (p) => readFileSync(join(ROOT, p), 'utf8')
const readIfPresent = (p) => (existsSync(join(ROOT, p)) ? readFileSync(join(ROOT, p), 'utf8') : null)

// --- parse the simple `key: value` frontmatter block at the top of a file ----
const unquote = (v) => {
  if (/^'[\s\S]*'$/.test(v)) return v.slice(1, -1).replace(/''/g, "'")
  if (!/^"[\s\S]*"$/.test(v)) return v
  try { return JSON.parse(v) } catch { return v }
}
function frontmatter(text) {
  const m = text.match(/^---\n([\s\S]*?)\n---/)
  if (!m) return null
  const fm = {}
  const lines = m[1].split('\n')
  for (let i = 0; i < lines.length; i++) {
    const km = lines[i].match(/^([A-Za-z][\w-]*):\s?(.*)$/)
    if (!km) continue
    let value = km[2]
    if (/^[>|][+-]?$/.test(value.trim())) {
      const parts = []
      while (i + 1 < lines.length && /^(\s+\S|\s*$)/.test(lines[i + 1])) parts.push(lines[++i].trim())
      value = parts.join(' ').trim()
    } else if (value.trim()) {
      // A plain or quoted scalar may continue on indented lines, which YAML folds into one value.
      // Blank lines inside it fold too, as long as an indented line still follows them.
      const more = (j) => { while (j < lines.length && !lines[j].trim()) j++; return j < lines.length && /^\s+\S/.test(lines[j]) }
      while (i + 1 < lines.length && more(i + 1)) { const l = lines[++i].trim(); if (l) value = `${value.trimEnd()} ${l}` }
    }
    fm[km[1]] = unquote(value)
  }
  return fm
}

const KERNEL_MAX_LINES = 200
const KERNEL_MAX_CHARS = 9500
// Under 10,000 characters the session hook can carry the kernel whole, and Claude Code warns past 200 lines.
// Counted in UTF-16 units, as that cap is: an emoji counts two.
function kernelBudget(text) {
  const lines = text.replace(/\n$/, '').split('\n').length
  const chars = text.length
  if (lines <= KERNEL_MAX_LINES && chars <= KERNEL_MAX_CHARS) return []
  return [`CLAUDE.md is ${lines} lines and ${chars} characters; the kernel budget is ${KERNEL_MAX_LINES} lines and `
    + `${KERNEL_MAX_CHARS} characters, and both must hold`]
}

// A skill with `disable-model-invocation: true` is invisible to the model, so a plain request such as
// "what can you do?" never reaches it, and in Claude Code `/help` is the built-in command. Measured live:
// help and signature went from 2/2 to 0/2. Skills that run only on request say so in their description.
function userOnlyErrors(skills) {
  return skills.filter(({ fm }) => String(fm['disable-model-invocation'] ?? '').trim() === 'true')
    .map(({ dir }) => `skills/${dir}/SKILL.md: \`disable-model-invocation: true\` hides it from the model, so a plain request cannot reach it: say "only when the user asks" in its description instead`)
}

function frontmatterKeyErrors(rel, fm) {
  return Object.keys(fm).filter((k) => !ALLOWED_FM_KEYS.has(k)).map((k) => `${rel}: unexpected frontmatter key "${k}"`)
}

// An unquoted value holding ": " is not YAML. Claude Code and Codex read it anyway; a strict parser drops the skill.
function unquotedColonErrors(rel, text) {
  const head = (text ?? '').match(/^---\n([\s\S]*?)\n---/)?.[1] ?? ''
  const out = []
  for (const line of head.split('\n')) {
    const kv = line.match(/^([A-Za-z][\w-]*):\s(.*)$/)
    if (kv && !/^["'>|]/.test(kv[2]) && /:\s|\s#/.test(kv[2]))
      out.push(`${rel}: \`${kv[1]}\` holds ": " or " #" unquoted, which strict YAML rejects: wrap the value in double quotes`)
  }
  return out
}

const DESC_MAX = 500
const DESC_TOTAL_MAX = 12000
// Every description is loaded into every session and competes for a share of the context window.
// They carry the phrasings users actually say: cut to bare intent, live routing fell from 79% to 60%.
function descriptionBudget(skills) {
  const out = []
  let total = 0
  for (const { dir, fm } of skills) {
    if (fm.name !== dir) out.push(`skills/${dir}/SKILL.md: name "${fm.name}" ≠ directory "${dir}"`)
    const n = [...(fm.description ?? '')].length
    total += n
    if (!n) out.push(`skills/${dir}/SKILL.md: missing description`)
    else if (n > DESC_MAX) out.push(`skills/${dir}/SKILL.md: description is ${n} characters, over the ${DESC_MAX} limit`)
  }
  if (total > DESC_TOTAL_MAX)
    out.push(`skill descriptions total ${total} characters across ${skills.length} skills, over the ${DESC_TOTAL_MAX} budget`)
  return { errors: out, total }
}

const distance = (a, b) => {
  const d = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)])
  for (let j = 1; j <= b.length; j++) d[0][j] = j
  for (let i = 1; i <= a.length; i++)
    for (let j = 1; j <= b.length; j++)
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1))
  return d[a.length][b.length]
}

// Outcome words one or two letters away from "wrong" that an entry legitimately opens with.
const REAL_WORDS = new Set(['wrote', 'write', 'writ', 'prong', 'wring', 'wrung', 'won', 'song', 'long', 'strong', 'along', 'among', 'wrongs'])

// `mastermind wrong-log` reads only lines of the exact entry shape, so a mistyped miss vanishes from it.
function journalErrors(text) {
  const out = []
  const ENTRY = /^(\d{4})-(\d{2})-(\d{2})\s*·\s*(.*)$/
  for (const [i, raw] of text.split('\n').entries()) {
    const line = raw.trim()
    if (!/^(?:[-*·•>]\s*)?\d{4}-\d{1,2}-\d{1,2}\b/.test(line)) continue
    const at = `journal.md:${i + 1}`
    const m = line.match(ENTRY)
    const shown = line.slice(0, 60)
    if (!m) { out.push(`${at}: a dated line that is not an entry (want "YYYY-MM-DD · what · outcome"): "${shown}"`); continue }
    const day = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]))
    if (day.getUTCFullYear() !== +m[1] || day.getUTCMonth() !== +m[2] - 1 || day.getUTCDate() !== +m[3])
      out.push(`${at}: "${m[1]}-${m[2]}-${m[3]}" is not a date`)
    const fields = m[4].split(/\s*·\s*/).filter(Boolean)
    if (fields.length < 2) out.push(`${at}: an entry needs at least "what · outcome" after the date: "${shown}"`)
    const marker = (fields[0] ?? '').toLowerCase().replace(/[^a-z]/g, '')
    const exact = /^\d{4}-\d{2}-\d{2}\s*·\s*wrong\s*·/.test(line)
    const meant = /^wrong\b/i.test(fields[0] ?? '') || (marker.length <= 7 && !REAL_WORDS.has(marker) && distance(marker, 'wrong') <= 2)
    if (meant && !exact)
      out.push(`${at}: looks like a miss but is not marked exactly "· wrong ·", so wrong-log cannot see it: "${shown}"`)
    if (exact && !fields.slice(2).some((f) => /^caught by\s+\S/i.test(f)))
      out.push(`${at}: a miss with no "caught by <catcher>" field, so nobody can calibrate trust from it: "${shown}"`)
  }
  const lines = text.split('\n')
  const entries = lines.filter((l) => /^\d{4}-\d{2}-\d{2}\s*·\s*wrong\s*·/.test(l.trim()))
  const mentions = lines.filter((l) => l.includes('\u00b7 wrong \u00b7'))
  if (entries.length !== mentions.length) {
    const stray = mentions.filter((l) => !entries.includes(l)).map((l) => l.trim().slice(0, 60))
    out.push(`journal.md: ${mentions.length} lines carry the miss marker but only ${entries.length} `
      + `are entries: prose inflates every count of the log: "${stray[0]}…"`)
  }
  return out
}

// The listing people install from names every skill and agent. A listing this cannot find is a failure.
function marketplaceErrors(manifest, known) {
  const entry = (manifest?.plugins ?? []).find((p) => p.name === 'mastermind')
  if (!entry) return ['.claude-plugin/marketplace.json: no plugin entry named "mastermind", so nothing lists what the plugin carries']
  const listed = String(entry.description ?? '').match(/Skills:\s*([^.]+)\./)?.[1]
  if (!listed)
    return ['.claude-plugin/marketplace.json: the "mastermind" entry has no "Skills: a, b + agents: c, d." list, '
      + 'so the listing cannot be checked against what ships']
  const advertised = new Set(listed.split(/[,+]/).map((t) => t.trim().replace(/^agents:\s*/, '')).filter(Boolean))
  const out = []
  for (const token of advertised)
    if (!known.has(token)) out.push(`.claude-plugin/marketplace.json advertises "${token}", which is not a skill or agent on disk`)
  const unlisted = [...known].filter((n) => !advertised.has(n))
  if (unlisted.length)
    out.push(`.claude-plugin/marketplace.json ships ${unlisted.length} skill(s) or agent(s) it never names: ${unlisted.join(', ')}`)
  return out
}

if (process.argv.includes('--self-test')) {
  const fx = JSON.parse(read('scripts/fixtures/integrity.json'))
  const run = {
    kernel: (c) => kernelBudget(c.repeat ? `${c.repeat.line}\n`.repeat(c.repeat.times) : 'z'.repeat(c.chars)),
    descriptions: (c) => descriptionBudget(c.many
      ? Array.from({ length: c.many.count }, (_, i) => ({ dir: `s${i}`, fm: { name: `s${i}`, description: 'x'.repeat(c.many.chars) } }))
      : c.skills.map((s) => ({ dir: s.dir, fm: frontmatter(s.text) ?? {} }))).errors,
    journal: (c) => journalErrors(c.text),
    marketplace: (c) => marketplaceErrors(c.manifest, new Set(c.known)),
    userOnly: (c) => userOnlyErrors(c.skills.map((s) => ({ dir: s.dir, fm: frontmatter(s.text) ?? {} }))),
    frontmatterKeys: (c) => frontmatterKeyErrors('fixture', frontmatter(c.text) ?? {}),
    unquotedColon: (c) => unquotedColonErrors('fixture', c.text),
  }
  const wrong = []
  let fired = 0, clean = 0
  for (const [gate, cases] of Object.entries(fx)) {
    if (!run[gate]) { wrong.push(`${gate}: fixtures for a rule this script does not have`); continue }
    if (!cases.fires?.length) wrong.push(`${gate}: no bad input, so nothing shows the rule can fire`)
    for (const c of cases.fires ?? []) { fired++; if (!run[gate](c).length) wrong.push(`${gate} did not fire: ${c.name}`) }
    for (const c of cases.clean ?? []) { clean++; const e = run[gate](c); if (e.length) wrong.push(`${gate} fired on clean input: ${c.name}: ${e[0]}`) }
  }
  if (wrong.length) { console.error('✖ integrity self-test:\n  ' + wrong.join('\n  ')); process.exit(1) }
  console.log(`✓ integrity self-test: ${fired} bad inputs fire, ${clean} good inputs stay clean.`)
  process.exit(0)
}

// --- 1. skills exist & have valid frontmatter --------------------------------
const skillDirs = readdirSync(join(ROOT, 'skills'), { withFileTypes: true })
  .filter((d) => d.isDirectory())
  .map((d) => d.name)
  .sort()

const parsedSkills = []
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
  frontmatterKeyErrors(rel, fm).forEach(fail)
  parsedSkills.push({ dir, fm })
}
const descriptions = descriptionBudget(parsedSkills)
descriptions.errors.forEach(fail)
userOnlyErrors(parsedSkills).forEach(fail)

const skillsReadme = readIfPresent('skills/README.md') ?? ''
const listedSkills = new Set(
  [...skillsReadme.matchAll(/\[`([a-z0-9-]+)`\]\(\.\/([a-z0-9-]+)\/SKILL\.md\)/g)].map((m) => m[2])
)
for (const dir of skillDirs) {
  if (!listedSkills.has(dir)) fail(`skills/README.md: skill "${dir}" not listed (the index must be complete)`)
}
for (const listed of listedSkills) {
  if (!skillDirs.includes(listed)) fail(`skills/README.md: lists "${listed}", no such skill dir`)
}
for (const file of ['skills/README.md', 'README.md']) {
  const text = readIfPresent(file)
  if (text === null) continue
  for (const m of text.matchAll(/`(mastermind-[a-z-]+)`/g)) {
    if (!skillDirs.includes(m[1])) fail(`${file}: lists "${m[1]}", no such skill dir`)
  }
}

// --- 4. no broken cross-references in the docs --------------------------------
const docFiles = []
;(function walk(d) {
  for (const e of readdirSync(join(ROOT, d), { withFileTypes: true })) {
    if (e.name === 'node_modules' || e.name === 'lab' || e.name === 'private' || e.name === 'local' || e.name.startsWith('.git')) continue
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

if (!/^-?\s*\*\*Level:\*\*\s*\d+/m.test(read('engineering/active-field.md'))) {
  fail('engineering/active-field.md: no current level declared (expected a `**Level:** N` line)')
}

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
    fail(`engineering/fields/${pack}/: no audit-rules.md, code-reviewer would have no framework rules`)
  }
  for (const abs of files) {
    if (NON_ROUTABLE.has(abs.split('/').pop())) continue
    const rel = abs.slice(ROOT.length + 1)
    const fm = frontmatter(read(rel))
    if (!fm || !('route_when' in fm)) {
      fail(`${rel}: no \`route_when\` frontmatter, build-router.mjs will skip it silently`)
    }
    if (fm && fm.field && !pack.startsWith('_') && fm.field !== pack) {
      fail(`${rel}: declares \`field: ${fm.field}\` inside the "${pack}" pack, so it would route under `
        + `the wrong name. A pack copied or half-renamed passes every other check.`)
    }
  }
}

const activeField = read('engineering/active-field.md')
const fieldless =
  /Current field:\s*\*\*\s*none/i.test(activeField) || /^\s*[-*]\s*\*\*Level:\*\*\s*0\b/m.test(activeField)
const packRef = activeField.match(/^\s*[-*]\s*\*\*Field pack:\*\*\s*`([^`]+)`/m)
if (fieldless) {
  // no field by design: nothing to resolve
} else if (!packRef) {
  fail('engineering/active-field.md: no `- **Field pack:** `<path>`` line, nothing declares the active pack')
} else {
  const packPath = packRef[1].replace(/\/$/, '')
  if (!existsSync(join(ROOT, packPath)) || !statSync(join(ROOT, packPath)).isDirectory()) {
    fail(`engineering/active-field.md: field pack "${packRef[1]}" does not exist, the active field cannot load`)
  } else {
    for (const required of ['field.md', 'audit-rules.md']) {
      if (!existsSync(join(ROOT, packPath, required))) {
        fail(`engineering/active-field.md: active pack "${packRef[1]}" is missing ${required}`)
      }
    }
  }
}

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
    fail(`${rel}: re-vendor \`rm -rf\`s this directory but no preserve list found: expected bullets of the form "- **\`path\`**, why" after a line saying what must survive`)
    continue
  }
  const rescued = [...text.matchAll(/^\s*cp\b[^\n]*?\$\{?P\}?\/([^"'\s]+)["']?\s+\/tmp\S*/gm)].map((m) =>
    m[1].replace(/\/$/, '')
  )
  for (const p of listed) {
    if (!existsSync(join(ROOT, dir, p))) fail(`${rel}: preserved path "${p}" does not exist, the re-vendor would restore nothing`)
    if (!rescued.includes(p)) fail(`${rel}: preserved path "${p}" is never copied aside by the re-vendor block: the list and the procedure have drifted`)
  }
  for (const p of rescued) {
    if (!listed.includes(p)) fail(`${rel}: re-vendor copies "${p}" aside but it is not in the preserve list: undocumented, so the next editor won't know it's ours`)
  }
}

const REPO_ONLY = [/^# >>> repo-only:[\s\S]*?^# <<< repo-only[^\n]*\n/gm]
const hasLiveHooks = existsSync(join(ROOT, '.githooks'))
for (const hook of hasLiveHooks ? ['pre-commit', 'pre-push'] : []) {
  const live = join(ROOT, '.githooks', hook)
  const shipped = join(ROOT, 'skills', 'quarantine', 'assets', hook)
  if (!existsSync(live) || !existsSync(shipped)) {
    fail(`${hook}: missing from .githooks/ or skills/quarantine/assets/, both copies must exist`)
    continue
  }
  const norm = (p) =>
    REPO_ONLY.reduce((acc, re) => acc.replace(re, ''), readFileSync(p, 'utf8'))
      .replace(/\n{2,}/g, '\n')
      .trimEnd()
  if (norm(live) !== norm(shipped)) {
    fail(
      `.githooks/${hook} differs from skills/quarantine/assets/${hook}: the guard protecting ` +
        `this repo is not the guard we ship. Sync them (a fix must land in both).`
    )
  }
}

const realNames = new Set([
  ...readdirSync(join(ROOT, 'skills'), { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name),
  ...readdirSync(join(ROOT, 'agents')).filter((f) => f.endsWith('.md')).map((f) => f.replace(/\.md$/, '')),
])
const RX_META = /[.*+?^${}()|[\]\\]/g
// A skill is listed when its name opens an entry: a table cell, a bullet, or an item
// after a separator. A mention inside another entry's prose ("inside `build`") is not a
// listing, and matching the bare word anywhere passed on the prose around the menu.
const menuToken = (n) =>
  new RegExp('(?:^|[|\u00b7:])[ \t]*\\[?(`|\\*\\*)' + n.replace(RX_META, '\\$&') + '\\1', 'm')

const RETIRED = ['perf', 'spec', 'spike', 'lab', 'doubt', 'map']
for (const menu of ['skills/help/SKILL.md', 'CLAUDE.md', 'skills/README.md', 'README.md']) {
  const file = join(ROOT, menu)
  if (!existsSync(file)) continue
  const text = readFileSync(file, 'utf8')
  for (const dead of RETIRED) {
    const re = new RegExp('(\\*\\*|`)' + dead + '(\\*\\*|`)')
    if (re.test(text) && !realNames.has(dead))
      fail(`${menu} still advertises the retired name "${dead}": it fails when typed`)
  }
  // Only retired names were checked, so a menu could silently omit a shipped skill:
  // `clarify` and `deepen` reached neither the help menu nor the marketplace listing.
  // README.md is a highlights list and does not claim to be complete, so it is exempt.
  if (menu === 'README.md') continue
  const unlisted = skillDirs.filter((n) => !menuToken(n).test(text))
  if (unlisted.length)
    fail(`${menu} never names ${unlisted.length} shipped skill(s): ${unlisted.join(', ')}`)
}

const aboutPairs = [
  ...skillDirs.map((n) => ({ kind: 'skill', name: n, about: `skills/${n}/ABOUT.md`, source: `skills/${n}/SKILL.md` })),
  ...readdirSync(join(ROOT, 'agents'))
    .filter((f) => f.endsWith('.md'))
    .map((f) => f.replace(/\.md$/, ''))
    .map((n) => ({ kind: 'agent', name: n, about: `library/agents/${n}.md`, source: `agents/${n}.md` })),
]

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
  for (const dead of RETIRED) {
    if (realNames.has(dead)) continue
    if (new RegExp('\\*\\*' + dead + '\\*\\*|`' + dead + '`|(?:^|\\s)/' + dead + '(?![\\w/-])', 'm').test(text))
      fail(`${about}: names the retired "${dead}", which is not a skill or agent on disk`)
  }
  for (const m of text.matchAll(/(?:^|[\s(])\/([a-z][a-z-]{2,})\b/g)) {
    if (!realNames.has(m[1])) continue
    if (kind === 'agent')
      fail(`${about}: presents "/${m[1]}", but agents are not slash commands, they run in an isolated context`)
    else if (m[1] !== name)
      fail(`${about}: presents "/${m[1]}" on the page for "${name}": the slash name must be the skill's own`)
  }
  if (kind === 'skill') {
    const desc = frontmatter(read(source))?.description ?? ''
    const optIn = /\bONLY when\b|off by default|never produce one unprompted|explicitly asks/i.test(desc)
    const claimsAuto =
      /\byou (?:don't|do not|never) (?:need to |have to )?type\b|applies automatically|fires on its own|without you asking/i.test(text)
    if (optIn && claimsAuto)
      fail(`${about}: claims it fires without being asked, but ${source} marks it opt-in: the page and the instructions disagree`)
  }
}

const journal = readIfPresent('journal.md')
if (journal !== null) journalErrors(journal).forEach(fail)

const marketplace = readIfPresent('.claude-plugin/marketplace.json')
if (marketplace !== null) marketplaceErrors(JSON.parse(marketplace), realNames).forEach(fail)

// A script that hardcodes the site as a sibling passes on a developer's machine and fails
// wherever the site is checked out elsewhere, which is every CI run. sync-evals did exactly
// that and took a release down with it.
for (const f of readdirSync(join(ROOT, 'scripts')).filter((f) => f.endsWith('.mjs'))) {
  const text = readFileSync(join(ROOT, 'scripts', f), 'utf8')
  if (text.includes('mastermind-site') && !text.includes('MASTERMIND_SITE'))
    fail(`scripts/${f}: resolves the site as a sibling and ignores MASTERMIND_SITE, so it cannot run where CI puts it`)
}

const CANON = 'A markdown brain that gives your AI coding tools judgment and rigor'
for (const f of ['.claude-plugin/plugin.json', '.claude-plugin/marketplace.json', 'cli/package.json', 'cli/README.md']) {
  const file = join(ROOT, f)
  if (!existsSync(file)) continue
  const text = readFileSync(file, 'utf8')
  const flat = (v) => v.replace(/\s+/g, ' ').toLowerCase()
  if (!flat(text).includes(flat(CANON)))
    fail(`${f}: description drifted from the canonical one-liner ("${CANON}…")`)
  for (const dead of ['Copilot', 'Gemini']) {
    if (new RegExp(`"[^"]*${dead}[^"]*"`).test(text))
      fail(`${f}: still advertises ${dead}, supported tools are Claude Code, Cursor and Codex`)
  }
}

for (const rel of [...skillDirs.map((d) => `skills/${d}/SKILL.md`), ...readdirSync(join(ROOT, 'agents')).filter((f) => f.endsWith('.md')).map((f) => `agents/${f}`)])
  unquotedColonErrors(rel, readIfPresent(rel)).forEach(fail)

const kernel = readIfPresent('CLAUDE.md')
if (kernel === null) fail('CLAUDE.md is missing: there is no kernel to load')
else kernelBudget(kernel).forEach(fail)

// --- report ------------------------------------------------------------------
if (errors.length) {
  console.error(`\n✗ MasterMind integrity: ${errors.length} issue(s)\n`)
  for (const e of errors) console.error('  • ' + e)
  console.error('')
  process.exit(1)
}
console.log(`✓ MasterMind integrity: ${skillDirs.length} skills, indexes and references consistent `
  + `(kernel ${kernel.length} characters, descriptions ${descriptions.total}).`)
