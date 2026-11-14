// The MasterMind mod: optional, Claude Code 2.1.287 or newer. The Markdown brain works without it.
// Events and $ calls are spelled literally because Claude Code reads them from this source.
import { irreversible, looksRisky, reasonFor, redirectTargets } from './irreversible.mjs'
import { evidence, hasKernel, isReview, needsAttention, notices, statusLine, steps } from './signals.mjs'

const WRITERS = ['Edit', 'Write', 'MultiEdit', 'NotebookEdit']
const NO_CLI = 'no mastermind CLI at <project>/.mastermind/bin/mastermind or ~/.mastermind/bin/mastermind. Set the brain up with: npx mastermind-brain'
const FORK_NOTE = 'this reviewer is a fork. A fork inherits the context that wrote the work: not a clean-context review. The code-reviewer agent starts fresh.'

let cfg = { hold: 'all', headless: 'defer', handoffAt: 70, nudge: 'on' }
let facts = { status: undefined, kernel: null, percent: null }
let turn = { changed: false, checks: [] }
let checksSinceChange = null
let hinted = false
let lastRoot = ''
let tempDirs = null
const agents = new Map()

function settings(options) {
  const o = options ?? {}
  const at = Number(o.handoffAt)
  return {
    hold: ['all', 'destructive-only', 'off'].includes(o.hold) ? o.hold : 'all',
    headless: o.headless === 'deny' ? 'deny' : 'defer',
    handoffAt: Number.isFinite(at) && at >= 0 && at <= 100 ? at : 70,
    nudge: o.nudge === 'off' ? 'off' : 'on',
  }
}

export function register(on, options) {
  cfg = settings(options)

  on('session.start', async ($, e, next) => {
    await commands($)
    try {
      lastRoot = await $.session.root()
    } catch {
      lastRoot = ''
    }
    refresh($)
    return next(e)
  })

  on('tool.check', { tool: 'Bash' }, holdBash).catch(async ($, e, next) => {
    const risk = cfg.hold === 'off' ? null : looksRisky(e.input?.command)
    if (!risk || (cfg.hold === 'destructive-only' && !risk.destructive)) return next(e)
    const decided = await next(e).catch(() => null)
    if (decided && (decided.decision === 'ask' || decided.decision === 'deny')) return decided
    return { decision: 'deny', reason: 'The MasterMind hold failed (' + next.error.kind + '), so this command was not run. Ask the user to run it themselves.' }
  })

  on('tool.check', { tool: ['Edit', 'Write', 'MultiEdit', 'NotebookEdit'] }, holdWrite).catch(async ($, e, next) => {
    const path = String(e.input?.file_path ?? e.input?.notebook_path ?? '')
    const temp = /^(\/private)?(\/tmp|\/var\/tmp|\/var\/folders)\//.test(path)
    if (cfg.hold === 'off' || temp || !path.startsWith('/') || (lastRoot !== '' && path.startsWith(lastRoot + '/'))) return next(e)
    return { decision: 'deny', reason: 'The MasterMind hold failed (' + next.error.kind + '), so this write outside the project was not made. Ask the user to make it themselves.' }
  })

  on('tool.call', async ($, e, next) => {
    const result = await next(e)
    record(e, result)
    return result
  })

  on('turn.start', async ($, e, next) => {
    if (e.agentId === undefined) turn = { changed: false, checks: [] }
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId !== undefined) {
      agents.delete(e.agentId)
      paint($)
      return result
    }
    const ended = e.reason ?? (e.isAborted ? 'aborted' : 'answer')
    if (ended === 'answer' && !e.isAborted && cfg.nudge === 'on') {
      for (const line of notices(e.answer, turn, checksSinceChange)) $.ui.log(line)
    }
    if (turn.changed) refresh($)
    else paint($)
    return result
  })

  on('agent.spawn', async ($, e, next) => {
    const started = await next(e)
    if (started.deny !== undefined || e.resume !== undefined || !started.agentId) return started
    const isFork = e.fork === true || e.subagentType === 'fork'
    agents.set(started.agentId, isFork ? 'fork' : String(started.model ?? e.model ?? 'default'))
    if (isFork && cfg.nudge === 'on' && isReview(e.description + ' ' + e.prompt)) $.ui.log(FORK_NOTE)
    paint($)
    return started
  })

  on('session.measure', async ($, e, next) => {
    const percent = e.context?.percent
    if (typeof percent === 'number') {
      facts.percent = percent
      if (cfg.handoffAt > 0 && percent < cfg.handoffAt) hinted = false
      if (cfg.handoffAt > 0 && percent >= cfg.handoffAt && !hinted) {
        hinted = true
        $.ui.toast('context ' + percent + '% full: say handoff, or run /handoff, to save the state of this work before it compacts', { timeoutMs: 12000 })
      }
    }
    paint($)
    return next(e)
  })

  on('prompt.context', async ($, e, next) => {
    if (e.instructionFiles !== undefined) sawKernel($, hasKernel(e.instructionFiles.map((f) => f.content)), 'instruction files')
    return next(e)
  })

  on('session.append', { door: 'hook-context' }, async ($, e, next) => {
    if (e.agentId === undefined && Array.isArray(e.message?.content) && hasKernel(e.message.content.map((b) => b?.text))) sawKernel($, true, 'session hook')
    return next(e)
  })

  on('command.run', { command: ['mm-status', 'mm-wrong-log', 'mm-next', 'mm-check', 'mm-evidence'] }, async ($, e) => {
    try {
      return { text: await answer($, e.command) }
    } catch (error) {
      return { text: '/' + e.command + ' failed: ' + String(error?.message ?? error) }
    }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const below = await next(e)
    if (e.props?.hasSurvey) return below
    const { Box, Text } = $.ui.resolve(e)
    const mine = Text({ key: 'mastermind', dimColor: true, wrap: 'truncate-end', children: [statusLine(facts, cfg, [...agents.values()])] })
    return Box({ flexDirection: 'column', children: [mine, below].filter(Boolean) })
  })
}

