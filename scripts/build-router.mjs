#!/usr/bin/env node

import fs from 'node:fs'
import path from 'node:path'
import crypto from 'node:crypto'
import { fileURLToPath } from 'node:url'

import { spawnSync } from 'node:child_process'
import os from 'node:os'

const at = process.argv.indexOf('--root')
const ROOT = at > 0 ? path.resolve(process.argv[at + 1]) : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const OUT = path.join(ROOT, 'engineering', 'ROUTER.md')

// A manifest written from one tree must fail --check once a routed file changes, and pass otherwise.
if (process.argv.includes('--self-test')) {
  const box = fs.mkdtempSync(path.join(os.tmpdir(), 'mm-router-'))
  const put = (rel, text) => { fs.mkdirSync(path.dirname(path.join(box, rel)), { recursive: true }); fs.writeFileSync(path.join(box, rel), text) }
  const run = (...a) => spawnSync('node', [fileURLToPath(import.meta.url), '--root', box, ...a], { encoding: 'utf8' }).status
  const reset = () => {
    fs.rmSync(box, { recursive: true, force: true })
    put('engineering/fields/web/react.md', '---\nroute_when: [react, hooks]\n---\n\n# React\n')
    put('engineering/fields/_template/stack-defaults.md', '---\nroute_when: [template]\n---\n\n# Template\n')
    put('skills/build/SKILL.md', '---\nname: build\ndescription: "Use when building."\n---\n\n# Build\n')
    run()
  }
  const fires = [
    ['a routed field file changed', () => put('engineering/fields/web/react.md', '---\nroute_when: [react, hooks]\n---\n\n# React, edited\n')],
    ['a skill added', () => put('skills/debug/SKILL.md', '---\nname: debug\ndescription: "Use when debugging."\n---\n\n# Debug\n')],
    ['a routed file removed', () => fs.rmSync(path.join(box, 'engineering/fields/web/react.md'))],
    ['the manifest edited by hand', () => fs.appendFileSync(path.join(box, 'engineering', 'ROUTER.md'), '\n| `extra` | web | x | 1 | x.md | 00000000 |\n')],
  ]
  const clean = [
    ['nothing changed', () => {}],
    ['a scaffold file under _template changed', () => put('engineering/fields/_template/stack-defaults.md', '---\nroute_when: [template]\n---\n\n# Edited\n')],
  ]
  const wrong = []
  for (const [name, change] of fires) { reset(); change(); if (run('--check') !== 1) wrong.push(`did not fire: ${name}`) }
  for (const [name, change] of clean) { reset(); change(); if (run('--check') !== 0) wrong.push(`fired on clean input: ${name}`) }
  fs.rmSync(box, { recursive: true, force: true })
  if (wrong.length) { console.error('✖ router self-test:\n  ' + wrong.join('\n  ')); process.exit(1) }
  console.log(`✓ router self-test: ${fires.length} bad inputs fire, ${clean.length} good inputs stay clean.`)
  process.exit(0)
}

const tokens = (s) => Math.round(s.length / 4)
const hash = (s) => crypto.createHash('sha256').update(s).digest('hex').slice(0, 8)

const unquote = (v) => { if (!/^"[\s\S]*"$/.test(v)) return v; try { return JSON.parse(v) } catch { return v } }
function frontmatter(body) {
  const m = body.match(/^---\n([\s\S]*?)\n---/)
  if (!m) return {}
  const fm = {}
  for (const line of m[1].split('\n')) {
    const kv = line.match(/^(\w+):\s*(.*)$/)
    if (!kv) continue
    let [, k, v] = kv
    const arr = v.match(/^\[(.*)\]$/)
    fm[k] = arr ? arr[1].split(',').map((x) => x.trim()).filter(Boolean) : unquote(v.trim())
  }
  return fm
}

const walk = (dir) =>
  fs.existsSync(dir)
    ? fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
        const p = path.join(dir, e.name)
        return e.isDirectory() ? walk(p) : p
      })
    : []

