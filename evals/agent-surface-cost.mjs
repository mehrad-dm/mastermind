#!/usr/bin/env node
import { readFileSync, readdirSync, existsSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const CLI = join(ROOT, 'cli', 'bin', 'mastermind.mjs')
const REQUEST = process.argv[2] || 'why is this page slow?'
const CHOSEN = process.argv[3] || 'performance'
// ~4 chars/token is the usual English rule of thumb; reported as an estimate, not a fact.
const tok = (chars) => Math.round(chars / 4)

const skillsDir = join(ROOT, 'skills')
let inline = 0
for (const e of readdirSync(skillsDir, { withFileTypes: true })) {
  const f = join(skillsDir, e.name, 'SKILL.md')
  if (e.isDirectory() && existsSync(f)) inline += readFileSync(f, 'utf8').length
}

const indexFile = join(skillsDir, 'README.md')
const chosenBody = readFileSync(join(skillsDir, CHOSEN, 'SKILL.md'), 'utf8').length
const viaIndex = readFileSync(indexFile, 'utf8').length + chosenBody

const sh = (args) => execFileSync('node', [CLI, ...args], { cwd: ROOT, encoding: 'utf8' })
const viaCli = sh(['route', REQUEST]).length + sh(['skill', CHOSEN]).length

const rows = [
  { path: 'A · inline every skill body', chars: inline },
  { path: 'B · read the index, then the skill', chars: viaIndex },
  { path: 'C · route, then skill (the CLI)', chars: viaCli },
]
for (const r of rows) {
  r.tokens_est = tok(r.chars)
  r.vs_inline = `${(100 - (r.chars / inline) * 100).toFixed(1)}% less`
}
console.table(rows)
console.log(`request: ${JSON.stringify(REQUEST)} → chose ${CHOSEN}`)
console.log('Estimates in characters; tokens ≈ chars/4. Measures the interface, not model quality.')
