#!/usr/bin/env node
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join, relative } from 'node:path'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const STRICT = process.argv.includes('--strict')
const read = (p) => readFileSync(join(ROOT, p), 'utf8')
const rel = (p) => relative(ROOT, p)

const ALWAYS = ['CLAUDE.md']
const onDemand = []
for (const d of ['engineering/core']) {
  for (const f of readdirSync(join(ROOT, d))) if (f.endsWith('.md')) onDemand.push(`${d}/${f}`)
}
for (const d of readdirSync(join(ROOT, 'skills'), { withFileTypes: true })) {
  if (d.isDirectory() && existsSync(join(ROOT, 'skills', d.name, 'SKILL.md'))) {
    onDemand.push(`skills/${d.name}/SKILL.md`)
  }
}
for (const f of readdirSync(join(ROOT, 'agents'))) if (f.endsWith('.md')) onDemand.push(`agents/${f}`)
const FILES = [...ALWAYS, ...onDemand]

const prose = (s) => s.replace(/```[\s\S]*?```/g, '').replace(/`[^`]*`/g, '')
const NEG = /\b(never|don't|do not|must not|avoid|refuse to)\b/gi
const est = (s) => Math.round(s.length / 4) // ~4 chars/token, close enough to budget with

const findings = []
const add = (sev, cat, file, line, msg) => findings.push({ sev, cat, file, line, msg })

const density = []
for (const f of FILES) {
  const body = prose(read(f))
  const n = (body.match(NEG) || []).length
  const lines = body.split('\n').length
  density.push({ f, n, per100: lines ? (n / lines) * 100 : 0 })
}
const rates = density.map((d) => d.per100).sort((a, b) => a - b)
const median = rates[Math.floor(rates.length / 2)] || 0
for (const d of density) {
  if (d.n >= 5 && d.per100 > median * 2) {
    add('warn', 'negative-density', d.f, 0,
      `${d.n} negatives (${d.per100.toFixed(1)}/100 lines vs corpus median ${median.toFixed(1)}): check each guards a real failure mode`)
  }
}

const layerOf = (f) => (f === 'CLAUDE.md' ? 'kernel' : f.startsWith('engineering/core') ? 'core' : f.startsWith('skills/') ? 'skill' : 'agent')
const norm = (s) => s.toLowerCase().replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim()
const seen = new Map()
for (const f of FILES) {
  const body = prose(read(f))
  body.split('\n').forEach((raw, i) => {
    for (const sent of raw.split(/(?<=[.!?])\s+/)) {
      const k = norm(sent)
      if (k.split(' ').length < 7) continue // short fragments repeat harmlessly
      if (!seen.has(k)) seen.set(k, [])
      seen.get(k).push({ f, line: i + 1, layer: layerOf(f) })
    }
  })
}
for (const [k, hits] of seen) {
  const layers = new Set(hits.map((h) => h.layer))
  if (hits.length < 2) continue
  const where = hits.map((h) => `${h.f}:${h.line}`).join(' · ')
  if (layers.size >= 3) add('high', 'cross-layer-repeat', hits[0].f, hits[0].line, `stated in ${layers.size} layers: ${where}, "${k.slice(0, 70)}…"`)
  else if (layers.size === 2) add('warn', 'cross-layer-repeat', hits[0].f, hits[0].line, `stated in 2 layers: ${where}, "${k.slice(0, 70)}…"`)
  else if (hits.length >= 2) add('info', 'repeat-in-file', hits[0].f, hits[0].line, `said ${hits.length}× in one file: "${k.slice(0, 70)}…"`)
}

const skillNames = new Set(readdirSync(join(ROOT, 'skills'), { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name))
const agentNames = new Set(readdirSync(join(ROOT, 'agents')).filter((f) => f.endsWith('.md')).map((f) => f.replace(/\.md$/, '')))
for (const f of FILES) {
  const body = read(f)
  for (const m of body.matchAll(/~\/\.mastermind\/([A-Za-z0-9_\-./]+)/g)) {
    const p = m[1].replace(/[.,)]+$/, '')
    if (!existsSync(join(ROOT, p))) {
      const line = body.slice(0, m.index).split('\n').length
      add('high', 'stale-ref', f, line, `path does not exist: ~/.mastermind/${p}`)
    }
  }
  for (const m of body.matchAll(/`(?:skills|agents)\/([a-z-]+)(?:\/SKILL)?\.md`/g)) {
    const n = m[1]
    if (!skillNames.has(n) && !agentNames.has(n)) {
      const line = body.slice(0, m.index).split('\n').length
      add('high', 'stale-ref', f, line, `references "${n}", which is not a skill or agent`)
    }
  }
}

// ---- 4. budget --------------------------------------------------------------------------------
const alwaysTok = ALWAYS.reduce((t, f) => t + est(read(f)), 0)
const demandTok = onDemand.reduce((t, f) => t + est(read(f)), 0)

// ---- report -----------------------------------------------------------------------------------
const g = '\x1b[0;32m', y = '\x1b[0;33m', r = '\x1b[0;31m', dim = '\x1b[2m', x = '\x1b[0m'
const rank = { high: 0, warn: 1, info: 2 }
findings.sort((a, b) => rank[a.sev] - rank[b.sev] || a.file.localeCompare(b.file))

console.log(`\nBrain lint: ${FILES.length} instruction files\n`)
console.log(`  always-loaded   ${String(alwaysTok).padStart(6)} tokens  ${dim}(paid every turn)${x}`)
console.log(`  on-demand       ${String(demandTok).padStart(6)} tokens  ${dim}(paid when routed to)${x}\n`)

if (!findings.length) {
  console.log(`${g}✓ no structural findings.${x} Judgment calls are still yours: this counts, it does not read.\n`)
  process.exit(0)
}
const color = { high: r, warn: y, info: dim }
for (const f of findings) {
  const loc = f.line ? `${f.file}:${f.line}` : f.file
  console.log(`  ${color[f.sev]}${f.sev.padEnd(4)}${x} ${f.cat.padEnd(19)} ${loc}\n         ${f.msg}`)
}
const high = findings.filter((f) => f.sev === 'high').length
console.log(`\n${findings.length} finding(s), ${high} high.`)
console.log(`${dim}These are candidates, not verdicts: a negative guarding a proven failure mode should stay.${x}\n`)
process.exit(STRICT && high ? 1 : 0)