async function commands($) {
  const add = async (spec) => {
    try {
      await spec()
    } catch {
      return
    }
  }
  await add(() => $.command.register({ name: 'mm-status', description: 'MasterMind: brain, field pack, logged misses and next spec step (no model turn)', immediate: true }))
  await add(() => $.command.register({ name: 'mm-wrong-log', description: 'MasterMind: the last 10 logged misses and what caught each (no model turn)', immediate: true }))
  await add(() => $.command.register({ name: 'mm-next', description: 'MasterMind: the next spec-driven step for this project (no model turn)', immediate: true }))
  await add(() => $.command.register({ name: 'mm-check', description: "MasterMind: run the installer's --check on this project (no model turn)", immediate: true }))
  await add(() => $.command.register({ name: 'mm-evidence', description: 'MasterMind: the check commands that ran in the latest turn and whether each exited 0 (no model turn)', immediate: true }))
}

function held(e, decided, risk) {
  if (cfg.hold === 'destructive-only' && !risk.destructive) return decided
  const reason = reasonFor(risk)
  if (e.approver === undefined) return cfg.headless === 'deny' ? { decision: 'deny', reason } : decided
  return { decision: 'ask', reason }
}

async function holdBash($, e, next) {
  const decided = await next(e)
  if (cfg.hold === 'off' || decided.decision === 'deny') return decided
  const command = e.input?.command
  const targets = redirectTargets(command)
  if (!irreversible(command) && !targets.length) return decided
  const root = await $.session.root()
  const home = (await $.env.get('HOME')) ?? ''
  const existing = new Set()
  for (const t of targets) {
    const at = t.startsWith('/') ? t : t.startsWith('~/') ? home + t.slice(1) : root + '/' + t
    if (await $.fs.exists(at)) existing.add(t)
  }
  const risk = irreversible(command, { root, tmpdir: await $.env.get('TMPDIR'), existing })
  return risk ? held(e, decided, risk) : decided
}

async function holdWrite($, e, next) {
  const decided = await next(e)
  if (cfg.hold === 'off' || decided.decision === 'deny') return decided
  const path = String(e.input?.file_path ?? e.input?.notebook_path ?? '')
  if (path === '') return decided
  const where = await outside($, path)
  if (where === null) return decided
  return held(e, decided, { label: e.tool + ' ' + where, effect: 'writes outside this project', rule: 'outside', destructive: true })
}

// undefined: nothing is there. null: something is there and it leads nowhere, as a dangling link does.
async function real($, path) {
  try {
    return (await $.fs.stat(path, { resolve: true })).realPath ?? null
  } catch {
    return undefined
  }
}

async function placed($, path) {
  let head = path
  let tail = ''
  for (let i = 0; i < 64; i += 1) {
    const at = await real($, head)
    if (at === null) return undefined
    if (at !== undefined) return tail.split('/').includes('..') ? undefined : at.replace(/\/+$/, '') + tail
    if (head === '/' || head === '.') return undefined
    const trimmed = head.replace(/\/+$/, '')
    const cut = trimmed.lastIndexOf('/')
    tail = '/' + trimmed.slice(cut + 1) + tail
    head = cut < 0 ? '.' : cut === 0 ? '/' : trimmed.slice(0, cut)
  }
  return undefined
}

const under = (path, dir) => path === dir || path.startsWith(dir.replace(/\/+$/, '') + '/')

async function outside($, raw) {
  const home = (await $.env.get('HOME')) ?? ''
  const path = raw === '~' || raw.startsWith('~/') ? home + raw.slice(1) : raw
  const at = await placed($, path)
  if (at === undefined) return path
  const root = await $.session.root()
  lastRoot = (await real($, root)) ?? root
  if (under(at, lastRoot)) return null
  if (tempDirs === null) {
    const found = [await real($, (await $.env.get('TMPDIR')) ?? '/tmp'), await real($, '/tmp'), await real($, '/var/tmp')]
    const dirs = found.filter((d) => typeof d === 'string' && d !== '/')
    if (dirs.length) tempDirs = dirs
    if (dirs.some((d) => under(at, d))) return null
  } else if (tempDirs.some((d) => under(at, d))) return null
  const own = (await real($, home + '/.claude')) ?? home + '/.claude'
  if (home !== '' && (under(at, own + '/plans') || (under(at, own + '/projects') && at.includes('/memory/')))) return null
  return at
}

