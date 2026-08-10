#!/usr/bin/env node
import { execFile, execFileSync } from 'node:child_process'
import { mkdtempSync, mkdirSync, rmSync, readdirSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const FULL = !!process.env.FULL
const REPS = Number(process.env.REPS || (FULL ? 3 : 1))
const MODEL = process.env.MODEL || 'sonnet'
const POOL = Number(process.env.POOL || 4)

const isHit = (c, got) => (c.forbidden ? !c.forbidden.includes(got) : !!(got && c.expected.includes(got)))
const label = (c) => (c.forbidden ? `not:${c.forbidden.join('|')}` : c.expected.join('|'))

const CORE = [
  { prompt: 'add a way to mark an order as urgent', expected: ['build'] },
  { prompt: 'cancelling an order sometimes leaves the stock count wrong, I cannot see why', expected: ['debug'] },
  { prompt: 'the orders list takes forever when there are lots of orders', expected: ['performance'] },
  { prompt: 'before I demo this to the client, make sure the cart flow actually holds up', expected: ['qa'] },
  { prompt: 'interview me about the discounts feature before you build anything', expected: ['interview'] },
  { prompt: "there is a .env with live credentials in here and I do not want it reaching github", expected: ['quarantine'] },
  { prompt: 'you said the discount rounding was fixed, are you certain? check yourself before I merge', expected: ['double-check', 'qa', 'code-reviewer'] },
  { prompt: 'we want to kill the legacy cart endpoint, find out if anything still uses it', expected: ['deprecate'] },
]
const EXTRA = [
  { prompt: 'I have no idea if streaming uploads will even work with our setup, find out fast', expected: ['prototype', 'learn'] },
  { prompt: 'write a proper guide for our internal auth package, people keep misusing it', expected: ['explain'] },
  { prompt: 'I am stopping here today, set things up so we can resume cleanly tomorrow', expected: ['handoff'] },
  { prompt: 'you keep formatting things differently from the rest of our code, learn our way', expected: ['signature'] },
  { prompt: 'we always use 2-space indent in this repo, you used tabs, keep that in mind from now on', expected: ['levelup', 'signature'] },
  { prompt: 'sharpen this prompt before I send it: summarize customer feedback by theme', expected: ['prompt'] },
  { prompt: 'summarize the customer feedback in this repo by theme and list the top 3 complaints', forbidden: ['prompt'] },
  { prompt: 'what can you actually do for me here?', expected: ['help'] },
]
const ONLY = process.env.ONLY
const ALL = FULL ? [...CORE, ...EXTRA] : CORE
const CASES = ONLY ? [...CORE, ...EXTRA].filter((c) => c.prompt.includes(ONLY)) : ALL

const DECOYS = [
  ['code-review', 'Review code for bugs, style and best practices. Use when the user asks to review changes, check a diff, or look over code before merging.'],
  ['optimize', 'Speed things up. Use for slow pages, slow queries, high memory, long load times, or any performance problem.'],
  ['test-writer', 'Write and run tests. Use when the user wants tests, wants to verify something works, or asks if the code is ready.'],
  ['bug-hunter', 'Find and fix bugs. Use when something is broken, errors appear, behaviour is wrong, or a fix does not stick.'],
  ['feature-builder', 'Implement new features end to end. Use when the user asks to add, build, create or implement anything.'],
  ['doc-writer', 'Write documentation for code, APIs and packages. Use when docs are missing or people misuse an interface.'],
  ['requirements', 'Clarify requirements before building. Use when the request is vague, or the user wants to be asked questions about scope.'],
  ['cleanup', 'Remove dead code and unused endpoints. Use when deleting features or retiring old APIs.'],
  ['secrets-guard', 'Keep credentials and private data out of the repository.'],
  ['session-notes', 'Save context so work can continue later.'],
]

const KNOWN = readdirSync(join(ROOT, 'skills'), { withFileTypes: true })
  .filter((e) => e.isDirectory())
  .map((e) => e.name)

const announced = (raw) => {
  let memoryWrite = false
  for (const line of raw.split('\n')) {
    try {
      const j = JSON.parse(line)
      for (const c of j?.message?.content || []) {
        if (c.type === 'tool_use' && c.name === 'Skill' && c.input?.skill) return c.input.skill
        if (c.type === 'tool_use' && /^(Write|Edit)$/.test(c.name) && /\/memory\//.test(c.input?.file_path || ''))
          memoryWrite = true
      }
    } catch { /* non-JSON line */ }
  }
  if (memoryWrite) return 'levelup'
  let text = ''
  for (const line of raw.split('\n')) {
    try {
      const j = JSON.parse(line)
      for (const c of j?.message?.content || []) if (c.type === 'text') text += c.text + '\n'
    } catch { /* ignore */ }
  }
  const m = text.slice(0, 1200).match(/└\s*`?([a-z][a-z-]*)`?/)
  return m && KNOWN.includes(m[1]) ? m[1] : null
}

const sh = (args, opts) => new Promise((res) => {
  execFile('claude', args, { maxBuffer: 32 * 1024 * 1024, timeout: Number(process.env.TIMEOUT_MS || 600000), ...opts }, (err, stdout, stderr) =>
    res({ out: String(stdout || ''), err, stderr: String(stderr || '') }))
})

const INFRA = /not logged in|unauthorized|invalid api key|authentication|credit balance|rate limit|overloaded/i
const infraReason = ({ out, err, stderr }) => {
  if (err && err.killed) return 'timed out'
  if (INFRA.test(stderr)) return (stderr.match(INFRA) || ['unknown'])[0].toLowerCase()
  if (err && !out.trim()) return `claude exited ${err.code ?? '?'}`
  return null
}

try { execFileSync('claude', ['--version'], { stdio: 'ignore' }) }
catch {
  console.log('SKIP: claude CLI not available, and auto-invoke needs a live session')
  process.exit(2)
}

// Outside the repo: a nested workspace lets the session discover this repo's own files.
const work = mkdtempSync(join(tmpdir(), 'mm-autoinvoke-'))
process.on('exit', () => rmSync(work, { recursive: true, force: true }))
execFileSync('git', ['init', '-q', work])
execFileSync('cp', ['-R', join(ROOT, 'evals', 'runs', 'v0.27-real', 'seed') + '/.', work])
const fakeHome = join(work, '.home')
mkdirSync(fakeHome, { recursive: true })
execFileSync('bash', [join(ROOT, 'install.sh')], { cwd: work, stdio: 'ignore', env: { ...process.env, HOME: fakeHome } })

if (process.env.CROWDED) {
  for (const [name, description] of DECOYS) {
    const dir = join(work, '.claude', 'skills', name)
    mkdirSync(dir, { recursive: true })
    writeFileSync(join(dir, 'SKILL.md'),
      `---\nname: ${name}\ndescription: ${description}\n---\n\n# ${name}\n\nDo the thing.\n`)
  }
  console.log(`crowded install: ${DECOYS.length} foreign skills alongside ${KNOWN.length} MasterMind skills`)
}

const runBatch = async (batch) => {
  const out = []
  let cursor = 0
  await Promise.all(Array.from({ length: POOL }, async () => {
    for (;;) {
      const job = batch[cursor++]
      if (!job) return
      const r = await sh(
        ['-p', job.prompt, '--setting-sources', 'project,local', '--model', MODEL,
         '--max-turns', '4', '--permission-mode', 'acceptEdits',
         '--output-format', 'stream-json', '--verbose'],
        { cwd: work },
      )
      out.push({ ...job, got: announced(r.out), infra: infraReason(r) })
    }
  }))
  return out
}

const jobs = []
for (const c of CASES) for (let r = 0; r < REPS; r++) jobs.push({ ...c, r })
let results = await runBatch(jobs)

if (!FULL) {
  const missed = results.filter((r) => !isHit(r, r.got))
  if (missed.length) {
    const second = await runBatch(missed.map(({ prompt, expected, forbidden }) => ({ prompt, expected, forbidden, r: 1 })))
    results = results.map((r) => second.find((x) => x.prompt === r.prompt && isHit(x, x.got)) || r)
  }
}

const decoyNames = new Set(DECOYS.map(([n]) => n))
let broken = results.filter((r) => r.infra)
if (broken.length) {
  const retried = await runBatch(broken.map(({ prompt, expected, forbidden }) => ({ prompt, expected, forbidden, r: 9 })))
  results = results.map((r) => {
    if (!r.infra) return r
    const again = retried.find((x) => x.prompt === r.prompt)
    return again && !again.infra ? again : r
  })
  broken = results.filter((r) => r.infra)
}
if (broken.length) {
  const reasons = [...new Set(broken.map((r) => r.infra))].join(', ')
  console.error(`✖ harness failure: ${broken.length}/${results.length} sessions could not run (${reasons}).`)
  console.error('  This says nothing about routing. Fix the environment and re-run.')
  process.exit(2)
}

const rows = []
let hit = 0, none = 0, foreign = 0
const flaky = []
for (const c of CASES) {
  const mine = results.filter((r) => r.prompt === c.prompt)
  const good = mine.filter((r) => isHit(c, r.got)).length
  hit += good
  none += mine.filter((r) => !r.got).length
  foreign += mine.filter((r) => r.got && decoyNames.has(r.got)).length
  if (mine.length > 1 && good > 0 && good < mine.length) flaky.push(`${label(c)} (${good}/${mine.length})`)
  rows.push({
    prompt: c.prompt.slice(0, 44),
    expected: label(c),
    fired: mine.map((r) => r.got || ', ').join(','),
    hit: mine.length > 1 ? `${good}/${mine.length}` : (good ? 'yes' : 'no'),
  })
}
console.table(rows)
const total = results.length
console.log(`announced a skill: ${total - none}/${total} · expected skill: ${hit}/${total} (${((hit / total) * 100).toFixed(0)}%)`)
if (REPS > 1) {
  // With reps, report the band the runs actually fell in. One number from one rep is noise.
  const perRep = Array.from({ length: REPS }, (_, i) =>
    CASES.filter((c) => {
      const r = results.filter((x) => x.prompt === c.prompt)[i]
      return r && isHit(c, r.got)
    }).length)
  console.log(`per-rep: ${perRep.map((n) => `${n}/${CASES.length}`).join(' · ')}, read the range, not the mean`)
  if (flaky.length) console.log(`unstable across reps: ${flaky.join(', ')}`)
}
if (process.env.CROWDED) console.log(`a foreign skill won: ${foreign}/${total}`)
if (FULL) {
  const fired = new Set(results.map((r) => r.got).filter(Boolean))
  const unmet = CASES.filter((c) => !results.filter((r) => r.prompt === c.prompt).some((r) => isHit(c, r.got)))
  const never = KNOWN.filter((k) => !fired.has(k) && unmet.some((c) => c.expected?.includes(k)))
  if (never.length) console.log('prompted but NEVER fired (fix or cut):', never.join(', '))
}
const bar = Math.ceil(total * 0.75)
process.exit(total - none >= bar && hit >= bar ? 0 : 1)
