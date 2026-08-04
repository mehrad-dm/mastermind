#!/usr/bin/env node
// npx mastermind-brain — versioned, provenance-signed front door; install.sh stays the engine
// so every existing flow keeps working. Fresh installs pin the brain to this release's tag.
//
// Commands:
//   npx mastermind-brain              install into the current project (the default)
//   npx mastermind-brain --global     Claude Code in every project
//   npx mastermind-brain check        doctor — is this project wired?
//   npx mastermind-brain update       refresh the brain + repair links
//   npx mastermind-brain uninstall    remove from this project (or with --global)
// Any other flags pass through to install.sh unchanged.
//
// Read-only commands an AGENT calls for itself (no install, no network, no writes):
//   mastermind skills                 the routing table: every skill, one line each
//   mastermind skill <name>           print one skill's full instructions
//   mastermind agents                 the isolated-context roles
//   mastermind agent <name>           print one agent's brief
//   mastermind route "<request>"      which skills match this request, ranked
// These exist because Cursor and Codex have no native skill mechanism: without them an
// agent either inlines the whole library or guesses a path. Add --json for structured output.

import { execFileSync, spawnSync } from 'node:child_process'
import { existsSync, readFileSync, readdirSync, writeSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, dirname, parse as parsePath } from 'node:path'
import { fileURLToPath } from 'node:url'

const VERSION = JSON.parse(
  readFileSync(join(dirname(fileURLToPath(import.meta.url)), '..', 'package.json'), 'utf8'),
).version

// Overridable for tests and forks; defaults are the published truth.
const REPO_URL = process.env.MASTERMIND_REPO || 'https://github.com/mehrad-dm/mastermind'
const MM_HOME = process.env.MASTERMIND_HOME || join(homedir(), '.mastermind')
const PIN = process.env.MASTERMIND_REF || `v${VERSION}`

const READ_CMDS = ['skills', 'skill', 'agents', 'agent', 'route', 'wrong-log']
const COMMANDS = [...READ_CMDS, 'check', 'update', 'uninstall', 'init']
const argv = process.argv.slice(2)
// Find the command wherever it sits, not just at argv[0]. Matching only the first token made
// `mastermind --json skills` — the obvious way to write it — fall through to the DEFAULT,
// which is install: a lookup would have cloned and written to the machine. A read-only
// command must stay read-only however the flags are ordered.
const cmdAt = argv.findIndex((a) => !a.startsWith('-'))
const cmd = cmdAt >= 0 && COMMANDS.includes(argv[cmdAt]) ? argv.splice(cmdAt, 1)[0] : 'init'
const passthrough = argv // --global, --shared, etc. go straight to the engine

const run = (bin, args, opts = {}) => {
  const r = spawnSync(bin, args, { stdio: 'inherit', ...opts })
  if (r.error) throw r.error
  return r.status ?? 1
}
const git = (args, opts = {}) =>
  execFileSync('git', args, { cwd: MM_HOME, encoding: 'utf8', ...opts }).trim()

const fail = (msg) => {
  console.error(`✖ ${msg}`)
  process.exit(1)
}

// ── the agent-callable surface ──────────────────────────────────────────────────
// Read-only by construction: it runs before the install path below, so a lookup can
// never clone, write, or reach the network. If no brain is installed it says so and
// exits non-zero rather than helpfully installing one behind the agent's back.

// The brain a lookup should answer from is the project's own, when there is one: an
// isolated .mastermind/ holds that project's field and lessons, and answering from the
// shared clone instead would quietly return another project's knowledge. Walk up so it
// works from any subdirectory, exactly like git.
const findBrain = () => {
  let dir
  // cwd can be gone (deleted under a watcher, a stale CI worktree). Node throws a raw
  // ENOENT stack from process.cwd() — answer through this file's own error path instead.
  try {
    dir = process.cwd()
  } catch {
    return existsSync(join(MM_HOME, 'VERSION')) ? MM_HOME : null
  }
  for (;;) {
    const candidate = join(dir, '.mastermind')
    if (existsSync(join(candidate, 'VERSION'))) return candidate
    const up = dirname(dir)
    if (up === dir || parsePath(dir).root === dir) break
    dir = up
  }
  return existsSync(join(MM_HOME, 'VERSION')) ? MM_HOME : null
}