function record(e, result) {
  if (!result || result.deny !== undefined) return
  const failed = result.isError === true
  if (WRITERS.includes(e.tool)) {
    if (!failed) changed()
    return
  }
  if (e.tool !== 'Bash') return
  const command = String(e.command ?? '')
  if (result.isReadOnly === true) return
  const ok = !failed && result.result?.interrupted !== true
  for (const step of steps(command)) {
    if (step === 'change') changed()
    if (step !== 'check') continue
    turn.checks.push({ command: command.replace(/\s+/g, ' ').slice(0, 160), ok, agent: e.agentId !== undefined })
    if (ok && checksSinceChange !== null) checksSinceChange += 1
  }
}

function changed() {
  turn.changed = true
  checksSinceChange = 0
}

function sawKernel($, found, where) {
  const before = facts.kernel
  if (found) facts.kernel = true
  else if (facts.kernel === null) facts.kernel = false
  if (facts.kernel === before) return
  $.ui.log('mastermind-mod: kernel ' + (facts.kernel ? 'loaded' : 'not loaded') + ' (' + where + ')', { to: 'debug' })
  paint($)
}

async function cli($) {
  const root = await $.session.root()
  const home = (await $.env.get('HOME')) ?? ''
  for (const dir of [root, home]) {
    const bin = dir + '/.mastermind/bin/mastermind'
    if (dir !== '' && (await $.fs.exists(bin))) return { bin, root, home }
  }
  return { bin: null, root, home }
}

async function refresh($) {
  try {
    const at = await cli($)
    const run = at.bin ? await $.process.run([at.bin, 'status', '--json'], { cwd: at.root, timeoutMs: 15000 }) : null
    const parsed = run && run.exitCode === 0 ? JSON.parse(run.stdout) : null
    facts.status = parsed && typeof parsed === 'object' && !parsed.error ? parsed : null
  } catch {
    facts.status = null
  }
  await paint($)
}

async function paint($) {
  try {
    $.ui.invalidate('ui.render')
    const surfaces = await $.session.surfaces()
    if (!surfaces.length) return
    const hasBand = surfaces.some((s) => s === 'terminal' || s === 'desktop' || s === 'mobile')
    $.ui.status(!hasBand && needsAttention(facts, cfg) ? statusLine(facts, cfg, [...agents.values()]).replace('MasterMind · ', '') : undefined)
  } catch {
    return
  }
}

const clean = (run) => (run.stdout + (run.stdout && run.stderr ? '\n' : '') + run.stderr).replace(/\x1b\[[0-9;]*m/g, '').trim()

async function answer($, command) {
  if (command === 'mm-evidence') return evidence(turn)
  const at = await cli($)
  if (command === 'mm-check') return check($, at)
  if (!at.bin) return (command === 'mm-status' ? 'status unavailable: ' : 'Nothing to read: ') + NO_CLI
  const args = command === 'mm-status' ? ['status'] : command === 'mm-next' ? ['next'] : ['wrong-log']
  const run = await $.process.run([at.bin, ...args], { cwd: at.root, timeoutMs: 15000 })
  const out = clean(run)
  if (command === 'mm-status' && run.exitCode !== 0)
    return 'status unavailable: ' + at.bin + ' has no `status` command (exit ' + run.exitCode + '). Update the brain: npx mastermind-brain update'
  if (command !== 'mm-wrong-log' || run.exitCode !== 0) return out || '(no output, exit ' + run.exitCode + ')'
  const rows = out.split('\n')
  return rows.length > 10 ? rows.length + ' misses logged; the last 10:\n' + rows.slice(-10).join('\n') : out
}

async function check($, at) {
  const brains = [facts.status?.brain, at.root + '/.mastermind', at.home + '/.mastermind'].filter((b) => typeof b === 'string' && b !== '')
  let installer = null
  for (const brain of brains) {
    if (await $.fs.exists(brain + '/install.sh')) {
      installer = brain + '/install.sh'
      break
    }
  }
  if (installer === null)
    return 'No installer here, so nothing was checked. This looks like a plugin-only install: the skills and this mod came from the plugin marketplace, and `--check` verifies the wiring that `npx mastermind-brain` creates in a project.'
  const run = await $.process.run(['bash', installer, '--check'], { cwd: at.root, timeoutMs: 120000, env: { MM_NO_NETWORK: '1' } })
  return 'bash ' + installer + ' --check (exit ' + run.exitCode + ')\n' + (clean(run) || '(no output)')
}
