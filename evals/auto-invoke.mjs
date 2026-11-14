#!/usr/bin/env node
import { execFile, execFileSync } from 'node:child_process'
import { mkdtempSync, mkdirSync, rmSync, readdirSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { outcome, hit as isHitFor } from './classify.mjs'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const FULL = !!process.env.FULL
const REPS = Number(process.env.REPS || (FULL ? 3 : 1))
const MODEL = process.env.MODEL || 'sonnet'
const POOL = Number(process.env.POOL || 4)

const want = (e) => (USER_ONLY.has(e) ? `menu:${e}` : e)
const negative = (c) => !!(c.forbidden || c.neverAutoFires)
const isHit = (c, got) => isHitFor(c, got, USER_ONLY)
const label = (c) => (c.neverAutoFires ? 'no user-only skill fired' : c.forbidden ? `not:${c.forbidden.join('|')}` : c.expected.map(want).join('|'))

const CORE = [
  { prompt: 'add a way to mark an order as urgent', expected: ['build'] },
  { prompt: 'cancelling an order sometimes leaves the stock count wrong, I cannot see why', expected: ['debug'] },
  { prompt: 'the orders list takes forever when there are lots of orders', expected: ['performance'] },
  { prompt: 'before I demo this to the client, make sure the cart flow actually holds up', expected: ['qa'] },
  { prompt: 'we need some kind of discounts thing in the shop. I only have a rough idea, so quiz me until you know what I actually want, and write no code yet', expected: ['interview'] },
  { prompt: "there is a .env with live credentials in here and I do not want it reaching github", expected: ['quarantine'] },
  { prompt: 'you said the discount rounding was fixed, are you certain? check yourself before I merge', expected: ['double-check', 'qa', 'code-reviewer'] },
  { prompt: 'that is me done for the day, back on this tomorrow morning', neverAutoFires: true },
  { prompt: 'nobody here thinks the old cart endpoint is needed any more. I want it gone without a customer noticing', expected: ['deprecate'] },
]
const EXTRA = [
  { prompt: 'I have no idea if streaming uploads will even work with our setup, find out fast', expected: ['prototype', 'learn'] },
  { prompt: 'three new hires misused our auth library this month. write something they can read so it stops happening', expected: ['explain'] },
  { prompt: 'I am stopping here today, set things up so we can resume cleanly tomorrow', expected: ['handoff'] },
  { prompt: 'you keep formatting things differently from the rest of our code, learn our way', expected: ['signature'] },
  { prompt: 'we always use 2-space indent in this repo, you used tabs, keep that in mind from now on', expected: ['levelup', 'signature'] },
  { prompt: 'I am about to paste this into another AI and I doubt it will get what I mean, fix it up first: summarize customer feedback by theme', expected: ['prompt'] },
  { prompt: 'summarize the customer feedback in this repo by theme and list the top 3 complaints', forbidden: ['prompt'] },
  { prompt: 'what can you actually do for me here?', expected: ['help'] },
  { prompt: 'I lost you halfway through that. say it again like I am new to all this', expected: ['clarify'] },
  { prompt: 'every small change in the orders code turns into a week of work. something about how it is put together is fighting us, show me what', expected: ['deepen'] },
  { prompt: 'my cofounder wants a referral program, I am not convinced people would use it, can we figure out if it is worth the effort', expected: ['assess'] },
  { prompt: 'two rules nobody here may ever break: card numbers never touch our database, and the app has to keep working without a connection. get that on record so every future change gets held to it', expected: ['constitution'] },
  { prompt: 'new people keep asking who our customers are and how we charge them, and the answers live in my head. put it somewhere in the repo that stays accurate', expected: ['living-docs'] },
  { prompt: 'we want customers to set up invoices that repeat every month. before any code, pin down exactly what it has to do and how we will know it works', expected: ['specify'] },
  { prompt: 'the invitations requirements in specs/004-invitations are signed off. now work out how we will actually implement them in this codebase', expected: ['blueprint'] },
  { prompt: 'turn the invitations design into an ordered list of small steps I can work through one at a time', expected: ['breakdown'] },
  { prompt: 'before anyone writes code for invitations, make sure the requirements, the design and the step list do not contradict each other or leave something out', expected: ['analyze'] },
  { prompt: 'blind users will sign up through the payments flow. before we plan it, tell me where the payments requirements leave their experience undefined', expected: ['checklist'] },
  { prompt: 'the team says CSV export is finished. compare the code with specs/007-export and show me where it falls short', expected: ['converge'] },
  { prompt: 'fix the typo in the footer copyright line', forbidden: ['specify', 'blueprint', 'breakdown', 'converge'] },
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

const USER_ONLY = new Set(KNOWN.filter((k) => {
  const head = readFileSync(join(ROOT, 'skills', k, 'SKILL.md'), 'utf8').match(/^---\n([\s\S]*?)\n---/)?.[1] ?? ''
  return /^disable-model-invocation:\s*true\s*$/m.test(head)
}))

// A prompt that repeats its target's description measures string matching, not routing.
const grams = (t) => {
  const w = String(t).toLowerCase().match(/[a-z0-9]+/g) ?? []
  return new Set(w.slice(2).map((_, i) => w.slice(i, i + 3).join(' ')))
}
const describe = (name) => readFileSync(join(ROOT, 'skills', name, 'SKILL.md'), 'utf8').match(/^description:\s*(.*)$/m)?.[1] ?? ''
function echoes(cases, desc = describe) {
  const out = []
  for (const c of cases) for (const target of c.expected ?? []) {
    if (!KNOWN.includes(target)) continue
    const said = grams(desc(target))
    const shared = [...grams(c.prompt)].filter((g) => said.has(g))
    if (shared.length) out.push(`"${c.prompt.slice(0, 50)}" repeats ${target}'s description: "${shared[0]}"`)
  }
  return out
}

if (process.argv.includes('--self-test')) {
  const planted = [
    { prompt: 'write me usage docs, people or AI sessions keep using it wrong', expected: ['explain'] },
    { prompt: 'you lost me: want it simpler or shorter', expected: ['clarify'] },
  ]
  const wrong = [
    ...planted.filter((c) => !echoes([c]).length).map((c) => `did not fire on a prompt that copies its description: ${c.prompt}`),
    ...echoes([...CORE, ...EXTRA]),
  ]
  if (wrong.length) { console.error('✖ auto-invoke self-test:\n  ' + wrong.join('\n  ')); process.exit(1) }
  console.log(`✓ auto-invoke self-test: ${planted.length} bad inputs fire, ${CORE.length + EXTRA.length} good inputs stay clean (no prompt shares three words in a row with its target's description).`)
  process.exit(0)
}
if (USER_ONLY.size) console.log(`user-only skills (reached through the menu, never fired): ${[...USER_ONLY].join(', ')}`)

const sh = (args, opts) => new Promise((res) => {
  execFile('claude', args, { maxBuffer: 32 * 1024 * 1024, timeout: Number(process.env.TIMEOUT_MS || 600000), ...opts }, (err, stdout, stderr) =>
    res({ out: String(stdout || ''), err, stderr: String(stderr || '') }))
})

try { execFileSync('claude', ['--version'], { stdio: 'ignore' }) }
catch {
  console.log('SKIP: claude CLI not available, and auto-invoke needs a live session')
  process.exit(2)
}

// Outside the repo: a nested workspace lets the session discover this repo's own files.
const root = mkdtempSync(join(tmpdir(), 'mm-autoinvoke-'))
process.on('exit', () => rmSync(root, { recursive: true, force: true }))
const work = join(root, 'proj')
const fakeHome = join(root, 'home')
const memory = join(root, 'memory')
for (const d of [work, fakeHome, memory]) mkdirSync(d, { recursive: true })
execFileSync('git', ['init', '-q', work])
execFileSync('cp', ['-R', join(ROOT, 'evals', 'runs', 'v0.27-real', 'seed') + '/.', work])
execFileSync('bash', [join(ROOT, 'install.sh')], { cwd: work, stdio: 'ignore', env: { ...process.env, HOME: fakeHome, MM_NO_NETWORK: '1' } })

// A session needs a login. With a key in the environment it runs under the scratch HOME; with a
// keychain login it keeps the real one, and auto-memory is pointed at the scratch directory.
const SANDBOXED = !!(process.env.ANTHROPIC_API_KEY || process.env.CLAUDE_CODE_OAUTH_TOKEN)
const SESSION_ENV = SANDBOXED ? { ...process.env, HOME: fakeHome } : process.env
mkdirSync(join(work, '.claude'), { recursive: true })
writeFileSync(join(work, '.claude', 'settings.local.json'), JSON.stringify({ autoMemoryDirectory: memory }, null, 2) + '\n')
console.log(SANDBOXED
  ? 'sessions run under a scratch HOME'
  : `sessions run under your HOME (no API key in the environment); memory writes go to ${memory}`)

// The spec-driven cases name feature folders, so a session can find what the user points at.
const FEATURES = {
  'specs/004-invitations/spec.md': '# Spec: team invitations\n\n**Status** clarified\n\n## User stories\n\n### US1: invite a teammate by email (P1)\n\n- **US1/AC1** When an owner sends an invite, the invitee receives an email with a link that expires in 7 days.\n\n## Requirements\n\n- **FR-001** Owners MUST be able to invite by email.\n- **FR-002** An invite MUST expire after 7 days.\n',
  'specs/004-invitations/plan.md': '# Plan: team invitations\n\n## Design\n\nAn `invites` table, a POST /invites endpoint, an email job, and an accept route that checks expiry.\n',
  'specs/005-payments/spec.md': '# Spec: card payments\n\n**Status** clarified\n\n## Requirements\n\n- **FR-001** Users MUST be able to pay for an order by card.\n- **FR-002** A receipt MUST be emailed after payment.\n',
  'specs/007-export/spec.md': '# Spec: CSV export\n\n**Status** building\n\n## Requirements\n\n- **FR-001** Users MUST be able to export orders to CSV.\n- **FR-002** Exports MUST include only the current workspace.\n- **FR-003** Exports over 10,000 rows MUST be refused with a message.\n',
  'specs/007-export/plan.md': '# Plan: CSV export\n\nAdd src/export.js with exportOrders(workspaceId) and a row limit check.\n',
  'specs/007-export/tasks.md': '# Tasks: CSV export\n\n- [x] T001 Add exportOrders in src/export.js (FR-001)\n- [x] T002 Filter by workspace in src/export.js (FR-002)\n- [x] T003 Refuse exports over 10,000 rows in src/export.js (FR-003)\n',
}
for (const [rel, text] of Object.entries(FEATURES)) {
  mkdirSync(join(work, dirname(rel)), { recursive: true })
  writeFileSync(join(work, rel), text)
}

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
        { cwd: work, env: SESSION_ENV },
      )
      out.push({ ...job, ...outcome(job, r, KNOWN, USER_ONLY) })
    }
  }))
  return out
}

