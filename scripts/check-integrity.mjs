#!/usr/bin/env node
/**
 * MasterMind integrity check — makes it impossible for the indexes to lie.
 * Zero deps. Exits 1 on any failure (CI-friendly). Run: `node scripts/check-integrity.mjs`.
 *
 * Verifies, per the project's own "a router that lies" warning (skills/README.md):
 *   1. every skills/<name>/ has a SKILL.md with valid frontmatter (name matches dir,
 *      description present & ≤1024 chars, only allowed keys — per the Agent Skills spec)
 *   2. skills/README.md lists exactly the skill dirs (no missing, no extra)
 *   3. the root README.md skills table lists exactly the skill dirs
 *   4. no broken ~/.mastermind / engineering / core / fields cross-references in the docs
 *   5. active-field.md declares a level
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
// root README.md markets the first-party skills: every mastermind-* dir must appear there.
const skillsReadme = read('skills/README.md')
for (const dir of skillDirs) {
  if (!skillsReadme.includes(dir)) fail(`skills/README.md: skill "${dir}" not listed (the index must be complete)`)
}
const rootReadme = read('README.md')
for (const dir of skillDirs) {
  if (dir.startsWith('mastermind-') && !rootReadme.includes(dir)) fail(`README.md: first-party skill "${dir}" not listed`)
}
// flag any mastermind-* name claimed in an index that has no matching dir
for (const file of ['skills/README.md', 'README.md']) {
  for (const m of read(file).matchAll(/mastermind-[a-z-]+/g)) {
    if (!skillDirs.includes(m[0])) fail(`${file}: lists "${m[0]}" — no such skill dir`)
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
if (!/level\s+\d+/i.test(read('engineering/active-field.md'))) {
  fail('engineering/active-field.md: no level declared')
}

// --- report ------------------------------------------------------------------
if (errors.length) {
  console.error(`\n✗ MasterMind integrity: ${errors.length} issue(s)\n`)
  for (const e of errors) console.error('  • ' + e)
  console.error('')
  process.exit(1)
}
console.log(`✓ MasterMind integrity: ${skillDirs.length} skills, indexes and references consistent.`)
