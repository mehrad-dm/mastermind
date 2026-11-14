#!/usr/bin/env node

// A check nobody has watched fail is not known to work. Each gate carries inputs it must fire
// on and inputs it must stay clean on (scripts/fixtures/), and this runs them all.

import { spawnSync } from 'node:child_process'
import { mkdtempSync, mkdirSync, rmSync, writeFileSync, chmodSync } from 'node:fs'
import { tmpdir } from 'node:os'
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
  'scripts/check-prose.mjs',
  'scripts/lint-brain.mjs',
  'scripts/build-router.mjs',
  'scripts/build-architecture.mjs',
  'evals/agent-surface-routing.mjs',
  'evals/auto-invoke.mjs',
  'evals/classify.mjs',
]
// Each self-test ends on this line. A gate whose bad inputs are all gone says 0 and fails here.
const COUNTS = /(\d+) bad inputs? fires?, (\d+) good inputs? stays? clean/

let failed = 0
const judge = (gate, status, said) => {
  const counts = said.split('\n').pop().match(COUNTS)
  // A script that ignores the flag would run its real check and exit 0, so the line is required too.
  if (status !== 0 || !counts || +counts[1] === 0) {
    failed++
    const why = status !== 0 ? `exit ${status}` : !counts ? 'no "N bad inputs fire, M good inputs stay clean" line' : 'no bad input fired'
    console.error(`✖ ${gate} --self-test (${why}):\n${said.split('\n').map((l) => '    ' + l).join('\n')}`)
  } else console.log(said.split('\n').pop())
}

for (const gate of GATES) {
  const r = spawnSync('node', [join(ROOT, gate), '--self-test'], { encoding: 'utf8', cwd: ROOT })
  judge(gate, r.status, `${r.stdout}${r.stderr}`.trim())
}

// validate-plugin.sh shells out to claude, so a stub stands in for it under a scratch HOME and PATH.
{
  const box = mkdtempSync(join(tmpdir(), 'mm-validate-'))
  const bin = join(box, 'bin')
  mkdirSync(bin)
  writeFileSync(join(bin, 'claude'), `#!/usr/bin/env bash\nexec bash ${JSON.stringify(join(ROOT, 'scripts', 'fixtures', 'claude-stub.sh'))} "$@"\n`)
  chmodSync(join(bin, 'claude'), 0o755)
  const want = { clean: 0, accepted: 0, silent: 1, real: 1 }
  const wrong = []
  for (const [mode, code] of Object.entries(want)) {
    const r = spawnSync('bash', [join(ROOT, 'scripts', 'validate-plugin.sh')], {
      encoding: 'utf8', cwd: ROOT,
      env: { ...process.env, HOME: box, PATH: `${bin}:${process.env.PATH}`, STUB_MODE: mode, MM_REQUIRE_CLAUDE: '' },
    })
    if (r.status !== code) wrong.push(`${mode}: wanted exit ${code}, got ${r.status}: ${`${r.stdout}${r.stderr}`.trim().split('\n').pop()}`)
  }
  rmSync(box, { recursive: true, force: true })
  const fires = Object.values(want).filter((c) => c !== 0).length
  judge('scripts/validate-plugin.sh', wrong.length ? 1 : 0, wrong.length
    ? `✖ validate-plugin self-test:\n  ${wrong.join('\n  ')}`
    : `✓ validate-plugin self-test: ${fires} bad inputs fire, ${Object.keys(want).length - fires} good inputs stay clean (a stub claude: a real finding and a strict failure that names none both fail).`)
}

const total = GATES.length + 1
if (failed) { console.error(`\n✖ ${failed} gate(s) do not behave on their own fixtures.`); process.exit(1) }
console.log(`\n✓ all ${total} gates fire on their bad fixtures and stay clean on their good ones.`)
