import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join, resolve } from 'node:path'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const P = join(ROOT, '.foglamp', 'scan.json')
const count = (dir, pred) => readdirSync(join(ROOT, dir), { withFileTypes: true }).filter(pred).length


const d = JSON.parse(readFileSync(P, 'utf8'))
const g = d.graph

const NEW_NODES = [
  {
    id: 'install',
    label: 'install.sh',
    kind: 'entry',
    sub: 'safe project wiring + updates',
    sourceRef: 'install.sh',
    detail:
      'Copies an isolated brain into the project by default, then wires Claude Code, Cursor and Codex without replacing project-owned instructions. Shared and global modes are explicit opt-ins.',
  },
  {
    id: 'cli',
    label: 'npx mastermind-brain',
    kind: 'entry',
    sub: 'installer + agent lookups',
    sourceRef: 'cli/',
    detail:
      'Installs the brain, and answers an agent mid-task: skills, skill, agents, agent, route, conflicts, wrong-log — from whichever brain the directory belongs to. Read-only.',
  },
  { id: 'lab', label: 'Quarantine', kind: 'store', sub: 'private data, gitignored', group: 'Safety & honesty', sourceRef: 'skills/quarantine/' },
  {
    id: 'bootstrap',
    label: 'Bootstrap hook',
    kind: 'service',
    sub: 're-injects on compaction',
    group: 'Safety & honesty',
    sourceRef: 'hooks/session-start.sh',
    detail:
      'SessionStart hook that re-injects the kernel on startup, clear, and compact — without it the brain is read once and fades as the context fills. Verified on Claude Code; wired for Cursor.',
  },
  {
    id: 'installtests',
    label: 'Installer tests',
    kind: 'service',
    sub: 'guards the install promises',
    group: 'Safety & honesty',
    sourceRef: 'tests/install.test.sh',
    detail:
      "Guards the promises install.sh makes: never destroy your files, never lose a MasterMind capability, stay idempotent, merge settings instead of clobbering, and leave an unparseable config alone.",
  },
  {
    id: 'field',
    label: 'Field pack',
    kind: 'store',
    sub: 'built per project from the template',
    group: 'Knowledge',
    sourceRef: 'engineering/fields/_template/',
    detail:
      'A swappable domain pack: what to know and which tools, for one real stack. No field ships — on the first task `init` detects the stack and builds the pack from the template; the project owns it.',
  },
  {
    id: 'library',
    label: 'Library pages',
    kind: 'service',
    sub: 'docs generated from source',
    group: 'Safety & honesty',
    sourceRef: 'scripts/build-library.mjs',
    detail:
      'Generates one article per skill and agent from ABOUT.md files, so public docs cannot claim what a skill does not do. Refuses to build without an article; --check fails when the site is stale.',
  },
  {
    id: 'moreskills',
    label: 'more skills',
    kind: 'tool',
    sub: 'route·interview·learn·explain·…',
    group: 'Library',
  },
  {
    id: 'secretguards',
    label: 'Secret guards',
    kind: 'service',
    sub: 'pre-commit + pre-push',
    group: 'Safety & honesty',
    sourceRef: '.githooks/pre-push',
    detail:
      'Always-on credential patterns plus a quarantine rule, identical in the hooks this repo runs and the ones it ships. Blocks tokens and lab/ files at commit and at push, denylist or not.',
  },
  {
    id: 'autoinvoke',
    label: 'Auto-invoke eval',
    kind: 'service',
    sub: 'does the right skill fire?',
    group: 'Safety & honesty',
    sourceRef: 'evals/auto-invoke.mjs',
    detail:
      'Live sessions on a seeded repo, measuring which skill actually fires from natural language. Separates harness failure from routing failure, and CROWDED=1 adds foreign skill packs.',
  },
  {
    id: 'wronglog',
    label: 'Wrong-log',
    kind: 'store',
    sub: 'misses, with the catcher named',
    group: 'Safety & honesty',
    sourceRef: 'journal.md',
    detail:
      'Every falsified claim, recorded with what caught it — a test, a reviewer, the user, a measurement. Read back with `mastermind wrong-log`; levelup distils it. Self-graded entries do not count.',
  },
  {
    id: 'crossos',
    label: 'Cross-OS CI',
    kind: 'service',
    sub: 'Linux · macOS · Windows · WSL · Alpine',
    group: 'Safety & honesty',
    sourceRef: '.github/workflows/cross-os.yml',
    detail:
      'Runs source and packed-package installs on Linux and macOS, asserts native Windows refuses clearly, and completes real installs in WSL and Alpine.',
  },
]

