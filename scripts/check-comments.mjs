#!/usr/bin/env node

// Comments are rare, short, and explain WHY. "Meaningful" is not machine-checkable, but length
// is, and length is where the rule actually breaks: a paragraph above a guard is the shape a
// reason takes when it should have gone in the changelog.

import { readFileSync, existsSync } from 'node:fs'
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

const tracked = (root) =>
  execFileSync('git', ['-C', root, 'ls-files', '-z'], { encoding: 'utf8', maxBuffer: 64 << 20 })
    .split('\0')
    .filter((f) => f && CODE.test(f) && !SKIP.test(f))

function scan(root, label) {
  const long = []
  const dense = []
  for (const file of tracked(root)) {
    const path = join(root, file)
    if (!existsSync(path)) continue
    const lines = readFileSync(path, 'utf8').split('\n')
    let run = 0
    let start = 0
    let comments = 0
    const close = (end) => {
      if (!run) return
      const limit = start <= HEADER_ZONE ? MAX_HEADER : MAX_BLOCK
      if (run > limit) long.push({ file: `${label}${file}`, line: start, run, limit })
      run = 0
    }
    // A heredoc body is content the script writes out, not commentary on it. The `#` lines in
    // the routes.map template are instructions to the user, and counting them here is wrong.
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
      if (COMMENT.test(line)) {
        if (!run) start = i + 1
        run++
        comments++
      } else close(i)
    })
    close(lines.length)
    const code = lines.filter((l) => l.trim()).length
    if (code > 40 && comments / code > DENSE) dense.push({ file: `${label}${file}`, pct: Math.round((comments / code) * 100) })
  }
  return { long, dense }
}

const roots = [[REPO, '']]
if (existsSync(SITE)) roots.push([SITE, 'site: '])

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

console.log(`✓ no comment block over ${MAX_BLOCK} lines (${MAX_HEADER} for a file header).`)
