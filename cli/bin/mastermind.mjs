#!/usr/bin/env node

import { execFileSync, spawnSync } from 'node:child_process'
import { existsSync, readFileSync, readdirSync, realpathSync, rmSync, writeSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, dirname, parse as parsePath } from 'node:path'
import { fileURLToPath } from 'node:url'

const PKG = JSON.parse(
  readFileSync(join(dirname(fileURLToPath(import.meta.url)), '..', 'package.json'), 'utf8'),
)
const VERSION = PKG.version
const PINNED_COMMIT = PKG.commit || process.env.MASTERMIND_COMMIT || ''

// Overridable for tests and forks; defaults are the published truth.
const REPO_URL = process.env.MASTERMIND_REPO || 'https://github.com/mehrad-dm/mastermind'
const MM_HOME_EXPLICIT = !!process.env.MASTERMIND_HOME
const MM_HOME = process.env.MASTERMIND_HOME || join(homedir(), '.mastermind')
const PIN = process.env.MASTERMIND_REF || `v${VERSION}`

const READ_CMDS = ['skills', 'skill', 'agents', 'agent', 'route', 'wrong-log', 'conflicts']
const COMMANDS = [...READ_CMDS, 'check', 'update', 'uninstall', 'init']
const argv = process.argv.slice(2)

if (argv.includes('--help') || argv.includes('-h')) {
  console.log(`MasterMind

  mastermind [tools...]       wire this project (default: the tools it detects)
  mastermind check            report what is wired here and what is broken
  mastermind update           update the brain and repair this project
  mastermind uninstall        remove MasterMind wiring from this project
  mastermind skills           list the skill routing table
  mastermind agents           list the agents

Tools:   claude · cursor · codex        AGENTS.md is always wired, so it is not a tool you name
Flags:   --global · --shared · --isolated        --json is for the listing commands above

Requires: Bash, Git, and Node 18 or newer. On Windows, run it inside WSL.`)
  process.exit(0)
}
if (argv.includes('--version') || argv.includes('-V')) {
  console.log(VERSION)
  process.exit(0)
}

// Rejected BEFORE anything is cloned, fetched or written. An unknown flag used to exit 2 only
// after the brain had been cloned, so a typo left state behind on a command that never ran.
const FLAGS = ['--global', '--shared', '--isolated', '--json', '--check', '--uninstall']
const badFlag = argv.find((a) => a.startsWith('-') && !FLAGS.includes(a))
if (badFlag) {
  console.error(`unknown flag: ${badFlag}\nflags: ${FLAGS.join(' · ')}`)
  process.exit(2)
}

const cmdAt = argv.findIndex((a) => !a.startsWith('-'))
const cmd = cmdAt >= 0 && COMMANDS.includes(argv[cmdAt]) ? argv.splice(cmdAt, 1)[0] : 'init'

// A flag the resolved command has no use for is still a mistake, and the engine only says so
// after the clone. `--json` on an install is the one users hit.
const READ_ONLY_FLAGS = ['--json']
const misplaced = argv.find((a) => READ_ONLY_FLAGS.includes(a) && !READ_CMDS.includes(cmd))
if (misplaced) {
  console.error(`${misplaced} applies to ${READ_CMDS.join(', ')}, not to \`mastermind ${cmd}\`.`)
  process.exit(2)
}
const passthrough = argv // --global, --shared, etc. go straight to the engine

const TOOLS = ['claude', 'cursor', 'codex']
const distance = (a, b) => {
  const d = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)])
  for (let j = 0; j <= b.length; j++) d[0][j] = j
  for (let i = 1; i <= a.length; i++)
    for (let j = 1; j <= b.length; j++)
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1))
  return d[a.length][b.length]
}
for (const word of READ_CMDS.includes(cmd) ? [] : passthrough.filter((a) => !a.startsWith('-'))) {
  if (TOOLS.includes(word)) continue
  const near = [...COMMANDS, ...TOOLS]
    .map((c) => [c, distance(word, c)])
    .filter(([, d]) => d <= 2)
    .sort((u, v) => u[1] - v[1])[0]
  const hint = near ? ` Did you mean \`${near[0]}\`?` : ` Commands: ${COMMANDS.join(', ')}.`
  console.error(`✖ unknown argument "${word}".${hint} Nothing was installed or changed.`)
  process.exit(2)
}

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

// verifyCommit throws through fail() -> process.exit, so cleanup must happen before it runs.

if (process.platform === 'win32') {
  fail('Native Windows is not supported yet: run this inside WSL, where it works as-is.\n'
    + '  Git Bash will not work either: it runs the Windows build of Node, which lands here too.')
}


