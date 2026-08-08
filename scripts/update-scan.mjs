// Refresh .foglamp/scan.json — the architecture map published on every push. Idempotent:
// re-running replaces the same nodes/edges by id rather than duplicating them.
//
// Counts are read from the repo, never written here: this file publishes a public map, so
// a stale literal would ship a lie on the first skill added after a release. (`version` is
// the API's schema version, not the repo's — see the bottom.)
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join, resolve } from 'node:path'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const P = join(ROOT, '.foglamp', 'scan.json')
const count = (dir, pred) => readdirSync(join(ROOT, dir), { withFileTypes: true }).filter(pred).length

// NO COUNTS IN NODE LABELS. This map is published publicly and a stale number is a public
// lie: it shipped "30 assertions" while the suite had 37. Deriving them statically proved
// fragile too (assertions fire inside loops; checks are numbered "2 & 3"), and this script
// must not run the test suites to find out. A structure map's job is what connects to what
// — the exact totals live in the suites themselves, which cannot go stale.

const d = JSON.parse(readFileSync(P, 'utf8'))
const g = d.graph

const NEW_NODES = [
  // No group key: entry points (claude, cursor, codex) float ungrouped, and the API rejects
  // an empty-string group outright.
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
    // No field ships pre-baked (0.27.0): only the scaffold. `init` builds the field for the
    // project's real stack. So this node is the *concept* of a field pack, anchored at the
    // template — not a shipped frontend pack, which no longer exists in the repo.
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
  // The catch-all for skills without their own node. Its label MUST stay count-free —
  // this map is published publicly, and a hardcoded "+11 more skills" is exactly the
  // stale-number lie the header forbids (it shipped "+11" while the library held 12).
  {
    id: 'moreskills',
    label: 'more skills',
    kind: 'tool',
    sub: 'route·interview·learn·explain·prototype·…',
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
    sub: 'linux · windows guard · alpine',
    group: 'Safety & honesty',
    sourceRef: '.github/workflows/cross-os.yml',
    detail:
      'Runs the install and the lookup surface on Linux, asserts native Windows refuses with the WSL pointer, and checks the Alpine no-bash guard then a full install once bash exists.',
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
  // build-library.mjs reads EVERY skill's ABOUT.md and every agents/about/*.md — not the
  // `moreskills` catch-all, which is only a display grouping for the skills without their
  // own node. Pointing the edge at it implied the other skills' docs come from somewhere else.
  { from: 'library', to: 'kernel', kind: 'reads', label: 'a page per skill + agent' },
  { from: 'ci', to: 'installtests', kind: 'triggers' },
  { from: 'ci', to: 'library', kind: 'triggers', label: 'checks docs are in sync' },
  { from: 'ci', to: 'integrity', kind: 'triggers' },
  { from: 'ci', to: 'crossos', kind: 'triggers', label: 'linux · win · alpine' },
  { from: 'cli', to: 'wronglog', kind: 'reads', label: 'wrong-log' },
  { from: 'levelup', to: 'wronglog', kind: 'reads', label: 'distils the misses' },
  { from: 'autoinvoke', to: 'install', kind: 'triggers', label: 'installs, then asks' },
  { from: 'secretguards', to: 'lab', kind: 'reads', label: 'never let it out' },
]

// Nodes retired from the map. The vendored design database and its test suite lived inside the
// frontend pack, which 0.27.0 removed from the repo (a project builds its own field from the
// template). They persist in the committed scan.json from earlier runs, so prune them by id.
const DEAD_NODES = ['designdb', 'designtests', 'copilot', 'gemini'] // tool scope is Claude Code · Cursor · Codex since 0.27

const byId = (arr, id) => arr.findIndex((n) => n.id === id)
for (const n of NEW_NODES) {
  const i = byId(g.nodes, n.id)
  if (i >= 0) g.nodes[i] = n
  else g.nodes.push(n)
}
// Edges that were wrong and must be pruned. Nodes get replaced by id, but edges are only
// ever appended — so a corrected edge would leave both the right and wrong one in the map.
// Prune first, then add.
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
// Replace by key, like nodes — append-only meant a corrected label never reached the
// committed scan.json.
for (const e of NEW_EDGES) {
  const i = g.edges.findIndex((x) => key(x) === key(e))
  if (i >= 0) g.edges[i] = e
  else g.edges.push(e)
}

for (const t of ['cursor']) {
  const i = byId(g.nodes, t)
  if (i >= 0) g.nodes[i].sub = 'kernel + bootstrap hook'
}

// `version` is foglamp's SCHEMA version — the API requires the literal 1. Writing the repo
// version here broke every republish for weeks while CI reported green.
d.version = 1
d.stats = {
  ...d.stats,
  agents: count('agents', (e) => e.isFile() && e.name.endsWith('.md')),
  tools: count('skills', (e) => e.isDirectory()),
}

// The API's contract, enforced here so preflight fails loudly instead of CI publishing
// nothing: version === 1, node detail ≤ 200 chars, no empty group, edge label ≤ 24 chars.
const bad = []
if (d.version !== 1) bad.push('version must be the literal 1')
for (const n of g.nodes) {
  if (n.detail && n.detail.length > 200) bad.push(`node ${n.id}: detail ${n.detail.length} > 200 chars`)
  if (n.group === '') bad.push(`node ${n.id}: empty group — omit the key instead`)
}
for (const e of g.edges)
  if (e.label && e.label.length > 24) bad.push(`edge ${key(e)}: label ${e.label.length} > 24 chars`)
// A node whose sourceRef does not exist is a dead link on a published map — `lab/` shipped
// like that, pointing at a folder that only exists inside a user's project.
for (const n of g.nodes)
  if (n.sourceRef && !existsSync(join(ROOT, n.sourceRef)))
    bad.push(`node ${n.id}: sourceRef "${n.sourceRef}" does not exist`)
const ids = new Set(g.nodes.map((n) => n.id))
for (const e of g.edges)
  if (!ids.has(e.from) || !ids.has(e.to)) bad.push(`edge ${key(e)}: points at a node that is not on the map`)
if (bad.length) {
  console.error('✗ foglamp contract violated:\n  ' + bad.join('\n  '))
  process.exit(1)
}

writeFileSync(P, JSON.stringify(d, null, 2) + '\n')
console.log(`✓ scan.json → ${g.nodes.length} nodes, ${g.edges.length} edges`)
