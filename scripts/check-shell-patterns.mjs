#!/usr/bin/env node

// `grep -q` stops reading as soon as it has its answer. Upstream then dies of SIGPIPE with
// status 141, and under `pipefail` that becomes the pipeline's verdict, so a successful
// search reads as a failure.

import { readFileSync, existsSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..')
const FIXTURES = join(REPO, 'scripts', 'fixtures', 'shell-patterns.json')

const SHELL = /\.(sh|bash)$|(^|\/)(pre-commit|pre-push|mastermind)$/
const WORKFLOW = /^\.github\/workflows\/[^/]+\.ya?ml$/
const PIPEFAIL = /(^|[;&|(\s])set\s+(?:[-+][A-Za-z]+\s+|-o\s+[a-z]+\s+)*-[A-Za-z]*o\s+pipefail\b/m
// `head` is left alone: it is nearly always display truncation where the status is discarded.
// Any reader that can stop before its input ends: -q, -l, -L and -m, for grep at any path and for rg.
const READER = /(?<![|&])\|&?(?!\|)\s*(?:command\s+)?(?:\/\S*\/)?(?:[ef]?grep|rg)\b/g
const QUIET = /^(?:--quiet|--silent|--files-with(?:out)?-match(?:es)?|--max-count(?:=\S*)?|-[A-Za-z0-9]*[qlLm][A-Za-z0-9]*)$/

const uncomment = (line) => line.replace(/(^|\s)#.*$/, '$1')

// One entry per command: a trailing `\` or `|`, or a leading `|`, continues the pipeline.
function logicalLines(text) {
  const out = []
  let cur = null
  for (const [i, raw] of text.split('\n').entries()) {
    const line = uncomment(raw).trimEnd()
    const leadsWithPipe = /^\s*\|(?!\|)/.test(line)
    if (cur && (cur.open || leadsWithPipe)) cur.text += ' ' + line.trim()
    else { if (cur) out.push(cur); cur = { line: i + 1, text: line, shown: raw.trim() } }
    cur.open = /\\$/.test(line) || /(?<!\|)\|$/.test(line)
    if (cur.open) cur.text = cur.text.replace(/\\$/, '')
  }
  if (cur) out.push(cur)
  return out
}

function earlyExits(text) {
  const hits = []
  for (const l of logicalLines(text)) {
    for (const m of l.text.matchAll(READER)) {
      const rest = l.text.slice(m.index + m[0].length).replace(/'[^']*'|"[^"]*"/g, ' ')
      const flags = rest.split(/[|;&)]/)[0].split(/\s+/)
      if (flags.some((f) => QUIET.test(f))) { hits.push({ line: l.line, text: l.shown.slice(0, 96) }); break }
    }
  }
  return hits
}

// Every `run:` body with the line it starts on, and whether its step pins `shell: bash`,
// which GitHub runs as `bash -eo pipefail`.
function runBlocks(yaml) {
  const lines = yaml.split('\n')
  const indent = (s) => s.match(/^ */)[0].length
  const blocks = []
  lines.forEach((line, i) => {
    const m = line.match(/^(\s*)(-\s+)?run:\s*(.*)$/)
    if (!m) return
    const key = m[1].length + (m[2] ? m[2].length : 0)
    let body = [], start = i + 1
    if (/^[|>][+-]?\d*\s*$/.test(m[3])) {
      let j = i + 1
      for (; j < lines.length && (!lines[j].trim() || indent(lines[j]) > key); j++) body.push(lines[j])
      start = i + 2
    } else body = [m[3]]
    let top = i
    while (top > 0 && !(indent(lines[top]) < key && /^\s*-\s/.test(lines[top])) && !m[2]) top--
    const dash = m[2] ? m[1].length : indent(lines[top])
    let end = i + 1
    while (end < lines.length && (!lines[end].trim() || indent(lines[end]) > dash)) end++
    const step = lines.slice(top, end).filter((l) => indent(l) <= key)
    const pinned = step.some((l) => /^\s*(-\s+)?shell:\s*bash\b/.test(l))
    blocks.push({ start, text: body.join('\n'), pinned })
  })
  return blocks
}

function scan(file, text) {
  if (WORKFLOW.test(file)) {
    const pinnedByDefault = /^defaults:\s*\n\s+run:\s*\n\s+shell:\s*bash\b/m.test(text)
    return runBlocks(text)
      .filter((b) => b.pinned || pinnedByDefault || PIPEFAIL.test(b.text))
      .flatMap((b) => earlyExits(b.text).map((h) => ({ file, line: b.start + h.line - 1, text: h.text })))
  }
  if (!PIPEFAIL.test(text)) return []
  return earlyExits(text).map((h) => ({ file, ...h }))
}

if (process.argv.includes('--self-test')) {
  const { fires, clean } = JSON.parse(readFileSync(FIXTURES, 'utf8'))
  const wrong = [
    ...fires.filter((c) => scan(c.file, c.text).length === 0).map((c) => `did not fire: ${c.name}`),
    ...clean.filter((c) => scan(c.file, c.text).length > 0).map((c) => `fired on clean input: ${c.name}`),
  ]
  if (wrong.length) { console.error('✖ shell-patterns self-test:\n  ' + wrong.join('\n  ')); process.exit(1) }
  console.log(`✓ shell-patterns self-test: ${fires.length} bad inputs fire, ${clean.length} good inputs stay clean.`)
  process.exit(0)
}

const tracked = execFileSync('git', ['-C', REPO, 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], { encoding: 'utf8', maxBuffer: 64 << 20 })
  .split('\0')
  .filter((f) => f && (SHELL.test(f) || WORKFLOW.test(f)) && !f.startsWith('evals/'))

const findings = []
for (const file of tracked) {
  const path = join(REPO, file)
  if (existsSync(path)) findings.push(...scan(file, readFileSync(path, 'utf8')))
}

if (findings.length) {
  console.error(`✖ ${findings.length} pipeline(s) whose reader exits early, under pipefail:\n`)
  for (const f of findings) console.error(`  ${f.file}:${f.line}  ${f.text}`)
  console.error('\nThe writer takes SIGPIPE and the pipeline reports 141, so a match reads as a miss.')
  console.error('Read into a variable first, then match with a here-string: grep -q PATTERN <<<"$VAR"')
  process.exit(1)
}

console.log(`✓ no early-exit pipeline reader under pipefail (${tracked.length} shell files and workflows).`)
