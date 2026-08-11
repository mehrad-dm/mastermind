#!/usr/bin/env node
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join, resolve } from 'node:path'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const ALLOWED_FM_KEYS = new Set(['name', 'description', 'license', 'allowed-tools', 'metadata'])
const errors = []
const fail = (m) => errors.push(m)
const read = (p) => readFileSync(join(ROOT, p), 'utf8')
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
}

const aboutPairs = [
  ...skillDirs.map((n) => ({ kind: 'skill', name: n, about: `skills/${n}/ABOUT.md`, source: `skills/${n}/SKILL.md` })),
  ...readdirSync(join(ROOT, 'agents'))
    .filter((f) => f.endsWith('.md'))
    .map((f) => f.replace(/\.md$/, ''))
    .map((n) => ({ kind: 'agent', name: n, about: `agents/about/${n}.md`, source: `agents/${n}.md` })),
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
if (journal !== null) {
  const lines = journal.split('\n')
  const entries = lines.filter((l) => /^\d{4}-\d{2}-\d{2}\s*·\s*wrong\s*·/.test(l.trim()))
  const mentions = lines.filter((l) => l.includes('\u00b7 wrong \u00b7'))
  if (entries.length !== mentions.length) {
    const stray = mentions.filter((l) => !entries.includes(l)).map((l) => l.trim().slice(0, 60))
    fail(`journal.md: ${mentions.length} lines carry the miss marker but only ${entries.length} `
      + `are entries: prose inflates every count of the log: "${stray[0]}…"`)
  }
}

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

// --- report ------------------------------------------------------------------
if (errors.length) {
  console.error(`\n✗ MasterMind integrity: ${errors.length} issue(s)\n`)
  for (const e of errors) console.error('  • ' + e)
  console.error('')
  process.exit(1)
}
console.log(`✓ MasterMind integrity: ${skillDirs.length} skills, indexes and references consistent.`)
