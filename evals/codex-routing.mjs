#!/usr/bin/env node
// Does the brain actually steer a Codex session? Asks a live `codex exec` session to name the
// skill it would use, in a project with the brain and in a bare one, REPS times each.
import { execFileSync } from 'node:child_process'
import { mkdtempSync, mkdirSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { cliFailure, codexModel, codexTrust, tally, verdict } from './classify.mjs'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
// These ask a session to NAME a skill from the kernel's menu. That is the route a user-only skill
// (handoff) keeps, so the case stands whether or not the model may fire it.
const CASES = [
  { prompt: 'I am stopping for today, set things up so tomorrow picks up cleanly', expected: ['handoff'] },
  { prompt: 'cancelling an order sometimes leaves the stock count wrong and I cannot see why', expected: ['debug'] },
  { prompt: 'there is a .env with live credentials in here and I do not want it reaching github', expected: ['quarantine'] },
  { prompt: 'we want customers to set up invoices that repeat every month. before any code, pin down exactly what it has to do and how we will know it works', expected: ['specify'] },
  { prompt: 'the team says CSV export is finished. compare the code with specs/007-export and show me where it falls short', expected: ['converge'] },
]
const SKIP = 2
const REPS = Math.max(1, Number(process.env.REPS || 1))

// MM_CODEX names the command when it is not `codex` on PATH, for example "npx -y @openai/codex".
const [BIN, ...PRE] = (process.env.MM_CODEX || 'codex').trim().split(/\s+/)
const codex = (args, opts = {}) =>
  execFileSync(BIN, [...PRE, ...args], { encoding: 'utf8', maxBuffer: 16 << 20, stdio: ['ignore', 'pipe', 'pipe'], timeout: 300000, ...opts })

try { codex(['--version'], { timeout: 120000 }) }
catch { console.error(`${BIN} is not installed: cannot measure the Codex path here (set MM_CODEX to the command)`); process.exit(SKIP) }

let catalog = ''
try { catalog = codex(['debug', 'models'], { timeout: 120000 }) } catch { /* an old CLI has no catalog command */ }
const MODEL = codexModel(process.env, catalog)
const WITH_MODEL = MODEL ? ['-m', MODEL] : []
console.log(MODEL ? `model: ${MODEL}${process.env.MM_CODEX_MODEL ? ' (MM_CODEX_MODEL)' : ' (first listed for this account)'}`
  : 'model: the CLI default (the catalog could not be read; set MM_CODEX_MODEL to choose)')

// The CLI resolves its login from the real home, so the measured calls keep it. Only install.sh
// gets a scratch HOME, because that is the part that could write into the real one.
const exec = (prompt, where) =>
  codex(['exec', '-s', 'read-only', '--skip-git-repo-check', '--ephemeral', ...WITH_MODEL, ...codexTrust(where), '-C', where, prompt])

const work = mkdtempSync(join(tmpdir(), 'mm-codex-'))
process.on('exit', () => rmSync(work, { recursive: true, force: true }))
const proj = join(work, 'proj')
const bare = join(work, 'bare')
for (const d of [proj, bare, join(work, 'home')]) mkdirSync(d, { recursive: true })

try {
  const probe = exec('Reply with the single word OK.', bare)
  if (!/\bOK\b/i.test(probe)) throw Object.assign(new Error('the probe did not answer OK'), { stdout: probe })
} catch (e) {
  const f = cliFailure(e)
  console.error(`codex is installed but cannot run a session (${f.kind === 'account' ? 'account or model access' : f.kind}): ${f.why}`)
  console.error(String(e?.stderr || e?.message || '').trim().split('\n').slice(-3).join('\n'))
  // Only an account we cannot control is a skip. Anything else is the CLI or this harness failing.
  process.exit(f.kind === 'account' ? SKIP : 1)
}

try {
  for (const d of [proj, bare]) execFileSync('git', ['init', '-q', '.'], { cwd: d })
  execFileSync('bash', [join(ROOT, 'install.sh'), 'codex'], {
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
    try { return { text: exec(q, where).toLowerCase() } }
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
console.log(`\ncodex routing: with the brain ${sum('hits')}/${sum('reps')} · without it ${sum('control')}/${sum('reps')}`)
// The control is reported, never gated: these skill names are guessable, so a bare session
// often names them too, and a delta of zero does not show the brain failed to steer.
const v = verdict(cases)
if (account) console.error(`codex could not finish the run (account or quota, not a regression): ${account.slice(0, 200)}`)
else if (v.code === 1) console.error(`${v.why}: the kernel reached Codex but did not steer it.`)
else if (v.code === 2) console.error(`${sum('failed')} session(s) could not run, so the result is incomplete: this is not a routing miss.`)
process.exit(v.code)
