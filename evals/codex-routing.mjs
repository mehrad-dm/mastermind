#!/usr/bin/env node
// Does the brain actually steer a Codex session? Claude Code has `auto-invoke.mjs`; Codex had
// nothing, so every claim about it rested on a file being in the right place. MasterMind's skills
// are not native to Codex, so the question is whether the kernel makes it NAME the right skill.
import { execFileSync } from 'node:child_process'
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const CASES = [
  { prompt: 'I am stopping for today, set things up so tomorrow picks up cleanly', expected: ['handoff'] },
  { prompt: 'cancelling an order sometimes leaves the stock count wrong and I cannot see why', expected: ['debug'] },
  { prompt: 'there is a .env with live credentials in here and I do not want it reaching github', expected: ['quarantine'] },
]
const SKIP = 2

try { execFileSync('codex', ['--version'], { stdio: 'ignore' }) }
catch { console.error('codex CLI not installed: cannot measure the Codex path here'); process.exit(SKIP) }

// The CLI resolves its login from the real home, so the measured calls keep it. Only
// install.sh gets a scratch HOME, because that is the part that could write into the real one.
const ENV = { ...process.env }

try {
  const probe = execFileSync('codex', ['exec', '-s', 'read-only', '--skip-git-repo-check', 'Reply with the single word OK.'],
    { encoding: 'utf8', maxBuffer: 1 << 20, stdio: ['ignore', 'pipe', 'pipe'], timeout: 120000, env: ENV })
  if (!/\bOK\b/i.test(probe)) throw new Error(probe.slice(-300))
} catch (e) {
  const why = String(e?.stdout || '') + String(e?.stderr || '') + String(e?.message || '')
  const env = /not supported when using Codex|invalid_request_error|401|403|login|expired|quota|rate limit/i.test(why)
  console.error(`codex is installed but cannot run a session${env ? ' (account or model access)' : ''}:`)
  console.error(why.trim().split('\n').slice(-3).join('\n'))
  process.exit(SKIP)
}

const work = mkdtempSync(join(tmpdir(), 'mm-codex-'))
const proj = join(work, 'proj')
mkdirSync(proj, { recursive: true })
mkdirSync(join(work, 'home'), { recursive: true })
try {
  execFileSync('git', ['init', '-q', '.'], { cwd: proj })
  execFileSync('bash', [join(ROOT, 'install.sh'), 'codex'], {
    cwd: proj, stdio: 'ignore', env: { ...process.env, HOME: join(work, 'home') },
  })
} catch (e) {
  rmSync(work, { recursive: true, force: true })
  // A failed install is a regression, not an environment skip. Only a missing CLI is a skip, and
  // that was checked above, so anything reaching here is ours.
  console.error(`installing into a scratch project failed, which is a regression, not an environment problem:\n${e?.message || e}`)
  process.exit(1)
}

const ask = (prompt, where) => {
  const q = `${prompt}\n\nName the single MasterMind skill you would use for this, lowercase, one word, nothing else.`
  try {
    return execFileSync('codex', ['exec', '-s', 'read-only', '--skip-git-repo-check', '-C', where, q],
      { encoding: 'utf8', maxBuffer: 16 << 20, stdio: ['ignore', 'pipe', 'pipe'], timeout: 300000,
        env: ENV })
  } catch { return '' }
}

const bare = join(work, 'bare')
mkdirSync(bare, { recursive: true })
try { execFileSync('git', ['init', '-q', '.'], { cwd: bare }) } catch { /* control is best-effort */ }

const results = []
for (const c of CASES) {
  const out = ask(c.prompt, proj).toLowerCase()
  const ctl = ask(c.prompt, bare).toLowerCase()
  const match = (t) => c.expected.some((e) => new RegExp(`\\b${e}\\b`).test(t))
  const hit = match(out)
  const control = match(ctl)
  results.push({ ...c, hit, control })
  console.log(`  ${hit ? '✓' : '✗'} ${c.expected.join('|').padEnd(14)} ${c.prompt.slice(0, 46)}` +
    `${control ? '   (control also named it)' : ''}`)
}
rmSync(work, { recursive: true, force: true })

const hits = results.filter((r) => r.hit).length
console.log(`\ncodex routing: ${hits}/${results.length}`)
// Failing only at zero lets two of three misroutes ship green. Every case must route: the set is
// small and deliberately unambiguous, so one miss is a regression and not variance.
const controls = results.filter((r) => r.control).length
const delta = results.filter((r) => r.hit && !r.control).length
console.log(`control (no brain installed): ${controls}/${results.length} named the same skill`)
console.log(`attributable to MasterMind:   ${delta}/${results.length} routed only with the brain`)
// Attribution is reported, never gated. Measured 2026-08-30: with the brain installed
// the control named the same skill in 3/3, and a control that keeps the brain files but
// drops the rule wiring still answers like the treatment, because the agent reads
// `.mastermind/` itself. A control that removes the files is no longer the same project.
// So delta 0 is not evidence of no steering, and failing on it fails a working brain.
console.log('(attribution is a trend, not a gate: these skill names are guessable, so the control often names them too.)')
if (hits < results.length) {
  console.error(`${results.length - hits} case(s) did not route: the kernel reached Codex but did not steer it.`)
  process.exit(1)
}
process.exit(0)
