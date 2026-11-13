#!/usr/bin/env node

// A check nobody has watched fail is not known to work. Each gate carries inputs it must fire
// on and inputs it must stay clean on (scripts/fixtures/), and this runs them all.

import { spawnSync } from 'node:child_process'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const GATES = [
  'scripts/check-shell-patterns.mjs',
  'scripts/check-comments.mjs',
  'scripts/check-instructions.mjs',
  'scripts/check-integrity.mjs',
  'scripts/check-links.mjs',
  'scripts/check-versions.mjs',
  'scripts/check-claims.mjs',
  'evals/agent-surface-routing.mjs',
  'evals/classify.mjs',
]

let failed = 0
for (const gate of GATES) {
  const r = spawnSync('node', [join(ROOT, gate), '--self-test'], { encoding: 'utf8', cwd: ROOT })
  const said = `${r.stdout}${r.stderr}`.trim()
  // A script that ignores the flag would run its real check and exit 0, so the line is required too.
  if (r.status !== 0 || !/self-test|classifiers/.test(said)) {
    failed++
    console.error(`✖ ${gate} --self-test (exit ${r.status}):\n${said.split('\n').map((l) => '    ' + l).join('\n')}`)
  } else console.log(said.split('\n').pop())
}
if (failed) { console.error(`\n✖ ${failed} gate(s) do not behave on their own fixtures.`); process.exit(1) }
console.log(`\n✓ all ${GATES.length} gates fire on their bad fixtures and stay clean on their good ones.`)
