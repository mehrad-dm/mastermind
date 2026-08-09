#!/usr/bin/env node
import { execFileSync } from 'node:child_process'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const CLI = join(ROOT, 'cli', 'bin', 'mastermind.mjs')

const PARAPHRASE = [
  ['why is this page so slow when there are lots of orders?', 'performance'],
  ['this test keeps failing randomly and I cannot work out why', 'debug'],
  ['add a favourites feature to the product list', 'build'],
  ['does it actually work? drive it end to end before we ship', 'qa'],
  ['this is sensitive client data, do not commit it', 'quarantine'],
  ['we need to remove the old v1 endpoint, is anything still using it?', 'deprecate'],
  ['I am about to say this is fixed — are you sure?', 'double-check'],
  ['set up mastermind for this project', 'init'],
  ['write docs for our internal package so people stop misusing it', 'explain'],
  ['I am pausing this, make it survive the next session', 'handoff'],
  ['what can you do? show me the options', 'help'],
  ['improve this prompt before I send it to the model', 'prompt'],
  ['make it match our team conventions, you keep writing it wrong', 'signature'],
  ['I do not know if this approach will even work, try something quick', 'prototype'],
  ['remember this correction for next time', 'levelup'],
]

const ORGANIC = [
  ['the invoice screen takes nine seconds to open', 'performance'],
  ['the checkout button does nothing in Safari but works in Chrome', 'debug'],
  ['customers keep asking for a dark mode toggle', 'build'],
  ['before this goes to the client I want proof it holds up', 'qa'],
  ['nobody knows whether we can drop the legacy sync job', 'deprecate'],
  ['our new hire cannot work out how the payments module is meant to be used', 'explain'],
  ['I might be wrong about what is causing this', 'double-check'],
  ['my laptop died and I lost the thread of what I was doing', 'handoff'],
]

const route = (q) => {
  const r = JSON.parse(execFileSync('node', [CLI, 'route', q, '--json'],
    { cwd: ROOT, encoding: 'utf8', env: { ...process.env, MASTERMIND_HOME: ROOT } }))
  return { all: r.skills.map((s) => s.name), hints: r.hints }
}

const score = (cases) => {
  let recall = 0, hinted = 0
  const missed = []
  for (const [q, want] of cases) {
    const { all, hints } = route(q)
    if (all.includes(want)) recall++
    else missed.push({ request: q.slice(0, 52), want, note: 'MISSING FROM TABLE — a real bug' })
    if (hints.includes(want)) hinted++
  }
  return { n: cases.length, recall, hinted, missed }
}

const pct = (n, of) => `${((n / of) * 100).toFixed(0)}%`
const report = (label, r) =>
  console.log(`${label.padEnd(22)} n=${r.n}  in-table ${r.recall} (${pct(r.recall, r.n)})  hinted ${r.hinted} (${pct(r.hinted, r.n)})`)

const p = score(PARAPHRASE)
const o = score(ORGANIC)
report('paraphrased triggers', p)
report('organic phrasing', o)
const missed = [...p.missed, ...o.missed]
if (missed.length) {
  console.log('\nabsent from the table (must never happen):')
  console.table(missed)
}
console.log(
  '\nin-table is the contract: the model always sees every option and judges from the'
  + '\ndescriptions. hinted is the keyword arrows only — weak on organic phrasing by'
  + '\nmeasurement, which is why they mark and never filter. Paraphrased cases reuse the'
  + '\ndescriptions\' own vocabulary and read high by construction.',
)
// The gate is the contract, not the hints: every request must still see every skill.
process.exit(p.recall === p.n && o.recall === o.n ? 0 : 1)
