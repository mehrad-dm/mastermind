#!/usr/bin/env node

// A skill body is an instruction parsed by a reader who cannot ask a follow-up. Ambiguity there
// is not a style problem, it is a wrong action. STE-informed, never STE-compliant: the standard
// is free to obtain and not free to redistribute, so these are our own rules.

import { readFileSync, readdirSync, existsSync } from 'node:fs'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const MAX_WORDS = 30          // a directive longer than this is carrying more than one instruction
const IMPERATIVE = /^(?:copy|delete|remove|run|write|add|read|move|create|send|open|close|set|check|update|install|commit|push|drop|rename|replace|split|merge|inspect|verify|confirm|deploy|build|test|review|report|record|log|apply|revert|restore|fetch|pull|clone|start|stop|enable|disable|list|print|show|ask|tell|name|state|keep|load|save|scan|search|find|fix|clean|prune|tag|publish|measure|profile|trace|mock|stub|wrap|extract|inline|rewrite|refactor)$/i
const SEPARATOR = /\s(?:and(?:\s+then)?|then|;|,\s*then)\s+/i
const HEDGE = new RegExp([
  '(?<![-/])\\bshould(?:\\s+probably)?\\b(?!-)',
  '\\b(?:might|may) want to\\b', '\\btry to\\b', '\\bwhere possible\\b', '\\bif possible\\b', '\\bas appropriate\\b',
  '\\bconsider (?:doing|using|adding)\\b', '\\bit may be worth\\b',
  '\\bperhaps\\b', '\\bideally\\b', '\\bmaybe\\b', '\\bif you (?:feel like|want to|like)\\b',
  '\\byou could\\b', '\\bcould (?:perhaps|possibly|maybe|also|consider|try)\\b', '\\bit could be (?:worth|useful|helpful|good|a good idea)\\b',
].join('|'), 'i')
// A line that addresses the reader with a soft modal is an instruction, bullet or not.
const SOFT = /\byou (?:may|might|could) (?:want|wish|like|also|consider|try)\b|^\s*(?:perhaps|ideally|maybe)\b/i

const targets = []
for (const d of readdirSync(join(ROOT, 'skills'), { withFileTypes: true })) {
  if (!d.isDirectory()) continue
  const f = `skills/${d.name}/SKILL.md`
  if (existsSync(join(ROOT, f))) targets.push(f)
}
for (const f of readdirSync(join(ROOT, 'agents'))) {
  if (f.endsWith('.md')) targets.push(`agents/${f}`)
}

const words = (s) => s.trim().split(/\s+/).filter(Boolean).length

