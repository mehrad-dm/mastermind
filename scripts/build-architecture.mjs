#!/usr/bin/env node

// Writes architecture.json, the data behind the site's diagrams. The texts are hand-written in
// scripts/architecture.source.json; everything else is read from the repo and from a real install.

import { readFileSync, writeFileSync, readdirSync, existsSync, mkdtempSync, mkdirSync, rmSync, cpSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const SITE = process.env.MASTERMIND_SITE ? resolve(process.env.MASTERMIND_SITE) : resolve(ROOT, '..', 'mastermind-site')
const OUT = join(ROOT, 'architecture.json')
const SITE_OUT = join(SITE, 'src', 'data', 'architecture.json')
const SOURCE = join(ROOT, 'scripts', 'architecture.source.json')
const FIXTURES = join(ROOT, 'scripts', 'fixtures', 'architecture.json')
const LIMITS = { label: 32, sub: 40, detail: 160 }
const COUNTED = { skills: 'skills', skill: 'skills', workflows: 'skills', agents: 'agents', subagents: 'agents', roles: 'agents' }
const TYPED_COUNT = /\b\d+ (?:[a-z-]+ )?(?:skills?|workflows|agents|subagents|roles)\b/
const EM_DASH = String.fromCharCode(0x2014)

const read = (rel) => readFileSync(join(ROOT, rel), 'utf8')
const ls = (dir, pred) => readdirSync(join(ROOT, dir), { withFileTypes: true }).filter(pred).map((e) => e.name).sort()
const docs = (dir) => ls(dir, (e) => e.isFile() && e.name.endsWith('.md')).map((n) => n.replace(/\.md$/, ''))

function repoFacts() {
  const skills = ls('skills', (e) => e.isDirectory() && existsSync(join(ROOT, 'skills', e.name, 'SKILL.md')))
  const menu = read('CLAUDE.md').match(/\*\*spec-driven, in order\*\*:([\s\S]*?)\n- \*\*/)
  const specOrder = menu ? [...menu[1].matchAll(/`([a-z-]+)`/g)].map((m) => m[1]) : []
  const readme = read('README.md')
  const spec = []
  let seen = false
  for (const line of readme.slice(readme.indexOf('## Spec-driven')).split('\n')) {
    if (!line.startsWith('|')) { if (seen) break; continue }
    seen = true
    const cells = line.split('|').map((c) => c.trim()).filter(Boolean)
    if (cells.length !== 3 || cells[0] === 'Step' || cells[0].startsWith('---')) continue
    const names = [...cells[1].matchAll(/`([a-z-]+)`/g)].map((m) => m[1])
    if (!specOrder.includes(names[0])) continue
    spec.push({ question: cells[0], skills: names, writes: cells[2].replace(/`|\*\*/g, '') })
  }
  // The same set build-library.mjs writes a page for.
  const wanted = [...skills, ...docs('library/agents')].sort()
  const dir = join(SITE, 'src', 'pages', 'library')
  const onSite = existsSync(dir) ? readdirSync(dir).filter((f) => f.endsWith('.md')).map((f) => f.replace(/\.md$/, '')).sort() : null
  return {
    repo: JSON.parse(read('.claude-plugin/plugin.json')).repository.replace(/^https:\/\/github\.com\//, ''),
    release: read('VERSION').trim(),
    lists: { skill: skills, agent: docs('agents'), core: docs('engineering/core'), field: docs('engineering/fields/_template'),
      mod: ls('mod/hooks', (e) => e.isFile() && e.name.endsWith('.mjs')).map((n) => n.replace(/\.mjs$/, '')) },
    specOrder, spec,
    pages: new Set(wanted),
    pageDrift: onSite && onSite.join() !== wanted.join()
      ? [...wanted.filter((n) => !onSite.includes(n)), ...onSite.filter((n) => !wanted.includes(n))] : [],
    exists: (rel) => existsSync(join(ROOT, rel)),
  }
}

function walk(dir, rel = '') {
  const out = []
  for (const e of readdirSync(join(dir, rel), { withFileTypes: true })) {
    const path = rel ? `${rel}/${e.name}` : e.name
    if (path === '.git') continue
    out.push({ path, dir: e.isDirectory(), text: e.isFile() && e.name.endsWith('.json') ? readFileSync(join(dir, path), 'utf8') : '' })
    if (e.isDirectory() && path !== '.mastermind') out.push(...walk(dir, path))
  }
  return out
}

// One install per tool into an empty project, the brain being a copy of this tree under a scratch HOME.
function installFacts(tools) {
  const scratch = mkdtempSync(join(tmpdir(), 'mm-arch-'))
  try {
    const home = join(scratch, 'home'), brain = join(home, '.mastermind')
    const skip = /\/(\.git|node_modules|evals|\.claude|private|lab)(\/|$)/
    cpSync(ROOT, brain, { recursive: true, verbatimSymlinks: true, filter: (src) => !skip.test(src.slice(ROOT.length)) })
    const env = { ...process.env, HOME: home, MM_NO_NETWORK: '1' }
    for (const k of ['MASTERMIND_HOME', 'CLAUDE_PLUGIN_ROOT', 'CLAUDE_PROJECT_DIR', 'CURSOR_PLUGIN_ROOT']) delete env[k]
    const written = {}
    for (const tool of tools) {
      const proj = join(scratch, `proj-${tool}`)
      mkdirSync(proj)
      spawnSync('git', ['init', '-q', '.'], { cwd: proj, env })
      const r = spawnSync('bash', [join(brain, 'install.sh'), tool], { cwd: proj, env, encoding: 'utf8', timeout: 300000 })
      if (r.status !== 0) throw new Error(`install.sh ${tool} exited ${r.status} in a scratch project: ${`${r.stdout}${r.stderr}`.trim().split('\n').pop()}`)
      written[tool] = walk(proj)
    }
    return written
  } finally {
    rmSync(scratch, { recursive: true, force: true })
  }
}

function build(source, facts) {
  const errors = []
  const counts = { skills: facts.lists.skill.length, agents: facts.lists.agent.length, core: facts.lists.core.length }
  const text = (where, raw) => {
    if (typeof raw !== 'string' || !raw) { errors.push(`${where} is empty`); return '' }
    if (raw.includes(EM_DASH)) errors.push(`${where} contains an em dash`)
    const typed = raw.match(TYPED_COUNT)
    if (typed) {
      const word = typed[0].split(' ').pop()
      errors.push(`${where} types a count ("${typed[0]}"): write {${COUNTED[word]}} so it follows the repo`)
    }
    return raw.replace(/\{(\w+)\}/g, (m, k) => {
      if (k in counts) return counts[k]
      errors.push(`${where} uses ${m}, which is not a count this script derives`)
      return m
    })
  }

  const nodes = {}
  for (const [id, n] of Object.entries(source.nodes ?? {})) {
    const node = { label: text(`node "${id}" label`, n.label), sub: text(`node "${id}" sub`, n.sub) }
    if (n.ref !== undefined) {
      node.ref = n.ref
      if (!facts.exists(n.ref)) errors.push(`node "${id}": ref "${n.ref}" does not exist in the repo`)
    }
    node.detail = text(`node "${id}" detail`, n.detail)
    for (const [key, max] of Object.entries(LIMITS)) {
      const len = [...node[key]].length
      if (len > max) errors.push(`node "${id}": ${key} is ${len} characters, over the ${max} limit`)
    }
    nodes[id] = node
  }
  const used = new Set()
  const use = (id, where) => {
    used.add(id)
    if (!nodes[id]) errors.push(`${where} names "${id}", which is not a node`)
    return id
  }
  const head = (id, kind) => ({ id, kind, title: text(`${id} title`, source[id]?.title), summary: text(`${id} summary`, source[id]?.summary) })

  const flow = { ...head('flow', 'flow'), steps: (source.flow?.steps ?? []).map((step, i, all) => {
    const out = { nodes: step.nodes.map((id) => use(id, 'flow step')) }
    if (step.join) out.join = step.join
    if (step.back) {
      out.back = { to: use(step.back.to, 'flow back edge'), label: text('flow back edge label', step.back.label) }
      if (!all[i - 1]?.nodes.includes(step.back.to)) errors.push(`flow: the back edge to "${step.back.to}" must point at the step directly before it`)
    }
    return out
  }) }

  const target = source.install?.target ?? {}
  const install = { ...head('install', 'fanin'), sources: (source.install?.sources ?? []).map((s) => {
    const wrote = facts.install[s.tool] ?? []
    const has = (path) => wrote.find((w) => w.path === path)
    if (!wrote.length) errors.push(`install: nothing was installed for the tool "${s.tool}"`)
    else if (!has(target.path)) errors.push(`install: \`install.sh ${s.tool}\` did not write ${target.path}, the target of the diagram`)
    for (const p of s.parts) {
      const found = has(p.path)
      if (!found) { errors.push(`install: part "${p.node}" stands for ${p.path}, which \`install.sh ${s.tool}\` did not write`); continue }
      if (p.contains && !found.text.includes(p.contains)) errors.push(`install: ${p.path} was written without "${p.contains}", so part "${p.node}" is not there`)
      if (p.holds) {
        const inside = wrote.filter((w) => w.path.startsWith(`${p.path}/`) && !w.path.slice(p.path.length + 1).includes('/')).length
        if (inside !== counts[p.holds]) errors.push(`install: ${p.path} holds ${inside} entries after \`install.sh ${s.tool}\`, the repo has ${counts[p.holds]} ${p.holds}`)
      }
    }
    const units = wrote.filter((w) => w.path !== target.path && (w.path.split('/').length === 2 || (!w.dir && !w.path.includes('/')))).map((w) => w.path)
    const listed = (unit) => s.parts.some((p) => p.path === unit || p.path.startsWith(`${unit}/`))
    for (const unit of units) {
      if (!listed(unit) && !(s.unlisted ?? []).includes(unit)) errors.push(`install: \`install.sh ${s.tool}\` wrote ${unit}, which is on no part: add a part, or name it under "unlisted"`)
    }
    for (const gone of (s.unlisted ?? []).filter((u) => !units.includes(u))) errors.push(`install: "unlisted" names ${gone}, which \`install.sh ${s.tool}\` no longer writes`)
    return { node: use(s.node, 'install'), parts: s.parts.map((p) => use(p.node, 'install')) }
  }), target: use(target.node, 'install target') }

  const layers = { ...head('layers', 'layers'), layers: (source.layers?.layers ?? []).map((l) => {
    const out = { node: use(l.node, 'layers'), load: text(`layer "${l.node}" load`, l.load) }
    if (l.items === undefined) return out
    const names = facts.lists[l.items]
    if (!names?.length) { errors.push(`layers: "${l.node}" lists "${l.items}", and the repo has none`); return out }
    const linked = l.items === 'skill' || l.items === 'agent'
    out.items = names.map((name) => (linked && facts.pages.has(name) ? { name, href: `/library/${name}`, kind: l.items } : { name, kind: l.items }))
    return out
  }) }

  const spec = { ...head('spec', 'pipeline'), steps: facts.spec.map((s) => ({ question: text('spec question', s.question), skills: s.skills, writes: text('spec writes', s.writes) })) }
  if (!facts.specOrder.length) errors.push('spec: CLAUDE.md has no "spec-driven, in order" menu to take the steps from')
  if (facts.spec.map((s) => s.skills[0]).join() !== facts.specOrder.join()) {
    errors.push(`spec: the README table gives ${facts.spec.map((s) => s.skills[0]).join(', ') || 'no steps'}; the kernel menu gives ${facts.specOrder.join(', ')}`)
  }
  for (const s of facts.spec) for (const name of s.skills) {
    if (!facts.pages.has(name)) errors.push(`spec: the step "${s.question}" names "${name}", which has no library page`)
  }

  for (const id of Object.keys(nodes)) if (!used.has(id)) errors.push(`node "${id}" is on no diagram`)
  if (facts.pageDrift.length) errors.push(`the site's library pages differ from the repo (${facts.pageDrift.join(', ')}): run scripts/build-library.mjs first`)

  const data = { version: 2, source: { repo: facts.repo, release: facts.release }, counts, nodes, diagrams: [flow, install, layers, spec] }
  return { data, errors }
}

// An install record that satisfies the source as written, so a fixture can break one thing at a time.
function installStub(source, facts) {
  const size = { skills: facts.lists.skill.length, agents: facts.lists.agent.length }
  const out = {}
  for (const s of source.install.sources) {
    const paths = new Map([[source.install.target.path, { dir: true, text: '' }]])
    const add = (path, dir, text = '') => {
      const parts = path.split('/')
      for (let i = 1; i < parts.length; i++) paths.set(parts.slice(0, i).join('/'), { dir: true, text: '' })
      paths.set(path, { dir, text })
    }
    for (const p of s.parts) {
      add(p.path, Boolean(p.holds), p.contains ?? '')
      for (let i = 0; i < (size[p.holds] ?? 0); i++) add(`${p.path}/${i}`, false)
    }
    for (const u of s.unlisted ?? []) add(u, true)
    out[s.tool] = [...paths].map(([path, v]) => ({ path, ...v }))
  }
  return out
}

function selfTest() {
  const real = JSON.parse(readFileSync(SOURCE, 'utf8'))
  const base = { ...repoFacts(), pageDrift: [] }
  const { fires, clean } = JSON.parse(readFileSync(FIXTURES, 'utf8'))
  const wrong = []
  const run = (fx) => {
    const source = structuredClone(real)
    for (const [path, value] of fx.set ?? []) {
      const keys = path.split('.')
      const last = keys.pop()
      keys.reduce((o, k) => o[k], source)[last] = value
    }
    const facts = { ...base, install: installStub(source, base) }
    for (const [tool, path] of fx.unwrite ?? []) facts.install[tool] = facts.install[tool].filter((w) => w.path !== path && !w.path.startsWith(`${path}/`))
    for (const [tool, path] of fx.write ?? []) facts.install[tool].push({ path, dir: false, text: '' })
    return build(source, facts).errors
  }
  for (const fx of fires) {
    const errors = run(fx)
    if (!errors.some((e) => e.includes(fx.expect))) wrong.push(`"${fx.name}" did not fail with "${fx.expect}" (got: ${errors.join(' | ') || 'no error'})`)
  }
  for (const fx of clean) {
    const errors = run(fx)
    if (errors.length) wrong.push(`"${fx.name}" should be clean: ${errors.join(' | ')}`)
  }
  if (wrong.length) { console.error('✖ architecture self-test:\n  ' + wrong.join('\n  ')); process.exit(1) }
  console.log(`✓ architecture self-test: ${fires.length} bad inputs fire, ${clean.length} good inputs stay clean.`)
}

function main() {
  const source = JSON.parse(readFileSync(SOURCE, 'utf8'))
  const facts = repoFacts()
  try { facts.install = installFacts(source.install.sources.map((s) => s.tool)) }
  catch (e) { console.error(`✖ architecture: ${e.message}`); process.exit(1) }
  const { data, errors } = build(source, facts)
  if (errors.length) { console.error('✖ architecture data cannot be generated:\n  ' + errors.join('\n  ')); process.exit(1) }
  const json = JSON.stringify(data, null, 2) + '\n'
  const same = (file) => existsSync(file) && readFileSync(file, 'utf8') === json
  const site = existsSync(SITE)
  const shape = `${Object.keys(data.nodes).length} nodes, ${data.diagrams.length} diagrams`

  if (process.argv.includes('--check')) {
    const stale = [[OUT, 'architecture.json'], ...(site ? [[SITE_OUT, 'the site copy (src/data/architecture.json)']] : [])].filter(([file]) => !same(file))
    if (stale.length) {
      console.error(`✖ architecture data is stale: ${stale.map(([, name]) => name).join(' and ')}. Run: node scripts/build-architecture.mjs`)
      process.exit(1)
    }
    if (!site) { console.log(`· architecture.json matches the repo (${shape}); site not checked: ${SITE} is not checked out`); process.exit(2) }
    console.log(`✓ architecture data matches the repo, here and on the site: ${shape}`)
    return
  }
  if (!site && process.env.MASTERMIND_SITE) { console.error(`✖ ${SITE} is not checked out: nothing to write there.`); process.exit(1) }
  writeFileSync(OUT, json)
  if (site) {
    mkdirSync(dirname(SITE_OUT), { recursive: true })
    writeFileSync(SITE_OUT, json)
  }
  console.log(`✓ wrote architecture.json${site ? ' and the site copy' : ' (site not checked out, so its copy was not written)'}: ${shape}, ${data.counts.skills} skills, ${data.counts.agents} agents`)
}

if (process.argv.includes('--self-test')) selfTest()
else main()
