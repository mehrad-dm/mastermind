#!/usr/bin/env node
// Does the brain actually steer a Cursor session? Asks a live Cursor CLI session to name the
// skill it would use, in a project with the brain and in a bare one, REPS times each.
import { execFileSync } from 'node:child_process'
import { mkdtempSync, mkdirSync, rmSync } from 'node:fs'
import { tmpdir, homedir } from 'node:os'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { cliAnswer, cliFailure, tally, verdict } from './classify.mjs'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
// The first three cases of the Codex eval, so the two tools stay comparable. They ask a session
// to NAME a skill from the kernel's menu, the route a user-only skill (handoff) keeps.
const CASES = [
  { prompt: 'I am stopping for today, set things up so tomorrow picks up cleanly', expected: ['handoff'] },
  { prompt: 'cancelling an order sometimes leaves the stock count wrong and I cannot see why', expected: ['debug'] },
  { prompt: 'there is a .env with live credentials in here and I do not want it reaching github', expected: ['quarantine'] },
]
const SKIP = 2
const REPS = Math.max(1, Number(process.env.REPS || 1))

// The CLI was `cursor-agent` and is now also installed as `agent`, a name other tools use too,
// so a candidate counts only when its own help says it is Cursor's.
const isCursor = (c) => {
  try { return /cursor/i.test(execFileSync(c, ['--help'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 30000 })) }
  catch { return false }
}
const CLI = [process.env.MM_CURSOR, 'cursor-agent', 'agent', join(homedir(), '.local/bin/cursor-agent'), join(homedir(), '.local/bin/agent')]
  .filter(Boolean).find(isCursor)
if (!CLI) { console.error('no Cursor CLI found (looked for cursor-agent and agent): cannot measure the Cursor path here'); process.exit(SKIP) }

// The CLI resolves its login from the real home, so the measured calls keep it. Only install.sh
// gets a scratch HOME, because that is the part that could write into the real one.
const run = (prompt, cwd) => cliAnswer(
  execFileSync(CLI, ['-p', '--output-format', 'text', '--mode', 'ask', '--trust', prompt],
    { encoding: 'utf8', maxBuffer: 16 << 20, stdio: ['ignore', 'pipe', 'pipe'], timeout: 300000, cwd }))

const work = mkdtempSync(join(tmpdir(), 'mm-cursor-'))
process.on('exit', () => rmSync(work, { recursive: true, force: true }))
const proj = join(work, 'proj')
const bare = join(work, 'bare')
for (const d of [proj, bare, join(work, 'home')]) mkdirSync(d, { recursive: true })

try {
  const probe = run('Reply with the single word OK.', bare)
  if (!/\bOK\b/i.test(probe)) throw Object.assign(new Error('the probe did not answer OK'), { stdout: probe })
} catch (e) {
  const f = cliFailure(e)
  console.error(`${CLI} is installed but cannot run a session (${f.kind === 'account' ? 'account or login' : f.kind}): ${f.why}`)
  console.error(String(e?.stderr || e?.message || '').trim().split('\n').slice(-3).join('\n'))
  // Only an account we cannot control is a skip. Anything else is the CLI or this harness failing.
  process.exit(f.kind === 'account' ? SKIP : 1)
}

try {
  for (const d of [proj, bare]) execFileSync('git', ['init', '-q', '.'], { cwd: d })
  execFileSync('bash', [join(ROOT, 'install.sh'), 'cursor'], {
    cwd: proj, stdio: 'ignore', timeout: 300000, env: { ...process.env, HOME: join(work, 'home'), MM_NO_NETWORK: '1' },
  })
} catch (e) {
  console.error(`installing into a scratch project failed, which is a regression, not an environment problem:\n${e?.message || e}`)
  process.exit(1)
}

let account = ''
const ask = (prompt, where) => {
  const q = `${prompt}\n\nName the single MasterMind skill you would use for this, lowercase, one word, nothing else.`
  for (let attempt = 0; attempt < 2; attempt++) {
    try { return { text: run(q, where).toLowerCase() } }
    catch (e) {
      const f = cliFailure(e)
      if (f.kind === 'account') { account = f.why; return { failed: true } }
    }
  }
  return { failed: true }
}

const cases = []
for (const c of CASES) {
  const match = (t) => c.expected.some((e) => new RegExp(`\\b${e}\\b`).test(t))
  const runs = []
  for (let i = 0; i < REPS && !account; i++) {
    const out = ask(c.prompt, proj)
    const ctl = out.failed || account ? { failed: true } : ask(c.prompt, bare)
    runs.push(out.failed || ctl.failed ? { failed: true } : { hit: match(out.text), control: match(ctl.text) })
  }
  const t = { ...c, ...tally(runs), account: !!account }
  cases.push(t)
  const mark = t.reps === 0 ? '?' : t.hits * 2 > t.reps ? '✓' : '✗'
  console.log(`  ${mark} ${c.expected.join('|').padEnd(12)} with the brain ${t.hits}/${t.reps} · without ${t.control}/${t.reps}`
    + `${t.failed ? ` · ${t.failed} could not run` : ''}   ${c.prompt.slice(0, 40)}`)
  if (account) break
}

const sum = (k) => cases.reduce((n, c) => n + c[k], 0)
console.log(`\ncursor routing: with the brain ${sum('hits')}/${sum('reps')} · without it ${sum('control')}/${sum('reps')}`)
// The control is reported, never gated: these skill names are guessable, so a bare session
// often names them too, and a delta of zero does not show the brain failed to steer.
const v = verdict(cases)
if (account) console.error(`the Cursor CLI could not finish the run (account or quota, not a regression): ${account.slice(0, 200)}`)
else if (v.code === 1) console.error(`${v.why}: the kernel reached Cursor but did not steer it.`)
else if (v.code === 2) console.error(`${sum('failed')} session(s) could not run, so the result is incomplete: this is not a routing miss.`)
process.exit(v.code)
