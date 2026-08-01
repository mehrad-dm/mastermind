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

import { execFileSync, spawnSync } from 'node:child_process'
import { existsSync, readFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const VERSION = JSON.parse(
  readFileSync(join(dirname(fileURLToPath(import.meta.url)), '..', 'package.json'), 'utf8'),
).version

// Overridable for tests and forks; defaults are the published truth.
const REPO_URL = process.env.MASTERMIND_REPO || 'https://github.com/mehrad-dm/mastermind'
const MM_HOME = process.env.MASTERMIND_HOME || join(homedir(), '.mastermind')
const PIN = process.env.MASTERMIND_REF || `v${VERSION}`

const argv = process.argv.slice(2)
const cmd = ['check', 'update', 'uninstall', 'init'].includes(argv[0]) ? argv.shift() : 'init'
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

if (process.platform === 'win32') {
  fail('Native Windows is not supported yet — run this inside WSL (or Git Bash), where it works as-is.')
}
try {
  execFileSync('git', ['--version'], { stdio: 'ignore' })
} catch {
  fail('git is required (the brain is a git repo — that is also how you audit it).')
}

// ── 1. make sure the brain exists at ~/.mastermind ─────────────────────────────
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