const nodes = []

const isScaffold = (p) => path.relative(ROOT, p).split(path.sep).some((seg) => seg.startsWith('_'))

for (const f of walk(path.join(ROOT, 'engineering', 'fields')).filter((p) => p.endsWith('.md') && !isScaffold(p))) {
  const body = fs.readFileSync(f, 'utf8')
  const fm = frontmatter(body)
  if (!fm.route_when) continue // field.md (the pack TOC) and untagged files are skipped
  nodes.push({
    kind: 'field',
    field: fm.field || path.basename(path.dirname(f)),
    name: fm.name || path.basename(f, '.md'),
    tags: Array.isArray(fm.route_when) ? fm.route_when : [fm.route_when],
    tokens: tokens(body),
    hash: hash(body),
    path: path.relative(ROOT, f),
  })
}

// Skills: routed by their existing name + description
for (const f of walk(path.join(ROOT, 'skills')).filter((p) => p.endsWith('SKILL.md'))) {
  const body = fs.readFileSync(f, 'utf8')
  const fm = frontmatter(body)
  if (!fm.name) continue
  nodes.push({
    kind: 'skill',
    field: ', ',
    name: fm.name,
    tags: [String(fm.description || '').replace(/\s+/g, ' ').slice(0, 120)],
    tokens: tokens(body),
    hash: hash(body),
    path: path.relative(ROOT, f),
  })
}

nodes.sort((a, b) => a.kind.localeCompare(b.kind) || a.field.localeCompare(b.field) || a.name.localeCompare(b.name))

const row = (n) => `| \`${n.name}\` | ${n.field} | ${n.tags.join(', ')} | ${n.tokens} | ${n.path} | ${n.hash} |`
const section = (kind, title) => {
  const rows = nodes.filter((n) => n.kind === kind)
  if (!rows.length) return ''
  return `## ${title}\n\n| node | field | route_when | tokens | path | hash |\n| --- | --- | --- | --- | --- | --- |\n${rows.map(row).join('\n')}\n`
}

const total = nodes.reduce((s, n) => s + n.tokens, 0)
const manifest = `# ROUTER: load only what the task needs

Generated by \`scripts/build-router.mjs\`: do not edit by hand. Match the task to a node's
\`route_when\` **by meaning, not literal keyword overlap**: the tags are a hint at intent, not an exact
string to match. Then load **only** that node's \`path\`. Loading everything here would cost ~${total}
tokens; routing loads the manifest (~this file) plus the 1–2 matched files instead.

Matching rules, in order: **(1)** one node clearly fits → load just it. **(2)** two or three plausibly
fit → load them all (still far cheaper than everything). **(3)** nothing clearly fits, or you're unsure →
do **not** guess or skip: load the active field's \`field.md\` (its table of contents) and decide from
there. Under-loading silently is the failure mode; a slightly wider load is cheap insurance.

If this file is missing or stale (a \`hash\` no longer matches its file), ignore it and fall back to the
prose pointers in \`active-field.md\` / each field's \`field.md\`. The router only ever speeds things up.

Each \`hash\` is the first 8 hex characters of the SHA-256 of the file at \`path\`. To test the whole
file: \`node .mastermind/scripts/build-router.mjs --check\` in an installed project
(\`node scripts/build-router.mjs --check\` in the MasterMind repository). Exit 1 means stale; the same
command without \`--check\` rewrites it.

${section('field', 'Field-pack files')}
${section('skill', 'Skills')}`

if (process.argv.includes('--check')) {
  const current = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : ''
  if (current.trim() !== manifest.trim()) {
    console.error('✖ ROUTER.md is stale: run: node scripts/build-router.mjs')
    process.exit(1)
  }
  console.log('✓ ROUTER.md is up to date')
} else {
  fs.writeFileSync(OUT, manifest)
  console.log(`✓ wrote ROUTER.md: ${nodes.length} nodes, ${total} tokens catalogued`)
}
