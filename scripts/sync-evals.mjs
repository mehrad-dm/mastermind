#!/usr/bin/env node
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

const die = (m) => {
  console.error(`✖ ${m}: evals/RESULTS.md and this script have drifted`)
  process.exit(1)
}
const grab = (text, re, what) => (text.match(re) || die(`cannot read ${what}`))[1].trim()

const headlineMeta = section.split('\n').find((l) => l.startsWith('**Date:**')) ?? die('cannot find the Headline meta line')
const headlineDate = grab(headlineMeta, /\*\*Date:\*\*\s*(\d{4}-\d{2}-\d{2})/, 'the headline date')
const headlineGenerator = grab(headlineMeta, /\*\*Generator:\*\*\s*([^·]+)·/, 'the headline generator')
// The meta line wraps, so the judges run on into the next line before the next `·`.
const headlineJudges = grab(section, /\*\*Judges:\*\*\s*([\s\S]+?)·/, 'the headline judges').replace(/\s+/g, ' ')
const headlineN = Number(grab(section, /\*\*N=(\d+)\*\*/, 'the headline sample size'))

const runSections = md.split(/^## /m).filter((s) => /^Run \S+: \d{4}-\d{2}-\d{2}/.test(s))
const featured = runSections.filter((s) => /^>\s*\*\*Featured on the site\.\*\*/m.test(s))
if (featured.length !== 1) {
  die(`expected exactly one run marked "> **Featured on the site.**", found ${featured.length}`)
}
const latestSection = featured[0]
const latestId = grab(latestSection, /^Run (\S+): /, 'the featured run id')
const latestDate = grab(latestSection, /^Run \S+: (\d{4}-\d{2}-\d{2})/, 'the featured run date')
const latestWhat = grab(latestSection, /^>\s*\*\*Featured on the site\.\*\*\s*(.+)$/m, 'the featured run description')
const latestSummary = latestSection
  .split(/^>\s*\*\*Featured on the site\.\*\*.*$/m)[1]
  .split(/\n(?!>)/)[0]
  .split('\n')
  .map((l) => l.replace(/^>\s?/, '').trim())
  .filter(Boolean)
  .join(' ')
if (!latestSummary) die('the featured run has no summary paragraph under its callout')

let wins = 0
let ties = 0
let losses = 0
for (const line of latestSection.split('\n')) {
  const cells = line.split('|').map((c) => c.trim())
  if (cells.length < 7 || !/^\|/.test(line)) continue // 5 columns → 7 cells with the edges
  const delta = cells[5].replace(/\*/g, '').replace(/−/g, '-')
  if (!/^[+-]?\d+(?:\.\d+)?$/.test(delta)) continue // header and separator rows
  if (+delta > 0) wins++
  else if (+delta < 0) losses++
  else ties++
}
if (wins + ties + losses === 0) die('the featured run has no results table to count')

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
    source: 'evals/pilot-multimodel/RESULTS.md, measured per task, Opus average of 4 tasks',
  },
  headline: {
    date: headlineDate,
    generator: headlineGenerator,
    judges: headlineJudges,
    n: headlineN,
    rows: headline,
    mean,
  },
  latest: {
    id: latestId,
    date: latestDate,
    what: latestWhat,
    wins,
    ties,
    losses,
    summary: latestSummary,
  },
}

const json = JSON.stringify(data, null, 2) + '\n'
if (check) {
  if (!existsSync(OUT)) { console.error(`✖ ${OUT} missing: run: node scripts/sync-evals.mjs`); process.exit(1) }
  if (readFileSync(OUT, 'utf8') !== json) {
    console.error('✖ site eval numbers differ from evals/RESULTS.md: run: node scripts/sync-evals.mjs')
    process.exit(1)
  }
  console.log('✓ site eval numbers match RESULTS.md')
} else {
  mkdirSync(dirname(OUT), { recursive: true })
  writeFileSync(OUT, json)
  console.log(`✓ wrote ${OUT.replace(SITE, 'site')}: ${headline.length} tasks, mean ${mean?.delta}`)
}