const NEW_EDGES = [
  { from: 'cli', to: 'install', kind: 'triggers', label: 'drives the engine' },
  { from: 'install', to: 'cursor', kind: 'writes', label: '.cursor/rules (kernel)' },
  { from: 'install', to: 'codex', kind: 'writes', label: 'AGENTS.md → the brain' },
  { from: 'cursor', to: 'kernel', kind: 'reads' },
  { from: 'codex', to: 'kernel', kind: 'reads' },
  { from: 'install', to: 'bootstrap', kind: 'writes', label: 'registers the hook' },
  { from: 'bootstrap', to: 'kernel', kind: 'writes', label: 're-injects the brain' },
  { from: 'installtests', to: 'install', kind: 'reads', label: 'verifies' },
  { from: 'library', to: 'kernel', kind: 'reads', label: 'a page per skill + agent' },
  { from: 'ci', to: 'installtests', kind: 'triggers' },
  { from: 'ci', to: 'library', kind: 'triggers', label: 'checks docs are in sync' },
  { from: 'ci', to: 'integrity', kind: 'triggers' },
  { from: 'ci', to: 'crossos', kind: 'triggers', label: '5-platform matrix' },
  { from: 'cli', to: 'wronglog', kind: 'reads', label: 'wrong-log' },
  { from: 'levelup', to: 'wronglog', kind: 'reads', label: 'distils the misses' },
  { from: 'autoinvoke', to: 'install', kind: 'triggers', label: 'installs, then asks' },
  { from: 'secretguards', to: 'lab', kind: 'reads', label: 'never let it out' },
]

const DEAD_NODES = ['designdb', 'designtests', 'copilot', 'gemini'] // tool scope is Claude Code · Cursor · Codex since 0.27

const byId = (arr, id) => arr.findIndex((n) => n.id === id)
for (const n of NEW_NODES) {
  const i = byId(g.nodes, n.id)
  if (i >= 0) g.nodes[i] = n
  else g.nodes.push(n)
}
const DEAD_EDGES = [
  'library->moreskills', // implied only the catch-all group fed the docs; it reads every skill + agent
  'field->designdb', // the design DB was removed with the frontend pack (0.27.0)
  'designdb->designtests',
]

// Drop retired nodes, then any edge that would dangle to one of them.
g.nodes = g.nodes.filter((n) => !DEAD_NODES.includes(n.id))
const dead = new Set(DEAD_NODES)

const key = (e) => `${e.from}->${e.to}`
g.edges = g.edges.filter((e) => !DEAD_EDGES.includes(key(e)) && !dead.has(e.from) && !dead.has(e.to))
for (const e of NEW_EDGES) {
  const i = g.edges.findIndex((x) => key(x) === key(e))
  if (i >= 0) g.edges[i] = e
  else g.edges.push(e)
}

for (const t of ['cursor']) {
  const i = byId(g.nodes, t)
  if (i >= 0) g.nodes[i].sub = 'kernel + bootstrap hook'
}

d.version = 1
d.stats = {
  ...d.stats,
  agents: count('agents', (e) => e.isFile() && e.name.endsWith('.md')),
  tools: count('skills', (e) => e.isDirectory()),
  integrations: (d.topIntegrations ?? []).length,
}

const bad = []
if (d.version !== 1) bad.push('version must be the literal 1')
for (const n of g.nodes) {
  if (n.detail && n.detail.length > 200) bad.push(`node ${n.id}: detail ${n.detail.length} > 200 chars`)
  if (n.sub && n.sub.length > 40) bad.push(`node ${n.id}: sub ${n.sub.length} > 40 chars`)
  if (n.label && n.label.length > 40) bad.push(`node ${n.id}: label ${n.label.length} > 40 chars`)
  if (n.group === '') bad.push(`node ${n.id}: empty group — omit the key instead`)
}
for (const e of g.edges)
  if (e.label && e.label.length > 24) bad.push(`edge ${key(e)}: label ${e.label.length} > 24 chars`)
for (const n of g.nodes)
  if (n.sourceRef && !existsSync(join(ROOT, n.sourceRef)))
    bad.push(`node ${n.id}: sourceRef "${n.sourceRef}" does not exist`)
const skillNames = new Set(readdirSync(join(ROOT, 'skills'), { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name))
for (const t of d.topTools ?? [])
  if (!skillNames.has(t.id)) bad.push(`topTools lists "${t.id}", which is not a skill on disk`)

const WIRED = new Set(['claudecode', 'codex', 'cursor', 'github'])
for (const t of d.topIntegrations ?? [])
  if (!WIRED.has(t.id)) bad.push(`topIntegrations lists "${t.id}", which this version does not wire`)

const ids = new Set(g.nodes.map((n) => n.id))
for (const e of g.edges)
  if (!ids.has(e.from) || !ids.has(e.to)) bad.push(`edge ${key(e)}: points at a node that is not on the map`)
if (bad.length) {
  console.error('✗ foglamp contract violated:\n  ' + bad.join('\n  '))
  process.exit(1)
}

writeFileSync(P, JSON.stringify(d, null, 2) + '\n')
console.log(`✓ scan.json → ${g.nodes.length} nodes, ${g.edges.length} edges`)