// Frontmatter is `name` + `description` between the first pair of --- lines. A hand-rolled
// reader beats a YAML dependency here: the shape is fixed and check-integrity.mjs enforces it.
const frontmatter = (text) => {
  const m = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text)
  const out = {}
  if (!m) return out
  for (const line of m[1].split(/\r?\n/)) {
    const kv = /^(\w[\w-]*):\s*(.*)$/.exec(line)
    if (kv) out[kv[1]] = kv[2].replace(/^["']|["']$/g, '').trim()
  }
  return out
}

const listCapabilities = (brain, kind) => {
  const out = []
  if (kind === 'skill') {
    const dir = join(brain, 'skills')
    if (!existsSync(dir)) return out
    for (const e of readdirSync(dir, { withFileTypes: true })) {
      if (!e.isDirectory() && !e.isSymbolicLink()) continue
      const file = join(dir, e.name, 'SKILL.md')
      if (!existsSync(file)) continue
      const fm = frontmatter(readFileSync(file, 'utf8'))
      out.push({ name: fm.name || e.name, description: fm.description || '', path: file })
    }
  } else {
    const dir = join(brain, 'agents')
    if (!existsSync(dir)) return out
    for (const e of readdirSync(dir, { withFileTypes: true })) {
      if (!e.isFile() || !e.name.endsWith('.md')) continue
      const file = join(dir, e.name)
      const fm = frontmatter(readFileSync(file, 'utf8'))
      out.push({
        name: fm.name || e.name.replace(/\.md$/, ''),
        description: fm.description || '',
        path: file,
      })
    }
  }
  return out.sort((a, b) => a.name.localeCompare(b.name))
}

// Word overlap against the descriptions, which are written as trigger phrases. Measured on
// requests phrased the way people actually talk — "the invoice screen takes nine seconds" —
// this scores 0% top-1 and 25% top-3 (evals/agent-surface-routing.mjs). So it is a HINT, never
// a filter: `route` always returns the whole table and marks what looked related. Routing is a
// judgement the model makes; a lexical shortlist that hides the right skill is worse than none.
const STOP = new Set(('a an the is are was were be been being do does did doing this that these those'
  + ' i we you it my our your its of to in on at for with from by and or but not no so if then than'
  + ' can could should would will just very really please help me my how what why when where which'
  + ' something anything thing stuff need want make made get got go going').split(/\s+/))
const words = (s) => (s.toLowerCase().match(/[a-z][a-z+#.-]{1,}/g) || []).filter((w) => !STOP.has(w))

const rankCapabilities = (items, request) => {
  const q = new Set(words(request))
  return items
    .map((it) => {
      const hay = words(`${it.name} ${it.description}`)
      const hits = [...new Set(hay.filter((w) => q.has(w)))]
      // the skill's own name in the request is a near-certain signal, not one word among many
      const score = hits.length + (q.has(it.name.toLowerCase()) ? 3 : 0)
      return { ...it, score, matched: hits }
    })
    .filter((it) => it.score > 0)
    .sort((a, b) => b.score - a.score || a.name.localeCompare(b.name))
}

if (READ_CMDS.includes(cmd)) {
  const json = passthrough.includes('--json')
  const rest = passthrough.filter((a) => a !== '--json')
  const brain = findBrain()
  // Written with writeSync, not process.stdout.write: to a PIPE — which is how an agent always
  // calls this — stdout is async, and the process.exit() below discards whatever has not
  // flushed. That truncated the full table mid-string at ~8KB, producing invalid JSON. Loop,
  // because writeSync is allowed to write only part of the buffer.
  const writeAll = (fd, s) => {
    const buf = Buffer.from(s, 'utf8')
    for (let off = 0; off < buf.length; ) off += writeSync(fd, buf, off, buf.length - off)
  }
  // Text output is written verbatim — a skill body must arrive as its exact bytes, not with
  // a blank line console.log would add on top of the file's own trailing newline.
  const emit = (obj, text) => {
    const out = json ? `${JSON.stringify(obj, null, 2)}\n` : text
    writeAll(1, out.endsWith('\n') ? out : `${out}\n`)
    process.exit(0)
  }
  // Every failure answers in the shape that was asked for: a caller that requested --json
  // and gets a bare ✖ line crashes its own JSON.parse, and cannot tell a bad argument from
  // a broken tool.
  const refuse = (msg, extra = {}) => {
    if (json) writeAll(1, `${JSON.stringify({ error: msg, ...extra }, null, 2)}\n`)
    else writeAll(2, `✖ ${msg}\n`)
    process.exit(1)
  }
  if (!brain) refuse('no brain found — run `npx mastermind-brain` in this project first')
  // The calibration record: every time a claim of MasterMind's was falsified, with the catcher
  // named (core/rigor.md). It answers "how often is this thing wrong, and about what?" with
  // history instead of self-assessment — which is the only form of that answer worth having.
  if (cmd === 'wrong-log') {
    // `.mastermind/journal.md` — inside the brain that owns it, so an isolated project keeps
    // its own record and a shared clone keeps one across projects (core/rigor.md).
    const journal = join(brain, 'journal.md')
    // Anchored to a dated entry: an unanchored match also caught the journal's own header
    // prose describing the format, inflating the miss count with a sentence about misses.
    const lines = existsSync(journal)
      ? readFileSync(journal, 'utf8')
          .split(/\r?\n/)
          .filter((l) => /^\d{4}-\d{2}-\d{2}\s*·\s*wrong\s*·/.test(l.trim()))
      : []
    emit(
      { journal, count: lines.length, entries: lines },
      lines.length
        ? lines.join('\n')
        : `no misses recorded yet in ${journal} — that means nothing has been logged, not that nothing was wrong`,
    )
  }

  const kind = cmd === 'agent' || cmd === 'agents' ? 'agent' : 'skill'
  const items = listCapabilities(brain, kind)

  if (cmd === 'skills' || cmd === 'agents') {
    emit(
      { brain, [cmd]: items.map(({ name, description }) => ({ name, description })) },
      items.map((i) => `${i.name.padEnd(16)} ${i.description}`).join('\n'),
    )
  }

  if (cmd === 'skill' || cmd === 'agent') {
    const want = rest[0]
    const names = items.map((i) => i.name)
    if (!want) refuse(`which one? try \`mastermind ${kind}s\` for the list`, { available: names })
    const hit = items.find((i) => i.name === want)
    if (!hit) {
      const near = items.filter((i) => i.name.includes(want) || want.includes(i.name))
      refuse(
        `no ${kind} named "${want}"${near.length ? ` — did you mean ${near.map((n) => n.name).join(', ')}?` : ''}`,
        { available: names },
      )
    }
    const body = readFileSync(hit.path, 'utf8')
    emit({ name: hit.name, description: hit.description, path: hit.path, body }, body)
  }

  if (cmd === 'route') {
    const request = rest.join(' ').trim()
    if (!request) refuse('route what? e.g. `mastermind route "why is this page slow?"`')
    const allSkills = listCapabilities(brain, 'skill')
    const allAgents = listCapabilities(brain, 'agent')
    const hintNames = new Set([
      ...rankCapabilities(allSkills, request).slice(0, 3).map((s) => s.name),
      ...rankCapabilities(allAgents, request).slice(0, 2).map((a) => a.name),
    ])
    const line = (kind, i) =>
      `${hintNames.has(i.name) ? '→' : ' '} ${kind}  ${i.name.padEnd(14)} ${i.description}`
    emit(
      {
        request,
        hints: [...hintNames],
        skills: allSkills.map(({ name, description }) => ({ name, description, hint: hintNames.has(name) })),
        agents: allAgents.map(({ name, description }) => ({ name, description, hint: hintNames.has(name) })),
        note: 'the full table; → marks keyword overlap only. Keyword matching is unreliable on natural phrasing — judge from the descriptions, do not trust the arrows.',
      },
      [
        ...allSkills.map((s) => line('skill', s)),
        ...allAgents.map((a) => line('agent', a)),
        '',
        '→ marks keyword overlap only, and it is often wrong — choose from the descriptions.',
        'then: mastermind skill <name>',
      ].join('\n'),
    )
  }
}

if (process.platform === 'win32') {
  fail('Native Windows is not supported yet — run this inside WSL (or Git Bash), where it works as-is.')
}
try {
  execFileSync('git', ['--version'], { stdio: 'ignore' })
} catch {
  fail('git is required (the brain is a git repo — that is also how you audit it).')
}

// ── 1. make sure the shared brain exists (MASTERMIND_HOME, $HOME/.mastermind by default) ──
if (!existsSync(MM_HOME)) {
  console.log(`↓ fetching the brain at ${PIN} → ${MM_HOME}`)
  const st = run('git', ['clone', '--depth', '1', '--branch', PIN, REPO_URL, MM_HOME])
  if (st !== 0) fail(`clone of ${REPO_URL} at ${PIN} failed`)
} else if (!existsSync(join(MM_HOME, 'install.sh'))) {
  fail(`${MM_HOME} exists but doesn't look like the MasterMind repo — move it aside and re-run.`)
} else if (existsSync(join(MM_HOME, '.git'))) {
  if (cmd === 'update') {
    console.log('↓ updating the brain')
    let onBranch = true
    try { git(['symbolic-ref', '-q', 'HEAD']) } catch { onBranch = false }
    if (onBranch) {
      const st = run('git', ['pull', '--ff-only'], { cwd: MM_HOME })
      if (st !== 0) fail(`update refused — ${MM_HOME} has local changes. Keep them: git -C ${MM_HOME} stash && npx mastermind-brain update. Discard them: git -C ${MM_HOME} checkout -- . && npx mastermind-brain update`)
    }
    else {
      run('git', ['fetch', '--tags', '--depth', '1', 'origin', `refs/tags/${PIN}:refs/tags/${PIN}`], { cwd: MM_HOME })
      run('git', ['checkout', '-q', PIN], { cwd: MM_HOME })
    }
  }
  try {
    const have = git(['describe', '--tags', '--always'])
    if (!have.startsWith(PIN) && cmd !== 'update')
      console.log(`ℹ brain at ${MM_HOME} is ${have}; this CLI ships ${PIN} — run \`npx mastermind-brain update\` to sync.`)
  } catch { /* describe can fail on tagless shallow clones — not load-bearing */ }
}

// ── 2. hand over to the engine ──────────────────────────────────────────────────
const engineArgs =
  cmd === 'check' ? ['--check', ...passthrough]
  : cmd === 'uninstall' ? ['--uninstall', ...passthrough]
  : passthrough // init and update both end in a (re)install — that is the self-heal contract

process.exit(run('bash', [join(MM_HOME, 'install.sh'), ...engineArgs], { cwd: process.cwd() }))
