#!/usr/bin/env node

import { execFileSync, spawnSync } from 'node:child_process'
import { createHash } from 'node:crypto'
import { existsSync, lstatSync, readFileSync, readdirSync, realpathSync, rmSync, statSync, writeSync } from 'node:fs'
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

const READ_CMDS = ['skills', 'skill', 'agents', 'agent', 'route', 'wrong-log', 'conflicts', 'next', 'status']
const COMMANDS = [...READ_CMDS, 'check', 'update', 'uninstall', 'init']
const FLAG_CMDS = { '--check': 'check', '--uninstall': 'uninstall' }
const rawArgs = process.argv.slice(2)
const cmdAt = rawArgs.findIndex((a) => !a.startsWith('-'))
// `agents` is also a tool name: beside --check or --uninstall it is the tool, not the listing.
const asTool = cmdAt >= 0 && rawArgs[cmdAt] === 'agents' && rawArgs.some((a) => a in FLAG_CMDS)
const named = cmdAt >= 0 && !asTool && COMMANDS.includes(rawArgs[cmdAt]) ? rawArgs[cmdAt] : null
// Whatever follows `route` is the request, even when it starts with a dash.
const routeTail = named === 'route' ? rawArgs.slice(cmdAt + 1) : []
let argv = named === 'route' ? rawArgs.slice(0, cmdAt) : rawArgs.filter((_, i) => !(named && i === cmdAt))

if (argv.includes('--help') || argv.includes('-h')) {
  console.log(`MasterMind

  mastermind [tools...]       wire this project (default: the tools it detects)
  mastermind check            report what is wired here and what is broken
  mastermind update           update the brain and repair this project
  mastermind uninstall        remove MasterMind wiring from this project
  mastermind status           version, brain, kernel, field, logged misses and the next spec step
  mastermind skills           list the skill routing table, ours and any pack you installed
  mastermind agents           list the agents
  mastermind conflicts        show where an installed pack overlaps ours
  mastermind next [feature]   where a spec-driven feature stands, and the skill that comes next

Tools:   claude · cursor · codex        AGENTS.md is always wired, so it is not a tool you name
Flags:   --global · --shared · --isolated        --json is for status and the listing commands above

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

const flagCmds = [...new Set(argv.filter((a) => a in FLAG_CMDS).map((a) => FLAG_CMDS[a]))]
if (flagCmds.length > 1) {
  console.error('--check and --uninstall do different things: pick one.')
  process.exit(2)
}
if (flagCmds.length && named && named !== flagCmds[0]) {
  console.error(`--${flagCmds[0]} is \`mastermind ${flagCmds[0]}\`, so it cannot be combined with \`mastermind ${named}\`. Nothing was installed or changed.`)
  process.exit(2)
}
const cmd = named || flagCmds[0] || 'init'
argv = argv.filter((a) => !(a in FLAG_CMDS))

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
  if (TOOLS.includes(word) || word === 'agents') continue
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