// A directive is a line that commands: a bullet or numbered step, or any line with a hard modal.
const DIRECTIVE = /^\s*(?:[-*]|\d+\.)\s+\S|(?:\b(?:must|never|always|do not|don't)\b)/i
const FIXTURES = join(ROOT, 'scripts', 'fixtures', 'instructions.json')

// Wording quoted as an example of what not to say is not the instruction.
const unquoted = (t) => t.replace(/"[^"]*"|\u201c[^\u201d]*\u201d/g, 'x')

function inspect(rel, text, findings) {
  const lines = text.split('\n')
  let fenced = false
  // Frontmatter is skipped on purpose: check-integrity holds a `description` to its own budget.
  let fm = 0
  lines.forEach((line, i) => {
    if (/^---\s*$/.test(line) && fm < 2) { fm++; return }
    if (fm < 2) return
    if (/^\s*```/.test(line)) { fenced = !fenced; return }
    if (fenced) return
    if (/^\s*\|/.test(line)) return            // tables are lookup, not prose
    if (/^\s*>/.test(line)) return             // quoted example wording is deliberate
    if (!DIRECTIVE.test(line) && !SOFT.test(unquoted(line))) return
    // A directive wraps across lines. Reading one physical line let a 40-word instruction pass as two.
    let joined = line
    for (let j = i + 1; j < lines.length; j++) {
      const nxt = lines[j]
      if (/^\s*$/.test(nxt) || /^\s*(?:[-*]|\d+\.)\s+\S/.test(nxt) || /^\s*```/.test(nxt) || /^#/.test(nxt)) break
      if (!/^\s+\S/.test(nxt) && !/^\S/.test(nxt)) break
      joined += ' ' + nxt.trim()
      if (/^\s*[-*|>#]/.test(nxt)) break
    }
    const whole = joined.replace(/^\s*(?:[-*]|\d+\.)\s+/, '').replace(/`[^`]*`/g, 'x').replace(/\[[^\]]*\]\([^)]*\)/g, 'x').replace(/\*\*/g, '')
    const bare = (whole.match(/^.*?[.:!?](?=\s|$)/) || [whole])[0]
    const at = `${rel}:${i + 1}`
    const numbered = /^\s*\d+\.\s/.test(line)
    const verbs = whole
      .split(/[.;:!?]+\s+|,\s+|\s(?:and\s+then|and|then)\s+/i)
      .map((clause) => (clause.trim().replace(/^(?:do\s+not|don't|never|always)\s+/i, '').match(/^([A-Za-z]+)\b/) || [])[1])
      .filter((v) => v && IMPERATIVE.test(v))
    if (verbs.length > 1) {
      // A numbered step is a procedure by design, so it is reported and never fatal.
      findings.push({ at, kind: numbered ? 'seq' : 'two', n: verbs.slice(0, 3).join(' + '), line: whole.slice(0, 70) })
    }
    const instructs = (t) => {
      const c = t.trim()
      if (/^you\s+(?:should|must|can|may|might|will)\b/i.test(c)) return true
      const v = (c.replace(/^(?:do\s+not|don't|never|always)\s+/i, '').match(/^([A-Za-z]+)\b/) || [])[1]
      return !!v && IMPERATIVE.test(v)
    }
    const sentences = whole.split(/(?<=[.:!?])\s+/)
    const directives = sentences.filter((t, k) => k === 0 || instructs(t))
    for (const d of directives) {
      if (words(d) > MAX_WORDS) findings.push({ at, kind: 'long', n: words(d), line: d.slice(0, 70) })
    }
    for (const d of sentences.filter((t, k) => k === 0 || instructs(t) || SOFT.test(unquoted(t)))) {
      const h = unquoted(d).match(HEDGE)
      if (h) { findings.push({ at, kind: 'hedge', n: h[0], line: d.slice(0, 70) }); break }
    }
  })
}

if (process.argv.includes('--self-test')) {
  const { fires, clean } = JSON.parse(readFileSync(FIXTURES, 'utf8'))
  const hedged = (line) => {
    const f = []
    inspect('fixture', `---\nname: x\n---\n\n${line}\n`, f)
    return f.some((x) => x.kind === 'hedge')
  }
  const wrong = [...fires.filter((l) => !hedged(l)).map((l) => `did not fire: ${l}`),
    ...clean.filter((l) => hedged(l)).map((l) => `fired on clean input: ${l}`)]
  if (wrong.length) { console.error('✖ instructions self-test:\n  ' + wrong.join('\n  ')); process.exit(1) }
  console.log(`✓ instructions self-test: ${fires.length} hedged directives fire, ${clean.length} plain ones stay clean.`)
  process.exit(0)
}

const findings = []
for (const rel of targets) inspect(rel, readFileSync(join(ROOT, rel), 'utf8'), findings)

const strict = process.argv.includes('--strict')
const FATAL = new Set(['long', 'hedge'])
const byKind = (k) => findings.filter((f) => f.kind === k)
console.log(`instruction clarity: ${targets.length} files · ${byKind('long').length} over ${MAX_WORDS} words`
  + ` · ${byKind('hedge').length} hedged · ${byKind('two').length} multi-action bullets`
  + ` · ${byKind('seq').length} numbered sequences (advisory)`)
for (const f of findings) {
  const tag = f.kind === 'long' ? `${f.n}w` : f.kind === 'hedge' ? `hedge "${f.n}"`
    : f.kind === 'seq' ? `seq ${f.n}` : `two-action ${f.n}`
  console.log(`  ${tag}  ${f.at}\n        ${f.line}`)
}
if (!findings.some((f) => FATAL.has(f.kind))) console.log('✓ no over-long or hedged directive' + (findings.length ? ` (${findings.length} multi-action bullets reported above, judgment not a rule)` : ''))
process.exit(strict && findings.some((f) => FATAL.has(f.kind)) ? 1 : 0)
