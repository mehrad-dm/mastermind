#!/usr/bin/env node
// Does the brain actually steer a Cursor session? Claude Code has `auto-invoke.mjs` and Codex
// has `codex-routing.mjs`; Cursor had neither, so every claim about it rested on a rule file
// being in the right place. MasterMind's skills are not native to Cursor either, so the
// question is the same one: does the kernel make it NAME the right skill?
import { execFileSync } from 'node:child_process'
import { mkdtempSync, mkdirSync, rmSync } from 'node:fs'
import { tmpdir, homedir } from 'node:os'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
// The same three cases the Codex eval uses, so the two tools stay comparable.
const CASES = [
  { prompt: 'I am stopping for today, set things up so tomorrow picks up cleanly', expected: ['handoff'] },
  { prompt: 'cancelling an order sometimes leaves the stock count wrong and I cannot see why', expected: ['debug'] },
  { prompt: 'there is a .env with live credentials in here and I do not want it reaching github', expected: ['quarantine'] },
]
const SKIP = 2

// Installed by a script that does not always land on PATH, so look where it puts it.
const CLI = ['cursor-agent', join(homedir(), '.local/bin/cursor-agent')].find((c) => {
  try { execFileSync(c, ['--version'], { stdio: 'ignore' }); return true } catch { return false }
})
if (!CLI) { console.error('cursor-agent not installed: cannot measure the Cursor path here'); process.exit(SKIP) }

const run = (args, opts = {}) =>
  execFileSync(CLI, args, { encoding: 'utf8', maxBuffer: 16 << 20, stdio: ['ignore', 'pipe', 'pipe'], timeout: 300000, ...opts })

// The CLI resolves its login from the real home, so the measured calls keep it. Only
// install.sh gets a scratch HOME, because that is the part that could write into the real one.
const ENV = { ...process.env }

try {
  const probe = run(['-p', '--output-format', 'text', '--mode', 'ask', '--trust', 'Reply with the single word OK.'], { env: ENV })
  if (!/\bOK\b/i.test(probe)) throw new Error(probe.slice(-300))
} catch (e) {
  const why = String(e?.stdout || '') + String(e?.stderr || '') + String(e?.message || '')
  const env = /log ?in|logged out|auth|api key|401|403|quota|rate limit|subscription|expired/i.test(why)
  console.error(`cursor-agent is installed but cannot run a session${env ? ' (account or auth)' : ''}:`)
  console.error(why.trim().split('\n').slice(-3).join('\n'))
  // Only an environment we cannot control is a skip. Anything else is the CLI or
  // this harness failing, and reporting that as "not a regression" is how a broken
  // gate reads green to whoever accepts the skip.
  process.exit(env ? SKIP : 1)
}

const work = mkdtempSync(join(tmpdir(), 'mm-cursor-'))
const proj = join(work, 'proj')
const home = join(work, 'home')
mkdirSync(proj, { recursive: true })
mkdirSync(home, { recursive: true })

try {
  execFileSync('git', ['init', '-q', '.'], { cwd: proj })
  execFileSync('bash', [join(ROOT, 'install.sh'), 'cursor'], {
    cwd: proj, stdio: 'ignore', timeout: 300000, env: { ...process.env, HOME: home },
  })
} catch (e) {
  rmSync(work, { recursive: true, force: true })
  // A failed install is a regression, not an environment skip. A missing CLI and a dead account
  // were both ruled out above, so anything reaching here is ours.
  console.error(`installing into a scratch project failed, which is a regression, not an environment problem:\n${e?.message || e}`)
  process.exit(1)
}

const ask = (prompt, where) => {
  const q = `${prompt}\n\nName the single MasterMind skill you would use for this, lowercase, one word, nothing else.`
  try {
    return run(['-p', '--output-format', 'text', '--mode', 'ask', '--trust', q], { cwd: where, env: ENV })
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
console.log(`\ncursor routing: ${hits}/${results.length}`)
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
  console.error(`${results.length - hits} case(s) did not route: the kernel reached Cursor but did not steer it.`)
  process.exit(1)
}
process.exit(0)