// A skill we did not write may put its description in a YAML block scalar, with the text on the
// following indented lines. Reading the key line alone yields ">-", and the skill then routes on
// nothing at all.
const frontmatter = (text) => {
  const m = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text)
  const out = {}
  if (!m) return out
  const lines = m[1].split(/\r?\n/)
  for (let i = 0; i < lines.length; i++) {
    const kv = /^(\w[\w-]*):\s*(.*)$/.exec(lines[i])
    if (!kv) continue
    let value = kv[2].trim()
    if (value === '' || /^[|>](?:[-+]?\d*|\d+[-+]?)$/.test(value)) {
      const block = []
      while (i + 1 < lines.length && (/^\s+\S/.test(lines[i + 1]) || /^\s*$/.test(lines[i + 1]))) {
        const next = lines[i + 1]
        if (/^\s*$/.test(next)) {
          const more = lines.slice(i + 2).find((l) => !/^\s*$/.test(l))
          if (!more || !/^\s+\S/.test(more)) break
        }
        block.push(lines[++i].trim())
      }
      while (block.length && block[block.length - 1] === '') block.pop()
      if (block.length) value = block.join(' ').replace(/\s+/g, ' ').trim()
    }
    if (/^"[\s\S]*"$/.test(value)) {
      value = value.slice(1, -1)
        .replace(/\\U([0-9a-fA-F]{8})|\\u([0-9a-fA-F]{4})/g, (_, u8, u4) =>
          String.fromCodePoint(parseInt(u8 || u4, 16)))
        .replace(/\\(["\\/])/g, '$1').replace(/\\n/g, ' ').replace(/\\t/g, ' ')
    } else if (/^'[\s\S]*'$/.test(value)) {
      value = value.slice(1, -1).replace(/''/g, "'")
    }
    out[kv[1]] = value.trim()
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

const GENERATED_MARK = 'Generated by ~' + '/.mastermind/install.sh'

const readSkillsFrom = (root, source, pack = '') => {
  const out = []
  if (!existsSync(root)) return out
  let entries
  try { entries = readdirSync(root, { withFileTypes: true }) } catch { return out }
  const dirs = []
  for (const e of entries) {
    if (!e.isDirectory() && !e.isSymbolicLink()) continue
    if (existsSync(join(root, e.name, 'SKILL.md'))) { dirs.push(join(root, e.name)); continue }
    let nested = []
    try { nested = readdirSync(join(root, e.name), { withFileTypes: true }) } catch { continue }
    for (const n of nested) {
      if (!n.isDirectory() && !n.isSymbolicLink()) continue
      if (existsSync(join(root, e.name, n.name, 'SKILL.md'))) dirs.push(join(root, e.name, n.name))
    }
  }
  for (const dir of dirs) {
    const e = { name: dir.split('/').pop() }
    const file = join(dir, 'SKILL.md')
    let real
    try { real = realpathSync(file) } catch { continue }
    let text, fm
    try { text = readFileSync(file, 'utf8'); fm = frontmatter(text) } catch { continue }
    if (e.name.startsWith('mastermind-') && text.includes(GENERATED_MARK)) continue
    out.push({ name: fm.name || e.name, description: fm.description || '', path: real, source, pack })
  }
  return out
}

// Installed plugin packs, resolved through the registry rather than by globbing the cache: the
// cache also holds marketplace packs that were browsed and never installed.
const pluginPackRoots = () => {
  const reg = join(homedir(), '.claude', 'plugins', 'installed_plugins.json')
  if (!existsSync(reg)) return []
  let parsed
  try { parsed = JSON.parse(readFileSync(reg, 'utf8')) } catch { return [] }
  const roots = []
  for (const [key, installs] of Object.entries(parsed?.plugins ?? {})) {
    if (!Array.isArray(installs)) continue
    for (const inst of installs) {
      if (!inst?.installPath) continue
      roots.push({ pack: String(key).split('@')[0], root: join(inst.installPath, 'skills') })
    }
  }
  return roots
}

// Every place the three supported tools keep skills, plus one that belongs to no tool. Codex has
// no skill directory of its own, so without `local/skills` a Codex user has nowhere to put one.
const projectDir = () => {
  let dir
  try { dir = process.cwd() } catch { return null }
  const home = homedir()
  let gitRoot = null
  let pkg = null
  for (let d = dir; ; ) {
    // Stop at the nearest one: without this the walk kept climbing and the
    // outermost repo won, so a project inside a repo (or under a home directory
    // that is itself a repo) resolved to the wrong root, or to none at all.
    if (existsSync(join(d, '.git'))) { gitRoot = d; break }
    if (!pkg && existsSync(join(d, 'package.json'))) pkg = d
    const up = dirname(d)
    if (up === d || parsePath(d).root === d) break
    d = up
  }
  const found = gitRoot || pkg || dir
  return found === home ? null : found
}

const skillRoots = (brain) => {
  const home = homedir()
  const codexHome = process.env.CODEX_HOME || join(home, '.codex')
  const project = projectDir()
  return [
    ...(project ? [
      [join(project, '.claude', 'skills'), 'project'],
      [join(project, '.agents', 'skills'), 'project'],
      [join(project, '.cursor', 'skills'), 'project'],
      [join(project, '.codex', 'skills'), 'project'],
    ] : []),
    [join(brain, 'local', 'skills'), 'local'],
    [join(home, '.claude', 'skills'), 'user'],
    [join(home, '.agents', 'skills'), 'user'],
    [join(home, '.cursor', 'skills'), 'cursor'],
    [join(home, '.cursor', 'skills-cursor'), 'cursor'],
    [join(codexHome, 'skills'), 'codex'],
  ]
}

// Precedence, highest first: this project's own skills, then ones placed by hand, then installed
// packs. A skill that resolves back into a brain's own `skills/` is ours, however it was linked.
const discoverForeign = (brain) => {
  const ourSkillDirs = []
  for (const b of [brain, MM_HOME]) {
    try { if (existsSync(b)) ourSkillDirs.push(join(realpathSync(b), 'skills')) } catch { /* unreadable */ }
  }
  const found = [
    ...skillRoots(brain).flatMap(([root, source]) => readSkillsFrom(root, source)),
    ...pluginPackRoots().flatMap(({ pack, root }) => readSkillsFrom(root, 'plugin', pack)),
  ]
  const kept = []
  const shadowed = []
  const byName = new Set()
  const byPath = new Set()
  for (const s of found) {
    if (ourSkillDirs.some((d) => s.path.startsWith(d + '/'))) continue
    if (byPath.has(s.path)) continue
    byPath.add(s.path)
    if (byName.has(s.name)) { shadowed.push(s); continue }
    byName.add(s.name)
    kept.push(s)
  }
  return { foreign: kept, shadowed }
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

// One rule for the field and for feature folders. hooks/session-start.sh mirrors these four
// patterns, and tests/agent-surface.test.sh feeds both the same fixtures.
const FIELD_NAME_RE = /^[#* \t]*Current field:[*` \t]*([^*`]*)/
const FIELD_LEVEL_RE = /^[ \t]*[-*][ \t]*\*\*Level:\*\*[ \t]*([0-9]{1,9})/
const SPECS_DIR_RE = /^-?[ \t]*`?specs-dir:[ \t]*([^` \t]+)/
const FEATURE_RE = /^[0-9]{3,}-[a-z0-9-]+$/
const firstMatch = (file, re) => {
  let text
  try { text = readFileSync(file, 'utf8') } catch { return null }
  for (const line of text.split(/\r?\n/)) {
    const m = re.exec(line)
    if (m) return m[1]
  }
  return null
}
const fieldFile = (brain, proj) => {
  const own = proj && join(proj, '.mastermind', 'engineering', 'active-field.md')
  return own && existsSync(own) ? own : join(brain, 'engineering', 'active-field.md')
}
const readField = (file) => {
  let name = (firstMatch(file, FIELD_NAME_RE) || '').replace(/[ \t]+$/, '')
  if (/^(none|_)/i.test(name)) name = ''
  const lvl = firstMatch(file, FIELD_LEVEL_RE)
  return { name: name || null, level: lvl === null ? (name ? 1 : 0) : Number(lvl) }
}
const specsDirOf = (proj) => {
  const v = firstMatch(join(proj, '.mastermind', 'prefs.md'), SPECS_DIR_RE)
  // The value comes from the repository: a path that leaves the project is ignored.
  return v && !v.startsWith('/') && !v.split(/[\\/]/).includes('..') ? v : 'specs'
}
const featureFolders = (specs) => {
  try {
    return readdirSync(specs, { withFileTypes: true })
      .filter((e) => e.isDirectory() && FEATURE_RE.test(e.name)).map((e) => e.name)
  } catch { return [] }
}

const specState = (proj, asked) => {
  const dirName = specsDirOf(proj)
  const specs = join(proj, dirName)
  if (!existsSync(specs)) return { dirName, missing: true }
  const read = (f) => { try { return readFileSync(f, 'utf8') } catch { return null } }
  const features = featureFolders(specs).map((name) => {
    const dir = join(specs, name)
    const spec = read(join(dir, 'spec.md'))
    const tasks = read(join(dir, 'tasks.md'))
    const status = (spec?.match(/\*\*Status\*\*\s*([a-z]+)/) || [])[1] || (spec ? 'draft' : 'none')
    let mtime = 0
    for (const f of readdirSync(dir)) { try { mtime = Math.max(mtime, statSync(join(dir, f)).mtimeMs) } catch { /* gone */ } }
    return {
      name, status, mtime,
      markers: spec ? (spec.match(/\[NEEDS CLARIFICATION/g) || []).length : 0,
      plan: existsSync(join(dir, 'plan.md')),
      tasksOpen: tasks ? (tasks.match(/^\s*- \[ \]/gm) || []).length : null,
      tasksDone: tasks ? (tasks.match(/^\s*- \[[xX]\]/gm) || []).length : null,
    }
  })
  let branch = ''
  try { branch = execFileSync('git', ['rev-parse', '--abbrev-ref', 'HEAD'], { cwd: proj, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim() } catch { /* not git */ }
  const open = features.filter((f) => f.status !== 'converged').sort((a, b) => b.mtime - a.mtime)
  const pick = (asked && features.find((f) => f.name === asked || f.name.endsWith(`-${asked}`)))
    || features.find((f) => branch && (branch === f.name || branch.endsWith(`/${f.name}`)))
    || open[0] || null
  const how = !pick ? '' : asked ? 'named' : branch && pick.name !== open[0]?.name ? 'matches the branch' : 'most recently changed open feature'
  const constitution = existsSync(join(specs, 'constitution.md'))
  let next, why
  if (asked && !pick) { next = 'specify'; why = `no feature folder matches "${asked}"` }
  else if (!pick) { next = constitution ? 'specify' : 'constitution'; why = features.length ? 'every feature has converged' : 'no feature folder yet' }
  else if (pick.status === 'none') { next = 'specify'; why = 'the folder has no spec.md' }
  else if (pick.status === 'blocked') { next = 'ask the user'; why = 'the spec is blocked on a decision only the user can make: read its Clarifications and the open task' }
  else if (pick.markers) { next = 'interview'; why = `${pick.markers} open question(s) in the spec` }
  else if (pick.status === 'draft') { next = 'interview'; why = 'the spec has not had its clarification pass' }
  else if (!pick.plan) { next = 'blueprint'; why = 'no plan.md yet' }
  else if (pick.tasksOpen === null) { next = 'breakdown'; why = 'no tasks.md yet' }
  else if (pick.tasksOpen && !pick.tasksDone) { next = 'build'; why = `${pick.tasksOpen} task(s), none started: run analyze first if it touches money, auth or data` }
  else if (pick.tasksOpen) { next = 'build'; why = `${pick.tasksOpen} task(s) still open` }
  else if (pick.status !== 'converged') { next = 'converge'; why = 'every task is ticked, and a ticked box is a claim, not evidence' }
  else { next = 'specify'; why = `${pick.name} has converged and is history now: start the next feature, or name another one` }
  return { dirName, features, pick, how, constitution, next, why }
}

const readMisses = (brain) => {
  const proj = projectDir()
  const seen = new Set()
  const journals = [proj && join(proj, '.mastermind', 'journal.md'), join(brain, 'journal.md')]
    .filter((f) => f && existsSync(f) && !seen.has(f) && seen.add(f))
  const lines = journals.flatMap((f) =>
    readFileSync(f, 'utf8')
      .split(/\r?\n/)
      .filter((l) => /^\d{4}-\d{2}-\d{2}\s*·\s*wrong\s*·/.test(l.trim())))
  return { journals, lines }
}

// The installer's own project rule and record location, so `status` and `update` read the record
// the installer wrote. PWD is tried too: the installer keys a shared project on the logical path.
const installProjects = () => {
  const home = homedir()
  const walk = (start) => {
    let gitRoot = null
    for (let d = start; d !== home; ) {
      try { if (lstatSync(join(d, '.mastermind')).isDirectory()) return d } catch { /* none here */ }
      if (existsSync(join(d, '.git'))) { gitRoot = d; break }
      const up = dirname(d)
      if (up === d) break
      d = up
    }
    return gitRoot || start
  }
  const starts = []
  try { starts.push(process.cwd()) } catch { /* cwd is gone */ }
  const pwd = process.env.PWD
  try { if (pwd && starts.length && realpathSync(pwd) === realpathSync(starts[0])) starts.push(pwd) } catch { /* stale PWD */ }
  return [...new Set(starts.map(walk))]
}
const parseRecord = (file) => {
  let text
  try { text = readFileSync(file, 'utf8') } catch { return null }
  const rec = {}
  for (const line of text.split(/\r?\n/)) {
    const at = line.indexOf('=')
    if (at > 0) rec[line.slice(0, at)] = line.slice(at + 1)
  }
  return rec
}
const stateDir = () => process.env.MM_STATE_DIR || join(homedir(), '.mastermind-state')
const projectRecord = () => {
  for (const proj of installProjects()) {
    const own = parseRecord(join(proj, '.mastermind', '.installed'))
    if (own) return own
    const key = createHash('sha256').update(proj).digest('hex').slice(0, 16)
    const hashed = parseRecord(join(stateDir(), 'projects', key))
    if (hashed) return hashed
    const legacy = parseRecord(join(stateDir(), 'projects', proj.replace(/[^A-Za-z0-9._-]/g, '_')))
    if (legacy && legacy.project === proj) return legacy
  }
  return null
}
const MODES = ['isolated', 'shared', 'global', 'source']
const real = (p) => { try { return realpathSync(p) } catch { return p } }
const modeOf = (brain) => {
  const rec = projectRecord()
  if (rec && MODES.includes(rec.mode)) return rec.mode
  const rb = real(brain)
  if (installProjects().some((proj) => real(join(proj, '.mastermind')) === rb)) return 'isolated'
  let cwd = ''
  try { cwd = real(process.cwd()) } catch { /* cwd is gone */ }
  if (cwd === rb || cwd.startsWith(rb + '/')) return 'source'
  if (rec) return rec.scope === 'global' ? 'global' : 'shared'
  const global = parseRecord(join(stateDir(), 'global'))
  return global && MODES.includes(global.mode) ? global.mode : 'global'
}

if (READ_CMDS.includes(cmd)) {
  const json = passthrough.includes('--json') || routeTail.includes('--json')
  const rest = (cmd === 'route' ? routeTail : passthrough).filter((a) => a !== '--json')
  const brain = findBrain()
  const writeAll = (fd, s) => {
    const buf = Buffer.from(s, 'utf8')
    try {
      for (let off = 0; off < buf.length; ) off += writeSync(fd, buf, off, buf.length - off)
    } catch (e) {
      // `mastermind skills | head` closes the pipe early. That is the reader's choice, not our
      // error, and a node stack trace in the middle of a shell pipeline is noise.
      if (e && (e.code === 'EPIPE' || e.code === 'ERR_STREAM_DESTROYED')) process.exit(0)
      throw e
    }
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
  if (cmd === 'status') {
    const proj = projectDir()
    const kernelPath = join(brain, 'CLAUDE.md')
    let version = null, chars = null
    try { version = readFileSync(join(brain, 'VERSION'), 'utf8').trim() } catch { /* unreadable */ }
    try { chars = readFileSync(kernelPath, 'utf8').length } catch { /* no kernel */ }
    const field = readField(fieldFile(brain, proj))
    const { lines } = readMisses(brain)
    let last = null
    for (const l of lines) {
      const [date, , what = ''] = l.trim().split(/\s*·\s*/)
      if (!last || date >= last.date) last = { date, what }
    }
    const st = proj ? specState(proj) : { missing: true }
    const next = st.missing ? null : { feature: st.pick ? st.pick.name : null, skill: st.next, reason: st.why }
    const mode = modeOf(brain)
    emit(
      { version, brain: real(brain), mode, kernel: { path: real(kernelPath), chars }, field,
        misses: { count: lines.length, last }, next },
      [
        `MasterMind ${version ?? 'unknown'} · ${mode} brain at ${real(brain)}`,
        `kernel ${chars === null ? 'missing' : `${chars} chars`} · field ${field.name ? `${field.name}, level ${field.level}` : 'none yet (say init to build one)'}`,
        `misses ${lines.length} logged${last ? ` · last ${last.date}: ${last.what.length > 80 ? `${last.what.slice(0, 77)}...` : last.what}` : ''}`,
        next ? `next ${next.feature ? `${next.feature}: ` : ''}${next.skill} (${next.reason})` : 'next none: this project does not work spec-first',
      ].join('\n'),
    )
  }
  if (cmd === 'next') {
    const proj = projectDir()
    if (!proj) refuse('not inside a project')
    const st = specState(proj, argv.find((a) => !a.startsWith('-')))
    const { dirName } = st
    if (st.missing) {
      emit({ specs: null, next: null, why: 'no specs folder: this project does not work spec-first' },
        `no ${dirName}/ here: this project does not work spec-first. Small changes go straight to build.`)
    }
    const { features, pick, how, constitution, next, why } = st
    emit(
      { specs: dirName, constitution, feature: pick && (({ mtime, ...f }) => f)(pick), picked: how || null, next, why, features: features.map(({ mtime, ...f }) => f) },
      [
        pick ? `${dirName}/${pick.name} · ${pick.status}${pick.tasksOpen !== null ? ` · ${pick.tasksDone} done, ${pick.tasksOpen} open` : ''}${how ? ` (${how})` : ''}` : `${dirName}/ · ${features.length} feature(s)`,
        `next: ${next}: ${why}`,
        constitution ? '' : 'no constitution.md: rules every feature is checked against are not written down yet',
      ].filter(Boolean).join('\n'),
    )
  }
  if (cmd === 'wrong-log') {
    const { journals, lines } = readMisses(brain)
    const where = journals.length ? journals.join(' + ') : join(brain, 'journal.md')
    emit(
      { journals, count: lines.length, entries: lines },
      lines.length
        ? lines.join('\n')
        : `no misses recorded yet in ${where}: that means nothing has been logged, not that nothing was wrong`,
    )
  }

  if (cmd === 'conflicts') {
    const ours = listCapabilities(brain, 'skill')
    const ourNames = new Set(ours.map((s) => s.name))
    const { foreign, shadowed } = discoverForeign(brain)
    const all = [...ours, ...foreign]
    const df = new Map()
    for (const it of all) for (const w of new Set(words(it.description))) df.set(w, (df.get(w) || 0) + 1)
    const common = (w) => (df.get(w) || 0) > Math.max(3, all.length * 0.2)
    const overlap = (a, b) => {
      const A = new Set(words(a).filter((w) => !common(w)))
      const B = new Set(words(b).filter((w) => !common(w)))
      if (A.size < 3 || B.size < 3) return 0
      let shared = 0
      for (const w of A) if (B.has(w)) shared++
      if (shared < 3) return 0
      return shared / Math.min(A.size, B.size)
    }
    const collisions = []
    for (const f of foreign) {
      if (ourNames.has(f.name)) collisions.push({ kind: 'name', foreign: f.name, ours: f.name, path: f.path })
      const near = ours
        .map((o) => ({ name: o.name, score: overlap(o.description, f.description) }))
        .filter((o) => o.score >= 0.4) // raised from 0.25: at ~75 foreign skills that produced false pairs like automate/build
        .sort((a, b) => b.score - a.score)[0]
      if (near) collisions.push({ kind: 'overlap', foreign: f.name, ours: near.name, share: +near.score.toFixed(2), path: f.path })
    }
    emit(
      { brain,
        foreign: foreign.map(({ name, source, pack, path }) => ({ name, source, pack, from: dirname(dirname(path)) })),
        shadowed: shadowed.map(({ name, source, pack }) => ({ name, source, pack })),
        collisions,
        note: 'Precedence: this project\'s own skills → installed packs → MasterMind defaults. On a rule conflict the stricter rule wins.' },
      foreign.length === 0
        ? 'no other skill packs installed: nothing to collide with'
        : [
            `${foreign.length} foreign skill(s) installed beside ${ours.length} MasterMind skills`,
            ...collisions.map((c) => c.kind === 'name'
              ? `name   ${c.foreign}: same name as ours (yours is used; ours is mastermind-${c.foreign})`
              : `overlap ${c.foreign} ≈ ${c.ours} (${Math.round(c.share * 100)}% shared triggers)`),
            ...shadowed.map((s) => `hidden  ${s.name}: a higher-precedence skill of the same name wins`),
            '',
            'Precedence: your project\'s skills → installed packs → MasterMind defaults.',
            'On a rule conflict (committing, tests, scope) the stricter rule wins.',
          ].join('\n'),
    )
  }

  const kind = cmd === 'agent' || cmd === 'agents' ? 'agent' : 'skill'
  // A skill the user installed is only reachable in Cursor and Codex if this table names it:
  // those two have no native skill mechanism, so an index they cannot see does not exist.
  const everySkill = () => {
    const { foreign } = discoverForeign(brain)
    const taken = new Set(foreign.map((f) => f.name))
    const ours = listCapabilities(brain, 'skill').map((s) => {
      if (!taken.has(s.name)) return { ...s, source: 'mastermind', pack: '' }
      // The alias can be taken too. Keep stepping until the name is free, or ours disappears.
      let name = `mastermind-${s.name}`
      for (let n = 2; taken.has(name); n++) name = `mastermind-${s.name}-${n}`
      taken.add(name)
      return { ...s, name, plainName: s.name, source: 'mastermind', pack: '', shadows: s.name }
    })
    return [...foreign, ...ours].sort((a, b) => a.name.localeCompare(b.name))
  }
  const items = kind === 'skill' ? everySkill() : listCapabilities(brain, 'agent')
  const origin = (i) => (i.source === 'plugin' ? i.pack : i.source)

  if (cmd === 'skills' || cmd === 'agents') {
    emit(
      { brain,
        [cmd]: items.map(({ name, description, source, pack }) =>
          kind === 'skill' ? { name, description, source, pack } : { name, description }) },
      items.map((i) =>
        kind === 'skill'
          ? `${i.name.padEnd(24)} ${origin(i).padEnd(16)} ${i.description}`
          : `${i.name.padEnd(16)} ${i.description}`).join('\n'),
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
    const guard = hit.source && hit.source !== 'mastermind'
      ? `From ${origin(hit)}, not MasterMind. Follow its instructions, keep MasterMind's definition of `
        + `done: verify before saying done, stay in the scope you were given.`
      : ''
    emit(
      { name: hit.name, description: hit.description, path: hit.path, source: hit.source ?? 'mastermind',
        ...(guard ? { guard } : {}), body },
      guard ? `${body}\n\n---\n${guard}` : body,
    )
  }

  if (cmd === 'route') {
    const request = rest.join(' ').trim()
    if (!request) refuse('route what? e.g. `mastermind route "why is this page slow?"`')
    const allSkills = everySkill()
    const allAgents = listCapabilities(brain, 'agent')
    const hintNames = new Set([
      ...rankCapabilities(allSkills, request).slice(0, 3).map((s) => s.name),
      ...rankCapabilities(allAgents, request).slice(0, 2).map((a) => a.name),
    ])
    // A machine with a few packs installed reached 100 skills and ~8.7k tokens for one route call,
    // which costs more than routing saves. Ours and anything that scored keep their description; the
    // rest keep their name, so nothing vanishes and any of them can still be asked for by name.
    const scored = new Set(rankCapabilities(allSkills, request).map((s) => s.name))
    const full = (i) => i.source === 'mastermind' || scored.has(i.name) || hintNames.has(i.name)
    const brief = allSkills.filter((i) => !full(i))
    const line = (kind, i) =>
      `${hintNames.has(i.name) ? '→' : ' '} ${kind}  ${i.name.padEnd(24)} ${(i.source ? origin(i) : '').padEnd(16)} ${i.description}`
    emit(
      {
        request,
        hints: [...hintNames],
        skills: allSkills.map(({ name, description, source, pack }) => ({
          name, source, pack, hint: hintNames.has(name),
          description: full({ name, source }) ? description : undefined,
        })),
        agents: allAgents.map(({ name, description }) => ({ name, description, hint: hintNames.has(name) })),
        note: 'Every skill is listed. Ours and anything matching your words carry their description; the rest are named only, and `mastermind skill <name>` prints any of them. → marks keyword overlap only and is often wrong on natural phrasing: judge from the descriptions. A skill whose source is not "mastermind" is one you installed: follow its instructions, keep MasterMind\'s definition of done.',
      },
      [
        ...allSkills.filter(full).map((s) => line('skill', s)),
        ...allAgents.map((a) => line('agent', a)),
        ...(brief.length
          ? ['', 'also installed, names only (`mastermind skill <name>` prints any of them):',
             '  ' + brief.map((s) => s.name).join(' · ')]
          : []),
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
  const quiet = (args) => spawnSync('git', args, { cwd: MM_HOME, stdio: 'ignore' }).status === 0
  // A clone on a branch is someone's working copy: it moves by fast-forward or not at all.
  const syncToPin = () => {
    const onBranch = quiet(['symbolic-ref', '-q', 'HEAD'])
    const tagRef = `refs/tags/${PIN}:refs/tags/${PIN}`
    const fetched = run('git', onBranch ? ['fetch', 'origin', tagRef] : ['fetch', '--tags', '--depth', '1', 'origin', tagRef], { cwd: MM_HOME })
    if (!quiet(['rev-parse', '-q', '--verify', `${PIN}^{commit}`])) return fetched === 0 ? 'checkout' : 'fetch'
    const behind = quiet(['merge-base', '--is-ancestor', 'HEAD', PIN])
    if (onBranch) {
      if (!behind) {
        const branch = git(['symbolic-ref', '--short', 'HEAD'])
        fail(`brain at ${MM_HOME} is on branch ${branch} with commits that ${PIN} does not contain, so it was left alone.\n`
          + `  Keep working there and give this release its own brain:  MASTERMIND_HOME=<another folder> npx mastermind-brain\n`
          + `  Or move this clone to the release yourself:  git -C ${MM_HOME} switch --detach ${PIN}`)
      }
      return run('git', ['merge', '-q', '--ff-only', PIN], { cwd: MM_HOME }) === 0 ? '' : 'checkout'
    }
    if (!behind && !git(['tag', '--points-at', 'HEAD'])) {
      fail(`brain at ${MM_HOME} is at a commit that is neither a release nor part of ${PIN}, so it was left alone.\n`
        + `  Move it to the release yourself:  git -C ${MM_HOME} switch --detach ${PIN}`)
    }
    return run('git', ['checkout', '-q', PIN], { cwd: MM_HOME }) === 0 ? '' : 'checkout'
  }
  if (cmd === 'update') {
    console.log('↓ updating the brain')
    if (!PINNED_COMMIT && quiet(['symbolic-ref', '-q', 'HEAD'])) {
      const st = run('git', ['pull', '--ff-only'], { cwd: MM_HOME })
      if (st !== 0) fail(`update refused: ${MM_HOME} has local changes. Keep them: git -C ${MM_HOME} stash && npx mastermind-brain update. Discard them: git -C ${MM_HOME} checkout -- . && npx mastermind-brain update`)
    }
    else {
      const went = syncToPin()
      if (went === 'fetch') fail(`could not fetch ${PIN} from ${REPO_URL}: the brain is unchanged; nothing was installed.`)
      if (went) fail(`could not check out ${PIN}: the brain is unchanged; nothing was installed.`)
      verifyCommit(MM_HOME)
    }
  }
  if (PINNED_COMMIT && cmd !== 'update') {
    let head = ''
    try { head = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: MM_HOME, encoding: 'utf8' }).trim() } catch { /* verifyCommit reports it */ }
    if (head && head !== PINNED_COMMIT) {
      console.log(`↻ brain at ${MM_HOME} is not at this release: syncing to ${PIN}`)
      if (syncToPin())
        fail(`could not update ${MM_HOME} to ${PIN}: the brain is unchanged.\n`
          + `  Fix it by hand: git -C ${MM_HOME} fetch --tags && git -C ${MM_HOME} checkout ${PIN}`)
    }
  }
  verifyCommit(MM_HOME)
}

// ── 2. hand over to the engine ──────────────────────────────────────────────────
// AGENTS.md (and .agents/skills) is always wired, so naming tools must not drop it. Uninstall is
// the exception: removing one tool keeps what the others still read.
const always = cmd !== 'uninstall' && !passthrough.includes('--global') && !passthrough.includes('agents')
  && passthrough.some((a) => TOOLS.includes(a)) ? ['agents'] : []
// An update with no mode flag repairs the install in the mode it was made in.
const recorded = cmd === 'update' && !passthrough.some((a) => ['--global', '--shared', '--isolated'].includes(a))
  ? projectRecord()?.mode : null
const modeFlag = recorded === 'shared' || recorded === 'isolated' ? [`--${recorded}`] : []
const engineArgs =
  cmd === 'check' ? ['--check', ...passthrough, ...always]
  : cmd === 'uninstall' ? ['--uninstall', ...passthrough]
  : [...modeFlag, ...passthrough, ...always] // init and update both end in a (re)install: that is the self-heal contract

process.exit(run('bash', [join(MM_HOME, 'install.sh'), ...engineArgs], { cwd: process.cwd() }))
