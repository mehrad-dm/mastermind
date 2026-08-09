#!/usr/bin/env node

import { readFileSync, writeFileSync, readdirSync, mkdirSync, existsSync, rmSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..')
const OUT = join(REPO, '..', 'mastermind-site', 'src', 'pages', 'library')
const CHECK = process.argv.includes('--check')

const fm = (src) => {
  const m = src.match(/^---\n([\s\S]*?)\n---\n?/)
  if (!m) return [{}, src]
  const meta = {}
  for (const line of m[1].split('\n')) {
    const i = line.indexOf(':')
    if (i > 0) meta[line.slice(0, i).trim()] = line.slice(i + 1).trim()
  }
  return [meta, src.slice(m[0].length)]
}

// YAML-safe double-quoted scalar.
const q = (s) => `"${String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`

const clean = (body) =>
  body
    .replace(/^#\s+.*\n+/, '') // drop the H1; the page renders its own title
    .replace(/~\/\.mastermind\//g, '')
    .trim()

const items = []
for (const d of readdirSync(join(REPO, 'skills'), { withFileTypes: true })) {
  if (!d.isDirectory()) continue
  const about = join(REPO, 'skills', d.name, 'ABOUT.md')
  if (!existsSync(about)) {
    console.error(`✖ skills/${d.name} has no ABOUT.md — every skill needs a human-facing article`)
    process.exit(1)
  }
  const [meta, body] = fm(readFileSync(about, 'utf8'))
  items.push({ kind: 'skill', name: d.name, title: meta.title ?? d.name, blurb: meta.blurb ?? '', body: clean(body) })
}
for (const f of readdirSync(join(REPO, 'agents', 'about'))) {
  if (!f.endsWith('.md')) continue
  const [meta, body] = fm(readFileSync(join(REPO, 'agents', 'about', f), 'utf8'))
  const name = f.replace(/\.md$/, '')
  items.push({ kind: 'agent', name, title: meta.title ?? name, blurb: meta.blurb ?? '', body: clean(body) })
}
items.sort((a, b) => a.kind.localeCompare(b.kind) || a.name.localeCompare(b.name))

// Neighbours for prev/next, wrapping around so the library is browsable end to end.
const short = (t) => t.split(/\s+—\s+/)[1] ?? t

const seoTitle = (t) => {
  const full = `${t} · MasterMind`
  return full.length <= 60 ? full : `${t.split(/\s+—\s+/)[0]} · MasterMind`
}

const metaDesc = (s) => (s.length <= 155 ? s : `${s.slice(0, 155).replace(/\s+\S*$/, '')}…`)

const page = (it, i, all) => {
  const prev = all[(i - 1 + all.length) % all.length]
  const next = all[(i + 1) % all.length]
  return `---
layout: ../../layouts/Library.astro
name: ${q(it.name)}
kind: ${q(it.kind)}
heading: ${q(it.title)}
title: ${q(seoTitle(it.title))}
description: ${q(metaDesc(it.blurb))}
blurb: ${q(it.blurb)}
prevName: ${q(prev.name)}
prevBlurb: ${q(short(prev.title))}
nextName: ${q(next.name)}
nextBlurb: ${q(short(next.title))}
---

${it.body}
`
}

let stale = 0
const wanted = new Map(items.map((it, i) => [`${it.name}.md`, page(it, i, items)]))

if (CHECK) {
  if (!existsSync(join(REPO, '..', 'mastermind-site'))) {
    console.log('· site repo not checked out beside this one — skipping the library check')
    process.exit(0)
  }
  const have = existsSync(OUT) ? new Set(readdirSync(OUT).filter((f) => f.endsWith('.md'))) : new Set()
  for (const [f, want] of wanted) {
    if (!have.has(f) || readFileSync(join(OUT, f), 'utf8') !== want) stale++
  }
  for (const f of have) if (!wanted.has(f)) stale++
  if (stale) {
    console.error(`✖ library pages stale (${stale}) — run: node scripts/build-library.mjs`)
    process.exit(1)
  }
  console.log(`✓ library pages up to date — ${items.length} pages`)
  process.exit(0)
}

const SITE = join(REPO, '..', 'mastermind-site')
if (!existsSync(SITE)) {
  console.error(`✖ ${SITE} is not checked out — nothing to write. Clone the site repo beside this one.`)
  process.exit(1)
}

if (existsSync(OUT)) rmSync(OUT, { recursive: true }) // prune renamed/removed skills
mkdirSync(OUT, { recursive: true })
for (const [f, content] of wanted) writeFileSync(join(OUT, f), content)
console.log(
  `✓ wrote ${items.length} library pages — ${items.filter((i) => i.kind === 'skill').length} skills, ${items.filter((i) => i.kind === 'agent').length} agents`,
)
