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
    sub: '30 assertions',
    group: 'Safety & honesty',
    sourceRef: 'tests/install.test.sh',
    detail:
      "Guards the promises install.sh makes: never destroy your files, never lose a MasterMind capability, stay idempotent, merge settings instead of clobbering, and leave an unparseable config alone.",
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
]

const NEW_EDGES = [
  { from: 'install', to: 'bootstrap', kind: 'writes', label: 'registers the hook' },
  { from: 'bootstrap', to: 'kernel', kind: 'writes', label: 're-injects the brain' },
  { from: 'installtests', to: 'install', kind: 'reads', label: 'verifies' },
  { from: 'library', to: 'moreskills', kind: 'reads', label: 'generates docs from' },
  { from: 'ci', to: 'installtests', kind: 'triggers' },
  { from: 'ci', to: 'library', kind: 'triggers', label: 'checks docs are in sync' },
]

const byId = (arr, id) => arr.findIndex((n) => n.id === id)
for (const n of NEW_NODES) {
  const i = byId(g.nodes, n.id)
  if (i >= 0) g.nodes[i] = n
  else g.nodes.push(n)
}
const key = (e) => `${e.from}->${e.to}`
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
