#!/usr/bin/env node

// `grep -q` and `head` stop reading as soon as they have their answer. Upstream then dies of
// SIGPIPE with status 141, and under `pipefail` that becomes the pipeline's verdict, so a
// successful search reads as a failure. This repo has been bitten three times: twice found and
// fixed, once written straight back in by someone who had already fixed it. A lesson that lives
// in prose gets repeated, so it lives here now.

import { readFileSync, existsSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..')

const SHELL = /\.(sh|bash)$|(^|\/)(pre-commit|pre-push|mastermind)$/
const PIPEFAIL = /set\s+-[a-zA-Z]*o\s+pipefail|set\s+-o\s+pipefail/
// Only `grep -q`, and only downstream of a pipe. `head` is left alone: it is nearly always
// deliberate truncation of display output, where the status is discarded, and flagging it buries
// the one case that matters. `||` and `&&` are not pipes, hence the negative look.
const EARLY_EXIT = /(?<![|&])\|(?!\|)\s*grep\s+(-[a-zA-Z]*q\b|--quiet)/

const tracked = () =>
  execFileSync('git', ['-C', REPO, 'ls-files', '-z'], { encoding: 'utf8', maxBuffer: 64 << 20 })
    .split('\0')
    .filter((f) => f && SHELL.test(f) && !f.startsWith('evals/'))

const findings = []
for (const file of tracked()) {
  const path = join(REPO, file)
  if (!existsSync(path)) continue
  const text = readFileSync(path, 'utf8')
  if (!PIPEFAIL.test(text)) continue
  text.split('\n').forEach((line, i) => {
    const bare = line.replace(/#.*$/, '')
    if (EARLY_EXIT.test(bare)) findings.push({ file, line: i + 1, text: line.trim().slice(0, 96) })
  })
}

if (findings.length) {
  console.error(`✖ ${findings.length} pipeline(s) whose reader exits early, under pipefail:\n`)
  for (const f of findings) console.error(`  ${f.file}:${f.line}  ${f.text}`)
  console.error('\nThe writer takes SIGPIPE and the pipeline reports 141, so a match reads as a miss.')
  console.error('Read into a variable first, then match with a here-string: grep -q PATTERN <<<"$VAR"')
  process.exit(1)
}

console.log('✓ no early-exit pipeline reader under pipefail.')
