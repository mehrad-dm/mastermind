#!/usr/bin/env node

// Comments are rare, short, and explain WHY. "Meaningful" is not machine-checkable, but length
// is, and length is where the rule actually breaks.

import { readFileSync, existsSync, statSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..')
const SITE = process.env.MASTERMIND_SITE
  ? resolve(process.env.MASTERMIND_SITE)
  : join(REPO, '..', 'mastermind-site')

const MAX_BLOCK = 5      // consecutive comment lines anywhere in the body
const MAX_HEADER = 10    // a block that opens the file may say what the file is for
const HEADER_ZONE = 6    // ...if it starts this near the top
const DENSE = 0.3        // report, never fail: judgment, not a rule

const CODE = /\.(sh|mjs|js|ts|astro|css|yml|yaml)$/i
const SKIP = /^(evals|node_modules|dist)\//
const COMMENT = /^\s*(#|\/\/)/
const SHEBANG = /^#!/
const SLASH_STAR = /\.(mjs|js|ts|astro|css)$/i
const FIXTURES = join(REPO, 'scripts', 'fixtures', 'comments.json')

// A script with no extension (bin/mastermind, .githooks/pre-push) is code when its shebang says so.
const SHELL_SHEBANG = /^#!\s*(?:\/usr\/bin\/env\s+)?(?:\/\S*\/)?(?:ba|z|da|k)?sh\b/
const isCode = (file, head) => CODE.test(file) || (!/\.[^/]+$/.test(file) && SHELL_SHEBANG.test(head))

const tracked = (root) =>
  execFileSync('git', ['-C', root, 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], { encoding: 'utf8', maxBuffer: 64 << 20 })
    .split('\0')
    .filter((f) => f && !SKIP.test(f) && (CODE.test(f) || !/\.[^/]+$/.test(f)))

function measure(file, text, label = '') {
  const long = []
  const dense = []
  const lines = text.split('\n')
  const blocks = SLASH_STAR.test(file)
  let inBlock = false
  let run = 0
  let start = 0
  let comments = 0
  const close = (end) => {
    if (!run) return
    const limit = start <= HEADER_ZONE ? MAX_HEADER : MAX_BLOCK
    if (run > limit) long.push({ file: `${label}${file}`, line: start, run, limit })
    run = 0
  }
  // A heredoc body is content the script writes out, not commentary on it.
  let heredoc = null
  lines.forEach((line, i) => {
    if (heredoc !== null) {
      if (line.trim() === heredoc) heredoc = null
      return
    }
    const open = line.match(/<<-?\s*['"]?([A-Za-z_][A-Za-z0-9_]*)['"]?\s*$/)
    if (open) {
      heredoc = open[1]
      close(i)
      return
    }
    if (SHEBANG.test(line)) return
    const opens = blocks && !inBlock && /^\s*\/\*/.test(line)
    if (opens || inBlock) {
      if (!run) start = i + 1
      run++
      comments++
      inBlock = !/\*\//.test(opens ? line.replace(/^\s*\/\*/, '') : line)
      return
    }
    if (COMMENT.test(line)) {
      if (!run) start = i + 1
      run++
      comments++
    } else close(i)
  })
  close(lines.length)
  const code = lines.filter((l) => l.trim()).length
  if (code > 40 && comments / code > DENSE) dense.push({ file: `${label}${file}`, pct: Math.round((comments / code) * 100) })
  return { long, dense }
}

function scan(root, label) {
  const long = []
  const dense = []
  for (const file of tracked(root)) {
    const path = join(root, file)
    if (!existsSync(path) || !statSync(path).isFile()) continue
    const text = readFileSync(path, 'utf8')
    if (!isCode(file, text.slice(0, 120))) continue
    const r = measure(file, text, label)
    long.push(...r.long)
    dense.push(...r.dense)
  }
  return { long, dense }
}

if (process.argv.includes('--self-test')) {
  const { fires, clean } = JSON.parse(readFileSync(FIXTURES, 'utf8'))
  const long = (c) => isCode(c.file, c.text) && measure(c.file, c.text).long.length > 0
  const wrong = [
    ...fires.filter((c) => !long(c)).map((c) => `did not fire: ${c.name}`),
    ...clean.filter((c) => long(c)).map((c) => `fired on clean input: ${c.name}`),
  ]
  if (wrong.length) { console.error('✖ comments self-test:\n  ' + wrong.join('\n  ')); process.exit(1) }
  console.log(`✓ comments self-test: ${fires.length} bad inputs fire, ${clean.length} good inputs stay clean.`)
  process.exit(0)
}

const roots = [[REPO, '']]
const siteChecked = existsSync(SITE)
if (siteChecked) roots.push([SITE, 'site: '])

const long = []
const dense = []
for (const [root, label] of roots) {
  const r = scan(root, label)
  long.push(...r.long)
  dense.push(...r.dense)
}

if (dense.length) {
  console.log('· comment-heavy files, worth a look, not a failure:')
  for (const d of dense.sort((a, b) => b.pct - a.pct).slice(0, 8)) console.log(`    ${d.pct}%  ${d.file}`)
}

if (long.length) {
  console.error(`\n✖ ${long.length} comment block(s) longer than the house limit:\n`)
  for (const b of long.sort((a, b) => b.run - a.run))
    console.error(`  ${b.file}:${b.line}  ${b.run} lines (limit ${b.limit})`)
  console.error('\nSay it in one or two lines, or put it in the changelog where the reason belongs.')
  process.exit(1)
}

if (!siteChecked) {
  console.log(`· no comment block over ${MAX_BLOCK} lines in the repo, but the site is not checked out, so it was NOT checked`)
  process.exit(2)
}
console.log(`✓ no comment block over ${MAX_BLOCK} lines (${MAX_HEADER} for a file header) in the repo or the site.`)
