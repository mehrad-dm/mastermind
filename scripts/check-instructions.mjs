#!/usr/bin/env node

// A skill body is an instruction parsed by a reader who cannot ask a follow-up. Ambiguity there is
// not a style problem, it is a wrong action. `authoring.md` has demanded unambiguous descriptions
// since the beginning and nothing has ever checked one. STE-informed, never STE-compliant: the
// standard is free to obtain and not free to redistribute, so these are our own rules.

import { readFileSync, readdirSync, existsSync } from 'node:fs'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const MAX_WORDS = 30          // a directive longer than this is carrying more than one instruction
const IMPERATIVE = /^(?:copy|delete|remove|run|write|add|read|move|create|send|open|close|set|check|update|install|commit|push|drop|rename|replace|split|merge|inspect|verify|confirm|deploy|build|test|review|report|record|log|apply|revert|restore|fetch|pull|clone|start|stop|enable|disable|list|print|show|ask|tell|name|state|keep|load|save|scan|search|find|fix|clean|prune|tag|publish|measure|profile|trace|mock|stub|wrap|extract|inline|rewrite|refactor)$/i
const SEPARATOR = /\s(?:and(?:\s+then)?|then|;|,\s*then)\s+/i
const HEDGE = /(?:(?<![-/])\bshould(?:\s+probably)?\b(?!-)|might want to|try to|where possible|if possible|as appropriate|consider (?:doing|using|adding)|it may be worth)\b/i

const targets = []
for (const d of readdirSync(join(ROOT, 'skills'), { withFileTypes: true })) {
  if (!d.isDirectory()) continue
  const f = `skills/${d.name}/SKILL.md`
  if (existsSync(join(ROOT, f))) targets.push(f)
}
for (const f of readdirSync(join(ROOT, 'agents'))) {
  if (f.endsWith('.md')) targets.push(`agents/${f}`)
}

const findings = []
const words = (s) => s.trim().split(/\s+/).filter(Boolean).length

// A directive is a line that commands: a bullet or numbered step, or any line with a hard modal.
const DIRECTIVE = /^\s*(?:[-*]|\d+\.)\s+\S|(?:\b(?:must|never|always|do not|don't)\b)/i

for (const rel of targets) {
  const text = readFileSync(join(ROOT, rel), 'utf8')
  const lines = text.split('\n')
  let fenced = false
  // Frontmatter is skipped on purpose. A `description` is a routing rule listing every trigger, so
  // it is long by design, and check-integrity already caps it at 1024 characters.
  let fm = 0
  lines.forEach((line, i) => {
    if (/^---\s*$/.test(line) && fm < 2) { fm++; return }
    if (fm < 2) return
    if (/^\s*```/.test(line)) { fenced = !fenced; return }
    if (fenced) return
    if (/^\s*\|/.test(line)) return            // tables are lookup, not prose
    if (/^\s*>/.test(line)) return             // quoted example wording is deliberate
    if (!DIRECTIVE.test(line)) return
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
    const directives = whole.split(/(?<=[.:!?])\s+/).filter((t, k) => k === 0 || instructs(t))
    for (const d of directives) {
      if (words(d) > MAX_WORDS) findings.push({ at, kind: 'long', n: words(d), line: d.slice(0, 70) })
    }
    for (const d of directives) {
      const h = d.match(HEDGE)
      if (h) { findings.push({ at, kind: 'hedge', n: h[0], line: d.slice(0, 70) }); break }
    }
  })
}

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
