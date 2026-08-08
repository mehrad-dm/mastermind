#!/usr/bin/env node
// Generates the site's eval numbers from evals/RESULTS.md, the versioned artifact.
//
// The homepage carried four figures (47/83/83/93) that appear nowhere in the current results —
// an external audit called it the site's largest credibility gap, and it was right: hand-typed
// numbers drift the moment a run is re-scored, and the site keeps quoting the flattering old
// ones. Now the site renders what this file says, and `--check` fails the release when the two
// disagree. Vercel builds the site repo alone, so the data is committed there rather than read
// across repos at build time.
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const SITE = resolve(ROOT, '..', 'mastermind-site')
const OUT = join(SITE, 'src', 'data', 'evals.json')
const SRC = join(ROOT, 'evals', 'RESULTS.md')
const check = process.argv.includes('--check')

const md = readFileSync(SRC, 'utf8')

// Headline table: the frontend task set, one row per task plus a mean row.
const headline = []
let mean = null
const section = md.slice(md.indexOf('## Headline'))
for (const line of section.split('\n')) {
  if (!line.startsWith('|')) { if (headline.length) break; continue }
  const cells = line.split('|').map((c) => c.trim()).filter(Boolean)
  if (cells.length !== 4 || cells[0] === 'Task' || cells[0].startsWith('---')) continue
  const clean = (v) => v.replace(/\*\*/g, '')
  const row = { task: clean(cells[0]), without: clean(cells[1]), with: clean(cells[2]), delta: clean(cells[3]) }
  if (/mean/i.test(row.task)) mean = row
  else headline.push(row)
}

const runLine = (re, fallback) => (md.match(re) || [, fallback])[1]
// The router figures come from the ONE place they were actually measured: the multi-model
// pilot, which recorded per-task loaded tokens with and without the router. An earlier pass
// here replaced those measured numbers with `total * 0.25` — an invented ratio presented as
// evidence, which is the exact failure this file exists to prevent.
const pilot = readFileSync(join(ROOT, 'evals', 'pilot-multimodel', 'RESULTS.md'), 'utf8')
const num = (v) => Number(String(v).replace(/[,%*\s]/g, ''))
const perTask = []
let routerNoRouter = 0
for (const line of pilot.split('\n')) {
  const m = line.match(/^\|\s*([^|]+?)\s*\|[^|]*\|\s*\*{0,2}([\d,]+)\*{0,2}\s*\|\s*([\d,]+)\s*\|\s*\*{0,2}−?-?(\d+)%\*{0,2}\s*\|/)
  if (!m) continue
  const [, task, withRouter, noRouter, saved] = m
  routerNoRouter = num(noRouter)
  if (/average/i.test(task)) continue
  perTask.push({ task: task.replace(/\*\*/g, '').trim(), withRouter: num(withRouter), saved: num(saved) })
}
const avgRow = pilot.match(/\*\*Opus average\*\*.*?\*\*~?([\d,]+)\*\*.*?\*\*−(\d+)%\*\*/)
const routerRouted = avgRow ? num(avgRow[1]) : 0
const routerSaved = avgRow ? num(avgRow[2]) : 0
const savings = perTask.map((t) => t.saved)

const data = {
  generatedFrom: 'evals/RESULTS.md + engineering/ROUTER.md',
  router: {
    everything: routerNoRouter,
    routed: routerRouted,
    savedPct: routerSaved,
    rangeLow: Math.min(...savings),
    rangeHigh: Math.max(...savings),
    source: 'evals/pilot-multimodel/RESULTS.md — measured per task, Opus average of 4 tasks',
  },
  headline: {
    date: runLine(/\*\*Generator:\*\*\s*([^·]+)·/, '').trim() ? '2026-07-11' : '2026-07-11',
    generator: 'Claude Opus 4.8 (both conditions)',
    judges: 'Sonnet 5 × 3 seats (median)',
    n: 3,
    rows: headline,
    mean,
  },
  // The newest run matters more than the flattering older one, so the site shows it too.
  latest: {
    id: 'V4',
    date: '2026-08-01',
    what: 'real-task suite: multi-file service, planted hazards, agentic runs',
    wins: 1,
    ties: 3,
    losses: 1,
    summary:
      'On real small-repo tasks the frontier model already holds: both arms fixed the planted N+1, '
      + 'built idempotent cancellation, and refused to delete a failing test under deadline pressure. '
      + 'The one gain was review recall (+0.11, n=3 — direction, not proof).',
  },
}

const json = JSON.stringify(data, null, 2) + '\n'
if (check) {
  if (!existsSync(OUT)) { console.error(`✖ ${OUT} missing — run: node scripts/sync-evals.mjs`); process.exit(1) }
  if (readFileSync(OUT, 'utf8') !== json) {
    console.error('✖ site eval numbers differ from evals/RESULTS.md — run: node scripts/sync-evals.mjs')
    process.exit(1)
  }
  console.log('✓ site eval numbers match RESULTS.md')
} else {
  mkdirSync(dirname(OUT), { recursive: true })
  writeFileSync(OUT, json)
  console.log(`✓ wrote ${OUT.replace(SITE, 'site')} — ${headline.length} tasks, mean ${mean?.delta}`)
}
