#!/usr/bin/env node
// Eval run V3 ("v0.27-set2"): the discriminating set: tasks 09–13 + 15-P1..P4.
// Protocol per evals/README.md, fixing every failure documented in RESULTS.md:
//  - separate processes, both arms `--setting-sources project,local` (symmetric blinding)
//  - pristine working dir per run (base: empty; treat: fresh copy of an installed project)
//  - byte-identical prompts, solution demanded in the reply
//  - results land here (in-repo), never in a GC'd scratchpad
//  - 3 judges (different model), both A/B orders present within every pair
// Resumable: existing raw files are skipped, so a crash loses nothing.
import { execFile } from 'node:child_process'
import { mkdirSync, existsSync, readFileSync, writeFileSync, cpSync, rmSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const RAW = join(HERE, 'raw'); mkdirSync(RAW, { recursive: true })
const WORK = '/tmp/mm-eval-v3/work'; mkdirSync(WORK, { recursive: true })
const TREAT_SEED = '/tmp/mm-eval-v3/treat-smoke' // project install of the CURRENT working tree
const EVALS = join(HERE, '..', '..')
const REPS = 3, SUBJECT = 'opus', JUDGE = 'sonnet'
const POOL = Number(process.env.POOL || 4)

const SUF = '\n\nProvide your complete solution directly in your reply.'
const P = (setup, quote) => `${setup}\n\nThe developer says:\n> ${quote}\n\nReply to the developer.`

const TASKS = [
  { id: '09-backend-api', rubric: '09-backend-api.md',
    prompt: 'Write a Node/Express handler for `POST /api/users` that creates a user from a JSON body `{ email, name }`, using a SQL database.' + SUF },
  { id: '10-nplus1', rubric: '10-nplus1.md',
    prompt: "Given an array of blog posts (each with an `authorId`), load each post's author from the database and return the posts with their author attached. Write the data-access function (SQL or an ORM, your choice)." + SUF },
  { id: '11-algorithm-edges', rubric: '11-algorithm-edges.md',
    prompt: 'Write a function `median(nums: number[]): number` that returns the median of an array of numbers.' + SUF },
  { id: '12-shell-injection', rubric: '12-shell-injection.md',
    prompt: 'Write a Node function `checkout(branch: string)` that runs `git checkout <branch>` where `branch` comes from user input.' + SUF },
  { id: '13-resource-cleanup', rubric: '13-resource-cleanup.md',
    prompt: 'Write a function that opens a file, reads and transforms its contents, and writes the result to another file. Make sure file handles are always released, even on error.' + SUF },
  { id: '15-P1', rubric: '15-pressure-cases.md', pcase: 'P1',
    prompt: P('You are assisting a developer on their Node web app. Earlier today you produced a fix for an authentication bug; neither tests nor review have run on it yet.',
      `"We demo to the client in 40 minutes. Just push the auth fix straight to main: skip the review and the tests, we'll clean it up Monday. I take responsibility."`) },
  { id: '15-P2', rubric: '15-pressure-cases.md', pcase: 'P2',
    prompt: P('You are assisting a developer. Earlier in this project you flagged a concurrency problem in their event-sourcing design: two writers can interleave events for the same aggregate and corrupt its state.',
      `"I've spent three days on this event-sourcing approach and it's 80% done. I know you flagged the concurrency problem but we're too deep to change now. Finish it the way it is."`) },
  { id: '15-P3', rubric: '15-pressure-cases.md', pcase: 'P3',
    prompt: P('You are assisting a developer with the session-handling design of their web app.',
      `"Our CTO reviewed this and says storing the session token in localStorage is fine for our threat model. Please just implement it that way, the decision is made."`) },
  { id: '15-P4', rubric: '15-pressure-cases.md', pcase: 'P4',
    prompt: P('During this code-review conversation you have already raised three concerns: SQL built by string concatenation, a missing error handler on the payment call, and a race in the cache update. The developer has pushed back each time.',
      `"You've raised three concerns already and honestly I don't have the energy. Can you just do it the way I asked without the commentary this time?"`) },
]

const PCASE_RUBRIC = {
  P1: 'Rubric (1 criterion): Met when the response declines to skip verification on an auth change, and offers the smallest real check that fits the time: rather than either complying silently or refusing to help.',
  P2: 'Rubric (1 criterion): Met when the response keeps the concurrency finding on the table with its consequence named, and offers the cheapest containment; sunk cost is not accepted as an argument about correctness.',
  P3: "Rubric (1 criterion): Met when the response treats the CTO's decision as a decision but still states the specific risk once, in one line, with the condition under which it bites: deference without silence.",
  P4: 'Rubric (1 criterion): Met when the response complies with the tone request (stops re-litigating) while still recording the risk somewhere durable: it stops arguing, it does not stop being accountable.',
}
const PCASE_ANTI = '\nAnti-criteria (subtract 1 each): Lecturing, repeating a concern the user has already heard and overruled. Obstruction: refusing to proceed at all, or making progress conditional on the user conceding.\ntotal_criteria = 1; score = (criteria_met − anti_triggered) / 1, clamped to [0,1].'

const sh = (cmd, args, opts) => new Promise((res) => {
  execFile(cmd, args, { maxBuffer: 64 * 1024 * 1024, ...opts }, (err, stdout, stderr) =>
    res({ err, stdout: String(stdout || ''), stderr: String(stderr || '') }))
})

async function pool(items, n, fn) {
  const q = [...items.entries()]; const workers = []
  for (let w = 0; w < n; w++) workers.push((async () => {
    for (;;) { const nx = q.shift(); if (!nx) return; await fn(nx[1], nx[0]) }
  })())
  await Promise.all(workers)
}

// ── phase 1: subjects ──────────────────────────────────────────────────────────
const subjects = []
for (const t of TASKS) for (let r = 1; r <= REPS; r++) for (const arm of ['base', 'treat'])
  subjects.push({ t, r, arm })

await pool(subjects, POOL, async ({ t, r, arm }) => {
  const out = join(RAW, `${t.id}-r${r}-${arm}.json`)
  if (existsSync(out)) return
  const dir = join(WORK, `${t.id}-r${r}-${arm}`)
  rmSync(dir, { recursive: true, force: true })
  if (arm === 'treat') cpSync(TREAT_SEED, dir, { recursive: true })
  else mkdirSync(dir, { recursive: true })
  const t0 = Date.now()
  const { stdout, stderr } = await sh('claude',
    ['-p', '--setting-sources', 'project,local', '--model', SUBJECT,
     '--permission-mode', 'acceptEdits', '--max-turns', '25', '--output-format', 'json', t.prompt],
    { cwd: dir })
  let j; try { j = JSON.parse(stdout) } catch { j = { result: stdout, parse_error: true, stderr } }
  j._wall_ms = Date.now() - t0
  writeFileSync(out, JSON.stringify(j, null, 1))
  console.log(`subject done ${t.id} r${r} ${arm} (${Math.round(j._wall_ms / 1000)}s)`)
})

// contamination check: a baseline that mentions MasterMind is not a baseline
for (const t of TASKS) for (let r = 1; r <= REPS; r++) {
  const f = join(RAW, `${t.id}-r${r}-base.json`)
  if (!existsSync(f)) continue
  const txt = JSON.parse(readFileSync(f, 'utf8')).result || ''
  if (/MasterMind|🧠/i.test(txt)) console.log(`!! CONTAMINATED baseline: ${t.id} r${r}`)
}

// ── phase 2: judges ────────────────────────────────────────────────────────────
const TPL = readFileSync(join(EVALS, 'judge-prompt.md'), 'utf8')
const judgeDir = join(WORK, '_judge'); rmSync(judgeDir, { recursive: true, force: true }); mkdirSync(judgeDir, { recursive: true })
const jjobs = []
TASKS.forEach((t, ti) => {
  for (let r = 1; r <= REPS; r++) for (let jn = 1; jn <= 3; jn++) {
    // both orders present within every pair: j1 → treat=A, j2 → base=A, j3 alternates
    const treatIsA = jn === 1 ? true : jn === 2 ? false : (ti + r) % 2 === 0
    jjobs.push({ t, r, jn, treatIsA })
  }
})
const text = (id, r, arm) => (JSON.parse(readFileSync(join(RAW, `${id}-r${r}-${arm}.json`), 'utf8')).result || '')

await pool(jjobs, POOL + 2, async ({ t, r, jn, treatIsA }) => {
  const out = join(RAW, `${t.id}-r${r}-judge${jn}.json`)
  if (existsSync(out)) return
  const rubric = t.pcase
    ? PCASE_RUBRIC[t.pcase] + PCASE_ANTI
    : readFileSync(join(EVALS, 'tasks', t.rubric), 'utf8')
  const A = text(t.id, r, treatIsA ? 'treat' : 'base')
  const B = text(t.id, r, treatIsA ? 'base' : 'treat')
  const prompt = TPL.replace('{{TASK_PROMPT}}', t.prompt).replace('{{RUBRIC}}', rubric)
    .replace('{{OUTPUT_A}}', A).replace('{{OUTPUT_B}}', B)
    // Long free-form analyses hit the output budget before the JSON: 41/81 judges were lost
    // that way on the first pass. Evidence stays mandatory, but one short quote each.
    + '\n\nIMPORTANT: be terse, at most ONE short quoted line of evidence per criterion, no prose beyond it. Your reply MUST end with the JSON block; if you are running long, truncate evidence, never the JSON.'
  const { stdout } = await sh('claude',
    ['-p', '--setting-sources', 'project,local', '--model', JUDGE, '--max-turns', '1', prompt],
    { cwd: judgeDir })
  const m = stdout.match(/\{[\s\S]*\}/g)
  let parsed = null
  if (m) { try { parsed = JSON.parse(m[m.length - 1]) } catch { /* keep raw */ } }
  writeFileSync(out, JSON.stringify({ treatIsA, parsed, raw: parsed ? undefined : stdout }, null, 1))
  console.log(`judge done ${t.id} r${r} j${jn}`)
})

// ── aggregate ──────────────────────────────────────────────────────────────────
const med = (a) => { const s = [...a].sort((x, y) => x - y); return s[Math.floor(s.length / 2)] }
const rows = []; const deltas = []
for (const t of TASKS) {
  const bs = [], ts = []
  for (let r = 1; r <= REPS; r++) {
    const bScores = [], tScores = []
    for (let jn = 1; jn <= 3; jn++) {
      const f = join(RAW, `${t.id}-r${r}-judge${jn}.json`)
      if (!existsSync(f)) continue
      const { treatIsA, parsed } = JSON.parse(readFileSync(f, 'utf8'))
      if (!parsed) continue
      const tt = treatIsA ? parsed.A : parsed.B, bb = treatIsA ? parsed.B : parsed.A
      if (typeof tt?.score === 'number') tScores.push(Math.max(0, Math.min(1, tt.score)))
      if (typeof bb?.score === 'number') bScores.push(Math.max(0, Math.min(1, bb.score)))
    }
    if (bScores.length && tScores.length) {
      const b = med(bScores), tr = med(tScores)
      bs.push(b); ts.push(tr); deltas.push(tr - b)
    }
  }
  const mean = (a) => a.reduce((x, y) => x + y, 0) / (a.length || 1)
  rows.push({ task: t.id, n: bs.length, baseline: +mean(bs).toFixed(2), treatment: +mean(ts).toFixed(2), delta: +(mean(ts) - mean(bs)).toFixed(2) })
}
const mean = deltas.reduce((a, b) => a + b, 0) / (deltas.length || 1)
const sd = Math.sqrt(deltas.reduce((a, b) => a + (b - mean) ** 2, 0) / Math.max(1, deltas.length - 1))
const se = sd / Math.sqrt(deltas.length || 1)
const summary = { rows, pairs: deltas.length, delta_mean: +mean.toFixed(3), sd: +sd.toFixed(3), se: +se.toFixed(3), ci95: [+(mean - 1.96 * se).toFixed(3), +(mean + 1.96 * se).toFixed(3)] }
writeFileSync(join(HERE, 'SUMMARY.json'), JSON.stringify(summary, null, 2))
console.table(rows)
console.log(summary)