const findBrain = () => {
  if (MM_HOME_EXPLICIT) return existsSync(join(MM_HOME, 'VERSION')) ? MM_HOME : null
  let dir
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
  const writeAll = (fd, s) => {
    const buf = Buffer.from(s, 'utf8')
    for (let off = 0; off < buf.length; ) off += writeSync(fd, buf, off, buf.length - off)
  }
  const emit = (obj, text) => {
    const out = json ? `${JSON.stringify(obj, null, 2)}\n` : text
    writeAll(1, out.endsWith('\n') ? out : `${out}\n`)
    process.exit(0)
  }
  const refuse = (msg, extra = {}) => {
    if (json) writeAll(1, `${JSON.stringify({ error: msg, ...extra }, null, 2)}\n`)
    else writeAll(2, `✖ ${msg}\n`)
    process.exit(1)
  }
  if (!brain) refuse('no brain found: run `npx mastermind-brain` in this project first')
  if (cmd === 'wrong-log') {
    const journal = join(brain, 'journal.md')
    const lines = existsSync(journal)
      ? readFileSync(journal, 'utf8')
          .split(/\r?\n/)
          .filter((l) => /^\d{4}-\d{2}-\d{2}\s*·\s*wrong\s*·/.test(l.trim()))
      : []
    emit(
      { journal, count: lines.length, entries: lines },
      lines.length
        ? lines.join('\n')
        : `no misses recorded yet in ${journal}: that means nothing has been logged, not that nothing was wrong`,
    )
  }

  if (cmd === 'conflicts') {
    const ours = listCapabilities(brain, 'skill')
    const ourNames = new Set(ours.map((s) => s.name))
    const brainRoots = []
    for (const b of [brain, MM_HOME]) {
      try { if (existsSync(b)) brainRoots.push(realpathSync(b)) } catch { /* unreadable */ }
    }
    const foreign = []
    const seen = new Set()
    for (const root of [join(dirname(brain), '.claude', 'skills'), join(homedir(), '.claude', 'skills')]) {
      if (!existsSync(root)) continue
      for (const e of readdirSync(root, { withFileTypes: true })) {
        const file = join(root, e.name, 'SKILL.md')
        if (!existsSync(file)) continue
        let real = ''
        try { real = realpathSync(file) } catch { continue }
        if (brainRoots.some((b) => real.startsWith(b + '/'))) continue
        const fm = frontmatter(readFileSync(file, 'utf8'))
        const name = fm.name || e.name
        if (seen.has(name)) continue
        seen.add(name)
        foreign.push({ name, description: fm.description || '', path: real, from: root })
      }
    }
    const overlap = (a, b) => {
      const A = new Set(words(a)), B = new Set(words(b))
      if (!A.size || !B.size) return 0
      let shared = 0
      for (const w of A) if (B.has(w)) shared++
      return shared / Math.min(A.size, B.size)
    }
    const collisions = []
    for (const f of foreign) {
      if (ourNames.has(f.name)) collisions.push({ kind: 'name', foreign: f.name, ours: f.name, path: f.path })
      const near = ours
        .map((o) => ({ name: o.name, score: overlap(o.description, f.description) }))
        .filter((o) => o.score >= 0.25) // 0.29 is a genuine overlap (an 'optimize' pack vs `performance`); tuned against real descriptions, not a guess
        .sort((a, b) => b.score - a.score)[0]
      if (near) collisions.push({ kind: 'overlap', foreign: f.name, ours: near.name, share: +near.score.toFixed(2), path: f.path })
    }
    emit(
      { brain, foreign: foreign.map(({ name, from }) => ({ name, from })), collisions,
        note: 'Precedence: this project\'s own skills → installed packs → MasterMind defaults. On a rule conflict the stricter rule wins.' },
      foreign.length === 0
        ? 'no other skill packs installed: nothing to collide with'
        : [
            `${foreign.length} foreign skill(s) installed beside ${ours.length} MasterMind skills`,
            ...collisions.map((c) => c.kind === 'name'
              ? `name   ${c.foreign}: same name as ours (yours is used; ours is mastermind-${c.foreign})`
              : `overlap ${c.foreign} ≈ ${c.ours} (${Math.round(c.share * 100)}% shared triggers)`),
            '',
            'Precedence: your project\'s skills → installed packs → MasterMind defaults.',
            'On a rule conflict (committing, tests, scope) the stricter rule wins.',
          ].join('\n'),
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
        `no ${kind} named "${want}"${near.length ? `: did you mean ${near.map((n) => n.name).join(', ')}?` : ''}`,
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
        note: 'the full table; → marks keyword overlap only. Keyword matching is unreliable on natural phrasing: judge from the descriptions, do not trust the arrows.',
      },
      [
        ...allSkills.map((s) => line('skill', s)),
        ...allAgents.map((a) => line('agent', a)),
        '',
        '→ marks keyword overlap only, and it is often wrong: choose from the descriptions.',
        'then: mastermind skill <name>',
      ].join('\n'),
    )
  }
}

try {
  execFileSync('git', ['--version'], { stdio: 'ignore' })
} catch {
  fail('git is required (the brain is a git repo: that is also how you audit it).')
}
// install.sh is the engine, and Alpine: the usual CI base image: ships without bash.
try {
  execFileSync('bash', ['--version'], { stdio: 'ignore' })
} catch {
  fail('bash is required to install. On Alpine: `apk add --no-cache bash git`.')
}

