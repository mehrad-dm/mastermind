#!/usr/bin/env node

// The em dash is the most reliable tell that a machine wrote the text, so MasterMind ships none.
// Three sweeps each believed they were finished and each shipped more, because the rule lived in
// someone's attention instead of a check. Every sweep missed a different hiding place, so this
// looks in all of them: the character, the JSON escape, the HTML entities, and inside fenced code.

import { readFileSync, existsSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..')
const SITE = process.env.MASTERMIND_SITE
  ? resolve(process.env.MASTERMIND_SITE)
  : join(REPO, '..', 'mastermind-site')

// Assembled from pieces so that none of the three forms appears literally in this file. Spell any
// of them out here and the checker reports itself, which then needs an exemption, which is a hole
// in the one file that must not have one. Keep it built, not written.
const CHAR = String.fromCharCode(0x2014)
const FORMS = [
  [new RegExp(CHAR, 'g'), 'em dash'],
  [new RegExp('\\\\' + 'u2014', 'gi'), 'em dash, written as a JSON escape'],
  [new RegExp(['&' + 'mdash;', '&#' + '8212;', '&#' + 'x2014;'].join('|'), 'gi'), 'em dash, written as an HTML entity'],
]

// The exemptions are line-scoped rather than file-scoped, so exempting a line cannot blind the
// check to the rest of the file it lives in.
const ALLOW = [
  {
    // Uninstall matches this text exactly to take the pointer line back out of files written
    // before 0.31.3. Rewording it would strand our text in those users' files forever.
    test: (file, line) => file === 'install.sh' && /^HINT_LEGACY_(GLOBAL|ISOLATED)=/.test(line),
    why: 'the pre-0.31.3 pointer text, which uninstall matches verbatim',
  },
  {
    // Prompts we hand to models and the answers they gave back. Editing either would silently
    // change what past runs are being compared against.
    test: (file) => file.startsWith('evals/'),
    why: 'eval fixtures and recorded model output',
  },
  {
    // A gate that rejects the character proves it on an input that holds one.
    test: (file, line, at, bad) => bad.has(at),
    why: 'a bad input inside the "fires" list of a gate fixture under scripts/fixtures/',
  },
]

// The lines of a fixture's "fires" array, in a JSON file directly under scripts/fixtures/.
function badInputLines(file, text) {
  const lines = new Set()
  if (!/^scripts\/fixtures\/[^/]+\.json$/.test(file)) return lines
  const key = text.search(/"fires"\s*:\s*\[/)
  if (key < 0) return lines
  let i = text.indexOf('[', key), depth = 0, quoted = false
  const from = i
  for (; i < text.length; i++) {
    const c = text[i]
    if (quoted) { if (c === '\\') i++; else if (c === '"') quoted = false; continue }
    if (c === '"') quoted = true
    else if (c === '[') depth++
    else if (c === ']' && --depth === 0) break
  }
  const first = text.slice(0, from).split('\n').length, last = text.slice(0, i).split('\n').length
  for (let n = first; n <= last; n++) lines.add(n)
  return lines
}

function inspect(file, text, label = '') {
  const findings = []
  let exempt = 0
  if (!FORMS.some(([re]) => (re.lastIndex = 0) === 0 && re.test(text))) return { findings, exempt }
  const bad = badInputLines(file, text)
  text.split('\n').forEach((line, i) => {
    for (const [re, what] of FORMS) {
      re.lastIndex = 0
      if (!re.test(line)) continue
      if (ALLOW.find((a) => a.test(file, line, i + 1, bad))) { exempt++; return }
      findings.push({ file: `${label}${file}`, line: i + 1, what, text: line.trim().slice(0, 96) })
      return
    }
  })
  return { findings, exempt }
}

const BINARY = /\.(png|jpe?g|gif|webp|ico|woff2?|ttf|otf|zip|gz|tgz|pdf|mp4|webm)$/i

const tracked = (root) =>
  execFileSync('git', ['-C', root, 'ls-files', '-z'], { encoding: 'utf8', maxBuffer: 64 << 20 })
    .split('\0')
    .filter((f) => f && !BINARY.test(f))

function scan(root, label) {
  const findings = []
  let exempt = 0
  for (const file of tracked(root)) {
    const path = join(root, file)
    if (!existsSync(path)) continue // a deleted-but-staged path
    let text
    try {
      text = readFileSync(path, 'utf8')
    } catch {
      continue
    }
    const r = inspect(file, text, label)
    findings.push(...r.findings)
    exempt += r.exempt
  }
  return { findings, exempt }
}

if (process.argv.includes('--self-test')) {
  // The fixtures spell the character as {EM} so that they hold none of the forms themselves.
  const { fires, clean } = JSON.parse(readFileSync(join(REPO, 'scripts', 'fixtures', 'prose.json'), 'utf8'))
  const forms = { '{EM}': CHAR, '{ESC}': '\\' + 'u2014', '{ENT}': '&' + 'mdash;' }
  const fill = (t) => t.replace(/\{EM\}|\{ESC\}|\{ENT\}/g, (k) => forms[k])
  const hits = (c) => inspect(c.file, fill(c.text)).findings.length
  const wrong = [
    ...(fires.length ? [] : ['no bad input, so nothing shows the rule can fire']),
    ...fires.filter((c) => !hits(c)).map((c) => `did not fire: ${c.name}`),
    ...clean.filter((c) => hits(c)).map((c) => `fired on clean input: ${c.name}`),
  ]
  if (wrong.length) { console.error('✖ prose self-test:\n  ' + wrong.join('\n  ')); process.exit(1) }
  console.log(`✓ prose self-test: ${fires.length} bad inputs fire, ${clean.length} good inputs stay clean.`)
  process.exit(0)
}

const roots = [[REPO, '']]
let siteChecked = true
if (existsSync(SITE)) roots.push([SITE, 'site: '])
else siteChecked = false

const findings = []
let exempt = 0
for (const [root, label] of roots) {
  const r = scan(root, label)
  findings.push(...r.findings)
  exempt += r.exempt
}

if (findings.length) {
  console.error(`✖ em dashes in ${new Set(findings.map((f) => f.file)).size} file(s):\n`)
  for (const f of findings) console.error(`  ${f.file}:${f.line}  ${f.text}\n      ${f.what}`)
  console.error('\nUse a colon when what follows explains what came before, a comma otherwise.')
  console.error('A line that genuinely must keep one belongs in ALLOW in this script, with why.')
  process.exit(1)
}

const note = exempt ? `, ${exempt} exempt line(s) on the record` : ''
if (!siteChecked) {
  // Exit 2, not 0: preflight reads 2 as "could not run here" and keeps it out of the passed
  // count. A check that reports success for work it never did is the thing this file exists for.
  console.log(`· repo is clean${note}, but the site is not checked out, so it was NOT checked`)
  process.exit(2)
}
console.log(`✓ no em dashes in the repo or the site${note}.`)
