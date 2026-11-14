#!/usr/bin/env node

// Statements in the docs that a user relies on, each paired with a test a machine can run.
// A row fires when its statement is present and its test fails. A row whose statement is gone
// fails too when the row is marked `must`, so rewording a claim cannot retire its test unseen.
// Exit 1: a claim is false. Exit 2: nothing false, but a test could not run here.

import { readFileSync, readdirSync, existsSync, mkdtempSync, mkdirSync, writeFileSync, rmSync, cpSync, symlinkSync, statSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { tmpdir } from 'node:os'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const arg = (name) => { const i = process.argv.indexOf(name); return i > 0 ? process.argv[i + 1] : null }
const ROOT = arg('--root') ? resolve(arg('--root')) : HERE
const FAST = process.argv.includes('--fast')
const ONLY = arg('--only') ? arg('--only').split(',') : null
const HOOK_CAP = 10000
// Codex cuts hook context at roughly 2,500 tokens and gives no character figure.
const CODEX_HOOK_CAP = 9000
const KERNEL_BLOCK = /<!-- MASTERMIND:KERNEL:START -->\n[^\n]*\n([\s\S]*?)\n<!-- MASTERMIND:KERNEL:END -->\n/

const read = (rel) => (existsSync(join(ROOT, rel)) ? readFileSync(join(ROOT, rel), 'utf8') : '')
const names = (dir, pred) => readdirSync(join(ROOT, dir), { withFileTypes: true }).filter(pred).map((e) => e.name)
const skills = () => names('skills', (e) => e.isDirectory())
const agents = () => names('agents', (e) => e.isFile() && e.name.endsWith('.md')).map((n) => n.replace(/\.md$/, ''))
const workflows = () => names('.github/workflows', (e) => /\.ya?ml$/.test(e.name)).map((n) => [n, read(`.github/workflows/${n}`)])

const SKIP = (why) => ({ skip: why })
const scratch = mkdtempSync(join(tmpdir(), 'mm-claims-'))
process.on('exit', () => rmSync(scratch, { recursive: true, force: true }))
const home = join(scratch, 'home')
mkdirSync(home)
const env = { ...process.env, HOME: home, MM_NO_NETWORK: '1', MASTERMIND_HOME: ROOT }
for (const k of ['CLAUDE_PLUGIN_ROOT', 'CLAUDE_PROJECT_DIR', 'CURSOR_PLUGIN_ROOT', 'COPILOT_CLI']) delete env[k]
const sh = (cmd, args, opts = {}) => {
  const r = spawnSync(cmd, args, { encoding: 'utf8', maxBuffer: 32 << 20, timeout: 300000, env, ...opts })
  return { code: r.status ?? 1, out: `${r.stdout ?? ''}${r.stderr ?? ''}`, stdout: r.stdout ?? '', missing: r.error?.code === 'ENOENT' }
}
const emptyDir = (name) => { const d = join(scratch, name); mkdirSync(d, { recursive: true }); return d }

function hookPayloads() {
  const hook = join(ROOT, 'hooks', 'session-start.sh')
  const proj = emptyDir('hook-proj')
  const runs = [['claude', {}], ['cursor', {}], ['sdk', {}], ['auto', { CLAUDE_PLUGIN_ROOT: ROOT, CLAUDE_PROJECT_DIR: proj }]]
  return runs.map(([shape, extra]) => {
    const r = sh('bash', [hook, shape], { cwd: proj, env: { ...env, ...extra } })
    let text = null
    try {
      const j = JSON.parse(r.stdout)
      text = j.hookSpecificOutput?.additionalContext ?? j.additionalContext ?? j.additional_context ?? null
    } catch { /* reported below as not JSON */ }
    return { shape: extra.CLAUDE_PLUGIN_ROOT ? 'plugin' : shape, code: r.code, text, raw: r.stdout }
  })
}

const matcher = () => {
  try { return JSON.parse(read('hooks/hooks.json')).hooks.SessionStart.map((h) => h.matcher).join('|').split('|') }
  catch { return [] }
}

const cli = (args, cwd) => sh('node', [join(ROOT, 'cli', 'bin', 'mastermind.mjs'), ...args], { cwd })

let installed
function install() {
  if (installed) return installed
  const proj = emptyDir('install-proj')
  sh('git', ['init', '-q', '.'], { cwd: proj })
  mkdirSync(join(proj, '.claude'))
  writeFileSync(join(proj, '.claude', 'settings.json'), JSON.stringify({ permissions: { allow: ['Bash(ls:*)'] }, model: 'opus' }, null, 2))
  const r = sh('bash', [join(ROOT, 'install.sh'), 'claude', 'cursor', 'codex'], { cwd: proj })
  return (installed = { proj, ...r })
}

// A dangling symlink the project supplies, aimed outside it, in the default and the shared mode.
function escapeProbe() {
  return [['claude'], ['--shared', 'claude']].map((args, i) => {
    const proj = emptyDir(`escape-proj-${i}`)
    const outside = emptyDir(`escape-outside-${i}`)
    sh('git', ['init', '-q', '.'], { cwd: proj })
    mkdirSync(join(proj, '.mastermind'))
    symlinkSync(join(outside, 'prefs.md'), join(proj, '.mastermind', 'prefs.md'))
    const r = sh('bash', [join(ROOT, 'install.sh'), ...args], { cwd: proj })
    return { mode: args.join(' '), code: r.code, escaped: existsSync(join(outside, 'prefs.md')) }
  })
}

// The Codex shape, in a project whose AGENTS.md holds the kernel and in one with no kernel at all.
function codexPayloads() {
  const hook = join(ROOT, 'hooks', 'session-start.sh')
  const held = emptyDir('codex-held'), bare = emptyDir('codex-bare')
  writeFileSync(join(held, 'AGENTS.md'), read('CLAUDE.md'))
  return [['kernel in AGENTS.md', held], ['no kernel on disk', bare]].map(([name, cwd]) => {
    const r = sh('bash', [hook, 'codex'], { cwd })
    let text = null
    try {
      const o = JSON.parse(r.stdout).hookSpecificOutput
      if (o.hookEventName === 'SessionStart') text = o.additionalContext ?? null
    } catch { /* reported below as not the shape Codex reads */ }
    return { name, code: r.code, text }
  })
}

// A project with an AGENTS.md of its own: install, then uninstall.
function ownAgentsFile() {
  const proj = emptyDir('own-agents-proj')
  const file = join(proj, 'AGENTS.md'), theirs = '# Team rules\r\nNEVER FORCE PUSH'
  sh('git', ['init', '-q', '.'], { cwd: proj })
  writeFileSync(file, theirs)
  const inst = sh('bash', [join(ROOT, 'install.sh'), 'codex'], { cwd: proj })
  const wired = readFileSync(file, 'utf8')
  const un = sh('bash', [join(ROOT, 'install.sh'), '--uninstall'], { cwd: proj })
  return { theirs, wired, after: existsSync(file) ? readFileSync(file, 'utf8') : null, code: inst.code, uncode: un.code }
}

const DOCS = ['README.md', 'CLAUDE.md', 'SECURITY.md']
const MAP = 'scripts/update-scan.mjs'

const ROWS = [
  {
    id: 'skill-count', file: DOCS, claim: /\b\d+ skills\b/,
    test: (text) => {
      const bad = [...text.matchAll(/\b(\d+) skills\b/g)].filter((m) => +m[1] !== skills().length)
      return bad.length ? `says "${bad[0][0]}", the repo has ${skills().length}` : null
    },
  },
  {
    id: 'agent-count', file: DOCS, claim: /\b\d+ agents\b(?! in parallel)/,
    test: (text) => {
      const bad = [...text.matchAll(/\b(\d+) agents\b(?! in parallel)/g)].filter((m) => +m[1] !== agents().length)
      return bad.length ? `says "${bad[0][0]}", the repo has ${agents().length}` : null
    },
  },
  {
    id: 'agents-named', file: ['README.md', 'CLAUDE.md'], claim: /`architect`/, must: true,
    test: (text) => {
      const missing = agents().filter((a) => !text.includes('`' + a + '`'))
      return missing.length ? `never names the agent(s) ${missing.join(', ')}` : null
    },
  },
  {
    id: 'cli-no-dependencies', file: 'README.md', claim: /declares no dependencies/, must: true,
    test: () => {
      const pkg = JSON.parse(read('cli/package.json'))
      const has = ['dependencies', 'optionalDependencies', 'peerDependencies', 'bundledDependencies']
        .filter((k) => pkg[k] && Object.keys(pkg[k]).length)
      return has.length ? `cli/package.json declares ${has.join(', ')}` : null
    },
  },
  {
    id: 'node-floor', file: 'README.md', claim: /Node 18\+/, must: true,
    test: () => {
      const got = JSON.parse(read('cli/package.json')).engines?.node
      return got === '>=18' ? null : `cli/package.json engines.node is ${JSON.stringify(got)}`
    },
  },
  {
    id: 'cli-size', file: 'README.md', claim: /(\d+(?:\.\d+)?) KB packed, (\d+(?:\.\d+)?) KB unpacked/, must: true,
    test: (text, m) => {
      const r = sh('npm', ['pack', '--dry-run', '--json'], { cwd: join(ROOT, 'cli') })
      if (r.missing) return SKIP('npm is not installed')
      let p
      try { const raw = JSON.parse(r.stdout); p = Array.isArray(raw) ? raw[0] : Object.values(raw)[0] } catch { return SKIP('npm pack printed no JSON') }
      const off = (said, real) => Math.abs(said * 1000 - real) / real > 0.1
      return off(+m[1], p.size) || off(+m[2], p.unpackedSize)
        ? `says ${m[1]} KB packed, ${m[2]} KB unpacked; npm pack measures ${(p.size / 1000).toFixed(1)} and ${(p.unpackedSize / 1000).toFixed(1)}`
        : null
    },
  },
  {
    id: 'plugin-install-command', file: 'README.md', claim: /\/plugin install mastermind@mastermind/, must: true,
    test: () => {
      const m = JSON.parse(read('.claude-plugin/marketplace.json') || '{}')
      return m.name === 'mastermind' && (m.plugins ?? []).some((p) => p.name === 'mastermind')
        ? null : 'marketplace.json does not define a plugin "mastermind" in a marketplace "mastermind"'
    },
  },
  {
    id: 'mod-install-command', file: 'README.md', claim: /\/plugin install mastermind-mod@mastermind/,
    test: () => {
      const m = JSON.parse(read('.claude-plugin/marketplace.json') || '{}')
      if (!(m.plugins ?? []).some((p) => p.name === 'mastermind-mod')) return 'marketplace.json lists no plugin "mastermind-mod"'
      return existsSync(join(ROOT, 'mod', '.claude-plugin', 'plugin.json')) ? null : 'mod/.claude-plugin/plugin.json does not exist'
    },
  },
  {
    id: 'mod-minimum-version', file: 'README.md', claim: /Mod[\s\S]{0,400}?Claude Code (\d+\.\d+\.\d+)/,
    test: (text, m) => (read('mod/README.md').includes(m[1]) ? null : `says the Mod needs Claude Code ${m[1]}; mod/README.md does not say so`),
  },
  {
    id: 'mod-commands', file: 'README.md', claim: /`\/mm-[a-z-]+`/,
    test: (text) => {
      const dir = join(ROOT, 'mod', 'hooks')
      const src = existsSync(dir) ? readdirSync(dir).map((f) => read(`mod/hooks/${f}`)).join('\n') : ''
      const missing = [...text.matchAll(/`\/(mm-[a-z-]+)`/g)].map((m) => m[1]).filter((c) => !src.includes(`name: '${c}'`))
      return missing.length ? `names /${missing.join(', /')}, which the Mod does not register` : null
    },
  },
  {
    id: 'cli-commands-answer', file: ['README.md', 'CLAUDE.md', MAP], claim: /wrong-log/, must: true,
    test: () => {
      const cwd = emptyDir('cli-proj')
      const calls = [['skills'], ['skill', 'build'], ['agents'], ['agent', 'architect'], ['route', 'why is this slow?'], ['conflicts'], ['wrong-log']]
      for (const c of calls) {
        const r = cli([...c, '--json'], cwd)
        if (r.code !== 0) return `\`mastermind ${c.join(' ')}\` exited ${r.code}: ${r.out.trim().split('\n')[0]}`
        try { JSON.parse(r.stdout) } catch { return `\`mastermind ${c.join(' ')} --json\` did not print JSON` }
      }
      const left = readdirSync(cwd)
      return left.length ? `a read-only command wrote ${left.join(', ')} into the directory it ran in` : null
    },
  },
  {
    id: 'agents-md-is-the-kernel', file: 'CLAUDE.md', claim: /AGENTS\.md/,
    test: () => (read('AGENTS.md') === read('CLAUDE.md') ? null : 'AGENTS.md at the repo root does not carry the kernel'),
  },
  {
    id: 'hook-under-cap', file: [MAP, 'CLAUDE.md', 'README.md'], claim: /hook/i, must: true,
    test: () => {
      for (const p of hookPayloads()) {
        if (p.text === null) return `the ${p.shape} hook output is not the JSON shape a tool reads (exit ${p.code})`
        if ([...p.text].length >= HOOK_CAP) return `the ${p.shape} hook payload is ${[...p.text].length} characters; Claude Code truncates at ${HOOK_CAP}`
      }
      return null
    },
  },
  {
    id: 'hook-events', file: MAP, claim: /on (startup[a-z, ]*?(?:and|or) [a-z]+)[,.]/, must: true,
    test: (text, m) => {
      const said = m[1].split(/,\s*|\s+(?:and|or)\s+/).map((w) => w.trim()).filter(Boolean)
      const missing = said.filter((e) => !matcher().includes(e))
      return missing.length ? `says the hook runs on ${said.join(', ')}; hooks/hooks.json does not match ${missing.join(', ')}` : null
    },
  },
  {
    id: 'kernel-loads-natively', file: MAP, claim: /kernel (?:itself )?loads natively/, must: true,
    test: () => {
      const src = read('hooks/session-start.sh')
      if (!/CLAUDE\.md/.test(src)) return 'hooks/session-start.sh never points at CLAUDE.md'
      const p = hookPayloads().find((x) => x.shape === 'claude')
      return p?.text && /<mastermind-brain>/.test(p.text) ? null : 'the hook payload carries no <mastermind-brain> framing'
    },
  },
  {
    id: 'directive-cap', file: MAP, claim: /at (\d+) words/, must: true,
    test: (text, m) => (new RegExp(`MAX_WORDS = ${m[1]}\\b`).test(read('scripts/check-instructions.mjs'))
      ? null : `says directives are capped at ${m[1]} words; check-instructions.mjs uses another number`),
  },
  {
    id: 'cross-os-platforms', file: MAP, claim: /Linux · macOS · Windows · WSL · Alpine/, must: true,
    test: () => {
      const y = read('.github/workflows/cross-os.yml')
      const missing = ['linux', 'macos', 'windows-native-guard', 'wsl', 'alpine'].filter((j) => !new RegExp(`^  ${j}:`, 'm').test(y))
      return missing.length ? `cross-os.yml has no job ${missing.join(', ')}` : null
    },
  },
  {
    id: 'pre-tag-mirrors-gate', file: 'RELEASING.md', claim: /`pre-tag\.yml` runs everything the publish gate runs/, must: true,
    test: () => {
      const gate = read('.github/workflows/publish.yml').split(/^  cross-os:/m)[0]
      const pre = read('.github/workflows/pre-tag.yml')
      const missing = [...gate.matchAll(/^ {6}- (?:run: (?:node|bash) .+|name: .+)$/gm)].map((m) => m[0].trim())
        .filter((l) => !/the tagged commit is on master|refuse to release/.test(l) && !pre.includes(l))
      if (missing.length) return `pre-tag.yml does not run a step the publish gate runs: ${missing[0]}`
      return /uses: \.\/\.github\/workflows\/cross-os\.yml/.test(pre) ? null : 'pre-tag.yml does not run the platform matrix'
    },
  },
  {
    id: 'links-not-at-the-tag', file: 'RELEASING.md', claim: /Link liveness is deliberately absent/, must: true,
    test: () => (/check-links/.test(read('.github/workflows/publish.yml')) ? 'publish.yml still runs check-links at the tag' : null),
  },
  {
    id: 'actions-pinned', file: 'SECURITY.md', claim: /pinned to full commit SHAs/, must: true,
    test: () => {
      for (const [name, y] of workflows())
        for (const m of y.matchAll(/^\s*(?:-\s+)?uses:\s*(\S+)/gm))
          if (!m[1].startsWith('./') && !/@[0-9a-f]{40}$/.test(m[1])) return `${name} uses ${m[1]}, which is not a full commit SHA`
      return null
    },
  },
  {
    id: 'npm-pinned', file: 'SECURITY.md', claim: /`npm` itself is pinned/, must: true,
    test: () => (/npm install -g npm@\d+\.\d+\.\d+\b/.test(read('.github/workflows/publish.yml')) ? null : 'publish.yml does not install a pinned npm'),
  },
  {
    id: 'no-npm-token', file: 'SECURITY.md', claim: /no npm token/, must: true,
    test: () => {
      for (const [name, y] of workflows()) {
        if (/NPM_TOKEN|NODE_AUTH_TOKEN/.test(y)) return `${name} references an npm token`
        const grants = (y.match(/^\s*id-token:\s*write/gm) || []).length
        if (grants > (name === 'publish.yml' ? 1 : 0)) return `${name} grants id-token: write outside the one publish job`
      }
      return null
    },
  },
  {
    id: 'guards-exist', file: 'SECURITY.md', claim: /pre-commit \/ pre-push/, must: true,
    test: () => {
      for (const h of ['pre-commit', 'pre-push']) {
        const p = join(ROOT, '.githooks', h)
        if (!existsSync(p) || !(statSync(p).mode & 0o111)) return `.githooks/${h} is missing or not executable`
      }
      return null
    },
  },
  {
    id: 'settings-merge', file: 'README.md', claim: /leaving every other key and value as it was/, must: true, slow: true,
    test: () => {
      const { proj, code, out } = install()
      if (code !== 0) return `a plain install exited ${code}: ${out.trim().split('\n').slice(-1)[0]}`
      const s = JSON.parse(readFileSync(join(proj, '.claude', 'settings.json'), 'utf8'))
      if (s.model !== 'opus' || s.permissions?.allow?.[0] !== 'Bash(ls:*)') return 'the install changed a settings key that was not its own'
      return JSON.stringify(s.hooks?.SessionStart ?? '').includes('session-start.sh') ? null : 'the install registered no SessionStart hook'
    },
  },
  {
    id: 'per-tool-wiring', file: 'README.md', claim: /`alwaysApply: true`/, must: true, slow: true,
    test: () => {
      const { proj } = install()
      const rule = join(proj, '.cursor', 'rules', 'mastermind.mdc')
      if (!existsSync(rule) || !/alwaysApply:\s*true/.test(readFileSync(rule, 'utf8'))) return 'no always-applied .cursor/rules/mastermind.mdc after an install'
      if (!existsSync(join(proj, 'AGENTS.md'))) return 'no AGENTS.md after an install'
      return existsSync(join(proj, '.agents', 'skills', 'build')) ? null : 'no .agents/skills/build after an install'
    },
  },
  {
    id: 'codex-hook-wired', file: ['README.md', 'CLAUDE.md'], claim: /session hook|`SessionStart` entry in `\.codex\/hooks\.json`/, must: true, slow: true,
    test: () => {
      const { proj, code, out } = install()
      if (code !== 0) return `a plain install exited ${code}: ${out.trim().split('\n').slice(-1)[0]}`
      const file = join(proj, '.codex', 'hooks.json')
      if (!existsSync(file)) return 'no .codex/hooks.json after an install'
      const ours = (JSON.parse(readFileSync(file, 'utf8')).hooks?.SessionStart ?? [])
        .filter((e) => (e.hooks ?? []).some((h) => /session-start\.sh" codex$/.test(h.command ?? '')))
      if (!ours.length) return '.codex/hooks.json has no SessionStart entry that runs the hook in the codex shape'
      const missing = ['startup', 'resume', 'clear', 'compact', 'fork'].filter((src) => !ours.some((e) => new RegExp(e.matcher).test(src)))
      if (missing.length) return `the Codex hook's matcher does not cover ${missing.join(', ')}`
      return existsSync(join(home, '.codex', 'config.toml')) ? 'the install wrote ~/.codex/config.toml' : null
    },
  },
  {
    id: 'codex-hook-under-cap', file: ['README.md', 'CLAUDE.md'], claim: /session hook|`SessionStart` entry in `\.codex\/hooks\.json`/, must: true,
    test: () => {
      for (const p of codexPayloads()) {
        if (p.text === null) return `the codex hook output (${p.name}) is not the SessionStart shape Codex reads (exit ${p.code})`
        if ([...p.text].length >= CODEX_HOOK_CAP) return `the codex hook payload (${p.name}) is ${[...p.text].length} characters; the limit used for Codex is ${CODEX_HOOK_CAP}`
      }
      return null
    },
  },
  {
    id: 'cursor-subagents-wired', file: ['README.md', 'CLAUDE.md'], claim: /agents are wired as subagents|agents as subagents in `\.cursor\/agents\/`/, must: true, slow: true,
    test: () => {
      const { proj } = install()
      for (const a of agents()) {
        const f = join(proj, '.cursor', 'agents', `${a}.md`)
        if (!existsSync(f)) return `no .cursor/agents/${a}.md after an install`
        const fm = (readFileSync(f, 'utf8').match(/^---\n([\s\S]*?)\n---\n/) ?? [])[1] ?? ''
        const keys = fm.split('\n').map((l) => l.split(':')[0])
        const extra = keys.filter((k) => !['name', 'description', 'model', 'readonly'].includes(k))
        if (extra.length) return `.cursor/agents/${a}.md carries frontmatter Cursor does not document: ${extra.join(', ')}`
        if (!/^model: inherit$/m.test(fm)) return `.cursor/agents/${a}.md does not inherit the model`
        const readonly = /^readonly: true$/m.test(fm)
        if (readonly !== ['code-reviewer', 'tech-scout'].includes(a)) return `.cursor/agents/${a}.md is ${readonly ? '' : 'not '}read-only`
      }
      return null
    },
  },
  {
    id: 'agents-md-kernel-block', file: 'README.md', claim: /kernel in a marked block/, must: true, slow: true,
    test: () => {
      const r = ownAgentsFile()
      if (r.code !== 0) return `an install beside an AGENTS.md of the user's own exited ${r.code}`
      if (!r.wired.startsWith(r.theirs)) return 'the install changed the bytes of an existing AGENTS.md'
      const block = r.wired.match(KERNEL_BLOCK)
      if (!block || !block[1].startsWith('# MasterMind: global operating system')) return 'an existing AGENTS.md did not get the kernel in a marked block'
      return r.after === r.theirs ? null : 'uninstall did not return an existing AGENTS.md to the bytes it had'
    },
  },
  {
    id: 'writes-stay-inside', file: 'SECURITY.md', claim: /never followed/, must: true, slow: true,
    test: () => {
      for (const r of escapeProbe()) {
        if (r.escaped) return `\`install.sh ${r.mode}\` wrote through a symlink to a file outside the project`
        if (r.code === 0) return `\`install.sh ${r.mode}\` met a symlinked destination and still exited 0`
      }
      return null
    },
  },
]

function run() {
  const failed = [], skipped = [], idle = []
  let held = 0
  for (const row of ROWS) {
    if (ONLY && !ONLY.includes(row.id)) continue
    if (FAST && row.slow) { skipped.push(`${row.id}: skipped by --fast`); continue }
    const files = [].concat(row.file)
    const stated = files.map((f) => [f, read(f)]).filter(([, t]) => row.claim.test(t))
    if (!stated.length) {
      if (row.must) failed.push({ id: row.id, why: `${files.join(', ')} no longer states this; reword the row or delete it` })
      else idle.push(row.id)
      continue
    }
    for (const [f, text] of stated) {
      let res
      try { res = row.test(text, text.match(row.claim)) } catch (e) { res = `the test threw: ${e.message}` }
      if (res?.skip) skipped.push(`${row.id}: ${res.skip}`)
      else if (res) failed.push({ id: row.id, why: `${f}: ${res}` })
      else held++
      if (res) break
    }
  }
  return { failed, skipped, idle, held }
}

function selfTest() {
  const copy = join(scratch, 'mutated')
  cpSync(HERE, copy, { recursive: true, verbatimSymlinks: true, filter: (src) => !/\/(\.git|node_modules|evals|\.claude|private|lab)(\/|$)/.test(src.slice(HERE.length)) })
  const edit = (rel, fn) => writeFileSync(join(copy, rel), fn(readFileSync(join(copy, rel), 'utf8')))
  edit('README.md', (t) => `${t}\nIt ships 999 skills and 99 agents.\n`)
  edit('cli/package.json', (t) => { const p = JSON.parse(t); p.dependencies = { leftpad: '1.0.0' }; p.engines.node = '>=20'; return JSON.stringify(p) })
  edit('hooks/hooks.json', (t) => t.replace(/"matcher":\s*"[^"]*"/, '"matcher": "startup"'))
  edit('hooks/session-start.sh', (t) => t.replace(/\ncase "\$SHAPE" in\n/, `\npayload="$payload${'x'.repeat(HOOK_CAP)}"\ncase "$SHAPE" in\n`))
  edit('.github/workflows/integrity.yml', (t) => t.replace(/uses: actions\/checkout@[0-9a-f]{40}/, 'uses: actions/checkout@v4'))
  edit('.github/workflows/publish.yml', (t) => t.replace(/npm install -g npm@[\d.]+/, 'npm install -g npm@latest'))
  edit('scripts/check-instructions.mjs', (t) => t.replace(/MAX_WORDS = \d+/, 'MAX_WORDS = 45'))
  edit('.claude-plugin/marketplace.json', (t) => t.replace('"name": "mastermind"', '"name": "elsewhere"'))
  rmSync(join(copy, 'agents', 'tech-scout.md'))
  edit('.github/workflows/pre-tag.yml', (t) => t.replace(/^ {6}- run: node scripts\/build-router\.mjs --check\n/m, ''))
  const r = spawnSync('node', [join(HERE, 'scripts', 'check-claims.mjs'), '--root', copy, '--fast', '--json'], { encoding: 'utf8' })
  const got = new Set(JSON.parse(r.stdout).failed.map((f) => f.id))
  // The rows that install into a sandbox are skipped by --fast, so they get a brain of their own.
  const wired = ['codex-hook-wired', 'cursor-subagents-wired', 'agents-md-kernel-block']
  const second = join(scratch, 'mutated-install')
  cpSync(HERE, second, { recursive: true, verbatimSymlinks: true, filter: (src) => !/\/(\.git|node_modules|evals|\.claude|private|lab)(\/|$)/.test(src.slice(HERE.length)) })
  const mutate = (fn) => writeFileSync(join(second, 'install.sh'), fn(readFileSync(join(second, 'install.sh'), 'utf8')))
  mutate((t) => t.split('wire_codex_hook; wire_agent_skills').join('wire_agent_skills'))
  mutate((t) => t.replace('print "model: inherit"', 'print "model: fast"'))
  mutate((t) => t.replace('mm_strip_block "$t" exact "$MM_KSTART" "$MM_KEND" || return 0', 'return 0'))
  const r2 = spawnSync('node', [join(HERE, 'scripts', 'check-claims.mjs'), '--root', second, '--only', wired.join(','), '--json'], { encoding: 'utf8' })
  for (const f of JSON.parse(r2.stdout).failed) got.add(f.id)
  const want = ['skill-count', 'agent-count', 'cli-no-dependencies', 'node-floor', 'hook-events', 'hook-under-cap',
    'actions-pinned', 'npm-pinned', 'directive-cap', 'plugin-install-command', 'pre-tag-mirrors-gate', 'codex-hook-under-cap', ...wired]
  const silent = want.filter((id) => !got.has(id))
  if (silent.length || r.status !== 1 || r2.status !== 1) {
    console.error(`✖ claims self-test: planted a false statement and the row stayed quiet: ${silent.join(', ') || 'exit ' + r.status}`)
    process.exit(1)
  }
  console.log(`✓ claims self-test: ${want.length} planted false statements each fail their row.`)
}

if (process.argv.includes('--self-test')) selfTest()
else {
  const r = run()
  if (process.argv.includes('--json')) console.log(JSON.stringify(r))
  else {
    for (const f of r.failed) console.error(`  ✖ ${f.id}: ${f.why}`)
    for (const s of r.skipped) console.log(`  ⚠ could not run ${s}`)
    if (r.idle.length) console.log(`  · not stated anywhere, so not tested: ${r.idle.join(', ')}`)
    const tail = `${r.held} statement(s) hold, ${r.failed.length} false, ${r.skipped.length} could not run`
    console.log(r.failed.length ? `✖ claims: ${tail}.` : r.skipped.length ? `· claims: ${tail}.` : `✓ claims: ${tail}.`)
  }
  process.exitCode = r.failed.length ? 1 : r.skipped.length ? 2 : 0
}