// ── 1. make sure the shared brain exists (MASTERMIND_HOME, $HOME/.mastermind by default) ──
const verifyCommit = (where, { cleanupOnMismatch = false } = {}) => {
  // fail() exits the process, so anything that must happen first happens here.
  const bail = (msg) => {
    if (cleanupOnMismatch) rmSync(where, { recursive: true, force: true })
    fail(msg)
  }
  if (!PINNED_COMMIT) return // local checkout / unpublished: nothing to verify against
  let head = ''
  try { head = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: where, encoding: 'utf8' }).trim() }
  catch { bail(`cannot read the commit at ${where}: refusing to install unverified code.`) }
  if (head !== PINNED_COMMIT)
    bail(`brain at ${where} is commit ${head.slice(0, 12)}, but this release pins ${PINNED_COMMIT.slice(0, 12)}.\n`
      + '  The tag may have moved. Refusing to install code this release did not publish.')
  let dirty = ''
  try {
    dirty = execFileSync('git', ['status', '--porcelain', '--untracked-files=no'],
      { cwd: where, encoding: 'utf8' }).trim()
  } catch {
    bail(`cannot read the working tree at ${where}: refusing to run code this release cannot verify.\n`
      + `  Check it by hand: git -C ${where} status`)
  }
  if (dirty) {
    const files = dirty.split('\n').map((l) => l.replace(/^..\s+/, '')).slice(0, 5).join(', ')
    bail(`brain at ${where} has uncommitted changes to tracked files (${files}).\n`
      + '  This release can only vouch for the commit it pins, not for edits on top of it.\n'
      + `  Keep them: git -C ${where} stash    Discard them: git -C ${where} checkout -- .`)
  }
}

if (!existsSync(MM_HOME)) {
  console.log(`↓ fetching the brain at ${PIN} → ${MM_HOME}`)
  const st = run('git', ['clone', '--depth', '1', '--branch', PIN, REPO_URL, MM_HOME])
  if (st !== 0) {
    rmSync(MM_HOME, { recursive: true, force: true })
    fail(`clone of ${REPO_URL} at ${PIN} failed`)
  }
  verifyCommit(MM_HOME, { cleanupOnMismatch: true })
} else if (!existsSync(join(MM_HOME, 'install.sh'))) {
  fail(`${MM_HOME} exists but doesn't look like the MasterMind repo: move it aside and re-run.`)
} else if (PINNED_COMMIT && !existsSync(join(MM_HOME, '.git'))) {
  fail(`${MM_HOME} has no git history, so this release cannot verify what it would run.\n`
    + `  A published MasterMind only executes the commit it was built from.\n`
    + `  Move it aside and re-run, or set MASTERMIND_HOME to a real clone.`)
} else if (existsSync(join(MM_HOME, '.git'))) {
  if (cmd === 'update') {
    console.log('↓ updating the brain')
    let onBranch = true
    try { git(['symbolic-ref', '-q', 'HEAD']) } catch { onBranch = false }
    if (onBranch && !PINNED_COMMIT) {
      const st = run('git', ['pull', '--ff-only'], { cwd: MM_HOME })
      if (st !== 0) fail(`update refused: ${MM_HOME} has local changes. Keep them: git -C ${MM_HOME} stash && npx mastermind-brain update. Discard them: git -C ${MM_HOME} checkout -- . && npx mastermind-brain update`)
    }
    else {
      const f = run('git', ['fetch', '--tags', '--depth', '1', 'origin', `refs/tags/${PIN}:refs/tags/${PIN}`], { cwd: MM_HOME })
      if (f !== 0) fail(`could not fetch ${PIN} from ${REPO_URL}: the brain is unchanged; nothing was installed.`)
      const c = run('git', ['checkout', '-q', PIN], { cwd: MM_HOME })
      if (c !== 0) fail(`could not check out ${PIN}: the brain is unchanged; nothing was installed.`)
      verifyCommit(MM_HOME)
    }
  }
  if (PINNED_COMMIT && cmd !== 'update') {
    let head = ''
    try { head = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: MM_HOME, encoding: 'utf8' }).trim() } catch { /* verifyCommit reports it */ }
    if (head && head !== PINNED_COMMIT) {
      console.log(`↻ brain at ${MM_HOME} is behind this release: syncing to ${PIN}`)
      run('git', ['fetch', '--tags', '--depth', '1', 'origin', `refs/tags/${PIN}:refs/tags/${PIN}`], { cwd: MM_HOME })
      const c = run('git', ['checkout', '-q', PIN], { cwd: MM_HOME })
      if (c !== 0)
        fail(`could not update ${MM_HOME} to ${PIN}: the brain is unchanged.\n`
          + `  Fix it by hand: git -C ${MM_HOME} fetch --tags && git -C ${MM_HOME} checkout ${PIN}`)
    }
  }
  verifyCommit(MM_HOME)
}

// ── 2. hand over to the engine ──────────────────────────────────────────────────
const engineArgs =
  cmd === 'check' ? ['--check', ...passthrough]
  : cmd === 'uninstall' ? ['--uninstall', ...passthrough]
  : passthrough // init and update both end in a (re)install: that is the self-heal contract

process.exit(run('bash', [join(MM_HOME, 'install.sh'), ...engineArgs], { cwd: process.cwd() }))
