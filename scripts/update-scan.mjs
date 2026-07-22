// Refresh .foglamp/scan.json — the architecture map published on every push. Idempotent:
// re-running replaces the same nodes/edges by id rather than duplicating them.
//
// Version and counts are read from the repo, never written here: this file publishes a
// public map, so a stale literal would ship a lie on the first skill added after a release.
import { readFileSync, writeFileSync, readdirSync } from 'node:fs'
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
  {
    id: 'bootstrap',
    label: 'Bootstrap hook',
    kind: 'service',
    sub: 're-injects on compaction',
    group: 'Safety & honesty',
    sourceRef: 'hooks/session-start.sh',
    detail:
      'SessionStart hook that re-injects the kernel on startup, clear, and compact. Without it the brain is read once and fades as the window fills, so long sessions silently run without MasterMind. Verified on Claude Code; wired for Cursor and Copilot CLI.',
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
    id: 'designdb',
    label: 'Design database',
    kind: 'store',
    sub: 'vendored · UI/UX intelligence',
    group: 'Knowledge',
    sourceRef: 'engineering/fields/frontend/ui-ux-pro-max/',
    detail:
      'A vendored third-party design-intelligence database (MIT, NextLevelBuilder) behind the frontend pack: colour palettes, font pairings, UX guidelines, product types and chart types, plus per-stack guidance, searched by a local BM25 engine. Not authored here — SOURCE.md records the upstream, the re-vendor procedure, and the local fixes that must survive it.',
  },
  {
    id: 'designtests',
    label: 'Design engine tests',
    kind: 'service',
    sub: 'characterization suite',
    group: 'Safety & honesty',
    sourceRef: 'engineering/fields/frontend/ui-ux-pro-max/scripts/tests/',
    detail:
      'Pins what the vendored selection logic actually does — dial clamping, determinism, no-match paths, and that persistence writes only under its output dir — so a re-vendor cannot silently change behaviour. Written against code that had no tests; it found a path traversal and two selection bugs, all since fixed and pinned.',
  },
  {
    id: 'library',
    label: 'Library pages',
    kind: 'service',
    sub: 'docs generated from source',
    group: 'Safety & honesty',
    sourceRef: 'scripts/build-library.mjs',
    detail:
      'Generates one article per skill and agent from ABOUT.md files, so the public docs cannot claim a skill does something the skill does not. Refuses to build if a skill has no article; --check fails when the site is stale.',
  },
  // The catch-all for skills without their own node. Its label MUST stay count-free —
  // this map is published publicly, and a hardcoded "+11 more skills" is exactly the
  // stale-number lie the header forbids (it shipped "+11" while the library held 12).
  {
    id: 'moreskills',
    label: 'more skills',
    kind: 'tool',
    sub: 'route·spec·learn·explain·spike·…',
    group: 'Library',
  },
]

const NEW_EDGES = [
  { from: 'install', to: 'bootstrap', kind: 'writes', label: 'registers the hook' },
  { from: 'bootstrap', to: 'kernel', kind: 'writes', label: 're-injects the brain' },
  { from: 'installtests', to: 'install', kind: 'reads', label: 'verifies' },
  // build-library.mjs reads EVERY skill's ABOUT.md and every agents/about/*.md — not the
  // `moreskills` catch-all, which is only a display grouping for the skills without their
  // own node. Pointing the edge at it implied the other skills' docs come from somewhere else.
  { from: 'library', to: 'kernel', kind: 'reads', label: 'one page per skill + agent' },
  { from: 'ci', to: 'installtests', kind: 'triggers' },
  { from: 'ci', to: 'library', kind: 'triggers', label: 'checks docs are in sync' },
  // The design database is vendored, is the largest single component in the repo, and had
  // no node at all — the map showed a field pack with nothing inside it.
  { from: 'field', to: 'designdb', kind: 'reads', label: 'design intelligence' },
  { from: 'designdb', to: 'designtests', kind: 'reads', label: 'pinned by' },
  { from: 'ci', to: 'integrity', kind: 'triggers' },
]

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
]

const key = (e) => `${e.from}->${e.to}`
g.edges = g.edges.filter((e) => !DEAD_EDGES.includes(key(e)))
const have = new Set(g.edges.map(key))
for (const e of NEW_EDGES) if (!have.has(key(e))) g.edges.push(e)

// Cursor and Copilot now get the bootstrap too — reflect that they're first-class.
for (const t of ['cursor', 'copilot']) {
  const i = byId(g.nodes, t)
  if (i >= 0) g.nodes[i].sub = 'kernel + bootstrap hook'
}

d.version = readFileSync(join(ROOT, 'VERSION'), 'utf8').trim()
d.stats = {
  ...d.stats,
  agents: count('agents', (e) => e.isFile() && e.name.endsWith('.md')),
  tools: count('skills', (e) => e.isDirectory()),
}

writeFileSync(P, JSON.stringify(d, null, 2) + '\n')
console.log(`✓ scan.json → ${g.nodes.length} nodes, ${g.edges.length} edges (v${d.version})`)