// A retry carries the whole case, so a negative case keeps the flag that makes it negative.
const retry = ({ got, infra, hit, ...c }) => c
const jobs = []
for (const c of CASES) for (let r = 0; r < REPS; r++) jobs.push({ ...c, r })
let results = await runBatch(jobs)

if (!FULL) {
  const missed = results.filter((r) => !r.infra && !r.hit)
  if (missed.length) {
    const second = await runBatch(missed.map((r) => ({ ...retry(r), r: 1 })))
    results = results.map((r) => second.find((x) => x.prompt === r.prompt && x.hit) || r)
  }
}

const decoyNames = new Set(DECOYS.map(([n]) => n))
let broken = results.filter((r) => r.infra)
if (broken.length) {
  const retried = await runBatch(broken.map((r) => ({ ...retry(r), r: 9 })))
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
  if (!negative(c)) none += mine.filter((r) => !r.got).length
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
const positive = results.filter((r) => !negative(r)).length
console.log(`reached a skill: ${positive - none}/${positive} · expected skill: ${hit}/${total} (${((hit / total) * 100).toFixed(0)}%)`)
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
  const never = KNOWN.filter((k) => !fired.has(want(k)) && unmet.some((c) => c.expected?.includes(k)))
  if (never.length) console.log('prompted but NEVER fired (fix or cut):', never.join(', '))
}
const bar = Math.ceil(total * 0.75)
process.exit(positive - none >= Math.ceil(positive * 0.75) && hit >= bar ? 0 : 1)
