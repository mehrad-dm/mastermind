// Shared stand-ins for the engine: every hook here answers in the engine's place.

export const ROOT = '/work/proj'
export const CLI = ROOT + '/.mastermind/bin/mastermind'
export const HOME_CLI = '/home/u/.mastermind/bin/mastermind'
export const KERNEL = '# MasterMind: global operating system\n\nYou are MasterMind.'

export const STATUS = {
  version: '0.34.0',
  brain: ROOT + '/.mastermind',
  mode: 'isolated',
  kernel: { path: ROOT + '/.mastermind/CLAUDE.md', chars: 9321 },
  field: { name: 'web', level: 2 },
  misses: { count: 50, last: { date: '2026-11-07', what: 'a changelog claim never checked against the diff' } },
  next: { feature: '004-invitations', skill: 'blueprint', reason: 'no plan.md yet' },
}

export const STATUS_TEXT = 'MasterMind 0.34.0 · isolated brain at /work/proj/.mastermind\nkernel 9321 chars · field web (level 2)\n50 misses logged, last 2026-11-07\nnext: blueprint for 004-invitations: no plan.md yet'
export const NEXT_TEXT = 'specs/004-invitations · clarified (most recently changed open feature)\nnext: blueprint: no plan.md yet'
export const MISSES = Array.from({ length: 12 }, (_, i) => '2026-10-' + String(i + 10) + ' · wrong · miss ' + (i + 1) + ' · caught by a test')

const REAL: Record<string, string | null> = {
  [ROOT]: ROOT,
  [ROOT + '/src']: ROOT + '/src',
  [ROOT + '/src/a.ts']: ROOT + '/src/a.ts',
  '/tmp': '/private/tmp',
  '/var/tmp': '/private/var/tmp',
  '/var/folders/x/T/': '/private/var/folders/x/T',
  '/var/folders/x/T': '/private/var/folders/x/T',
  '/home/u': '/home/u',
  '/home/u/.claude': '/home/u/.claude',
  '/': '/',
}

export type Over = {
  surfaces?: string[]
  files?: string[]
  real?: Record<string, string | null>
  run?: (argv: readonly string[]) => { exitCode: number; stdout: string; stderr: string }
  tool?: (e: any) => any
  check?: (e: any) => any
  spawn?: (e: any) => any
  rootFails?: boolean
}

export function cliRun(argv: readonly string[]) {
  const out = (stdout: string) => ({ exitCode: 0, stdout, stderr: '' })
  if (argv[0] === 'bash') return out('✓ Claude Code wired\n✓ healthy\n')
  if (argv[1] === 'status') return out(argv[2] === '--json' ? JSON.stringify(STATUS) : STATUS_TEXT + '\n')
  if (argv[1] === 'next') return out(NEXT_TEXT + '\n')
  if (argv[1] === 'wrong-log') return out(MISSES.join('\n') + '\n')
  return { exitCode: 2, stdout: '', stderr: 'unknown' }
}

export function world(on: any, over: Over = {}) {
  const seen = {
    logs: [] as string[],
    debug: [] as string[],
    status: [] as (string | undefined)[],
    toasts: [] as string[],
    runs: [] as string[][],
    cwds: [] as (string | undefined)[],
    envs: [] as (Record<string, string> | undefined)[],
    registered: [] as string[],
    calls: [] as string[],
  }
  const files = over.files ?? [CLI, ROOT + '/.mastermind/install.sh']
  const real = { ...REAL, ...over.real }
  on('session.root', () => {
    seen.calls.push('session.root')
    if (over.rootFails) throw new Error('no root')
    return { value: ROOT }
  })
  on('env.get', (_: any, e: any) => ({ value: e.name === 'HOME' ? '/home/u' : e.name === 'TMPDIR' ? '/var/folders/x/T/' : undefined }))
  on('session.surfaces', () => ({ value: over.surfaces ?? ['terminal'] }))
  on('fs.exists', (_: any, e: any) => ({ value: files.includes(e.path) }))
  on('fs.stat', (_: any, e: any) => {
    if (!(e.path in real)) return { deny: 'ENOENT' }
    const at = real[e.path]
    return { value: at === null ? { kind: 'other', size: 0, mtimeMs: 0, isLink: true } : { kind: 'dir', size: 0, mtimeMs: 0, isLink: false, realPath: at } }
  })
  on('process.run', (_: any, e: any) => {
    seen.runs.push([...e.argv])
    seen.cwds.push(e.init?.cwd)
    seen.envs.push(e.init?.env)
    return { value: (over.run ?? cliRun)(e.argv) }
  })
  on('ui.log', (_: any, e: any) => ((e.to === 'debug' ? seen.debug : seen.logs).push(e.text), { value: undefined }))
  on('ui.status', (_: any, e: any) => (seen.status.push(e.text), { value: undefined }))
  on('ui.toast', (_: any, e: any) => (seen.toasts.push(e.text), { value: undefined }))
  on('command.register', (_: any, e: any) => (seen.registered.push(e.name), { value: { command: e.name } }))
  on('session.start', (_: any, e: any) => ({ cwd: e.cwd }))
  on('session.measure', (_: any, e: any) => ({ changed: e.changed }))
  on('turn.start', (_: any, e: any) => ({ turnId: e.turnId }))
  on('turn.complete', () => ({ text: '' }))
  on('tool.call', (_: any, e: any) => (over.tool ? over.tool(e) : { result: {} }))
  on('tool.check', (_: any, e: any) => (over.check ? over.check(e) : { decision: 'allow' }))
  on('agent.spawn', (_: any, e: any) => (over.spawn ? over.spawn(e) : { model: 'sonnet', agentId: 'agent-1' }))
  on('prompt.context', (_: any, e: any) => ({ blocks: e.blocks }))
  return seen
}

export async function settle($: any, done: () => boolean | Promise<boolean>) {
  for (let i = 0; i < 300; i += 1) {
    if (await done()) return true
    await $.command.run({ command: 'mm-evidence' })
  }
  return false
}

export const START = { cwd: ROOT, surface: 'terminal', isInteractive: true } as const

export const BAND = {
  plugin: 'mastermind-mod',
  component: 'AbovePrompt',
  requestId: 'band',
  props: { hasSurvey: false, isCollapsed: false, isWorking: false, maxRows: 4, bodyColumns: 160, scroll: { offset: 0, bodyRows: 4 }, view: {} },
} as const

let turns = 0

export async function runTurn($: any, calls: any[], answer: string, extra: Record<string, unknown> = {}) {
  turns += 1
  const turnId = 't' + turns
  await $.turn.start({ turnId, text: 'go', ...(extra.agentId ? { agentId: extra.agentId } : {}) })
  for (const call of calls) await $.tool.call(call)
  await $.turn.complete({ turnId, answer, durationMs: 5, isAborted: false, reason: 'answer', ...extra })
}
