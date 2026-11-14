import { expect, test } from 'claude-code/testing'
import { BAND, CLI, HOME_CLI, KERNEL, MISSES, NEXT_TEXT, ROOT, START, STATUS, STATUS_TEXT, cliRun, runTurn, settle, world } from './kit'

const edit = { tool: 'Edit', file_path: ROOT + '/src/a.ts', old_string: 'a', new_string: 'b' }
const band = async ($: any, ui: any, text: RegExp) => {
  let found: any
  await settle($, async () => (found = await ui.find({ type: 'Text', text })) !== undefined)
  return found?.text as string | undefined
}

test('commands: all five register at session start, each by its own name', async ($, on) => {
  const seen = world(on)
  await $.session.start(START)
  expect(seen.registered).toEqual(['mm-status', 'mm-wrong-log', 'mm-next', 'mm-check', 'mm-evidence'])
})

test('/mm-status prints the four lines of `mastermind status`, from the project CLI', async ($, on) => {
  const seen = world(on)
  const out = await $.command.run({ command: 'mm-status' })
  expect(out.text).toBe(STATUS_TEXT)
  expect(seen.runs).toEqual([[CLI, 'status']])
  expect(seen.cwds).toEqual([ROOT])
})

test('/mm-status falls back to the CLI in the home directory', async ($, on) => {
  const seen = world(on, { files: [HOME_CLI] })
  expect((await $.command.run({ command: 'mm-status' })).text).toBe(STATUS_TEXT)
  expect(seen.runs).toEqual([[HOME_CLI, 'status']])
})

test('/mm-status with no CLI anywhere says status unavailable and runs nothing', async ($, on) => {
  const seen = world(on, { files: [] })
  const out = await $.command.run({ command: 'mm-status' })
  expect(out.text).toContain('status unavailable')
  expect(out.text).toContain('npx mastermind-brain')
  expect(seen.runs).toEqual([])
})

test('/mm-status on a brain whose CLI has no `status` yet says so instead of printing an error', async ($, on) => {
  world(on, { run: () => ({ exitCode: 2, stdout: '', stderr: '✖ unknown argument "status". Nothing was installed or changed.' }) })
  const out = await $.command.run({ command: 'mm-status' })
  expect(out.text).toContain('status unavailable')
  expect(out.text).toContain('npx mastermind-brain update')
})

test('/mm-wrong-log shows the last 10 of 12 misses and says how many there are', async ($, on) => {
  const seen = world(on)
  const out = await $.command.run({ command: 'mm-wrong-log' })
  expect(out.text).toBe('12 misses logged; the last 10:\n' + MISSES.slice(-10).join('\n'))
  expect(seen.runs).toEqual([[CLI, 'wrong-log']])
})

test('/mm-wrong-log with few misses prints them as the CLI does', async ($, on) => {
  world(on, { run: () => ({ exitCode: 0, stdout: MISSES.slice(0, 2).join('\n') + '\n', stderr: '' }) })
  expect((await $.command.run({ command: 'mm-wrong-log' })).text).toBe(MISSES.slice(0, 2).join('\n'))
})

test('/mm-next output is `mastermind next` verbatim', async ($, on) => {
  const seen = world(on)
  expect((await $.command.run({ command: 'mm-next' })).text).toBe(NEXT_TEXT)
  expect(seen.runs).toEqual([[CLI, 'next']])
})

test('/mm-check runs the installer\'s --check from the brain, never the CLI\'s check', async ($, on) => {
  const seen = world(on)
  const out = await $.command.run({ command: 'mm-check' })
  expect(seen.runs).toEqual([['bash', ROOT + '/.mastermind/install.sh', '--check']])
  expect(seen.cwds).toEqual([ROOT])
  expect(seen.envs).toEqual([{ MM_NO_NETWORK: '1' }])
  expect(out.text).toContain('bash ' + ROOT + '/.mastermind/install.sh --check (exit 0)')
  expect(out.text).toContain('healthy')
})

test('/mm-check finds the installer in the home brain when the project has none', async ($, on) => {
  const seen = world(on, { files: [HOME_CLI, '/home/u/.mastermind/install.sh'] })
  await $.command.run({ command: 'mm-check' })
  expect(seen.runs).toEqual([['bash', '/home/u/.mastermind/install.sh', '--check']])
})

test('/mm-check in a plugin-only install says plainly that there is no installer, and runs nothing', async ($, on) => {
  const seen = world(on, { files: [] })
  const out = await $.command.run({ command: 'mm-check' })
  expect(out.text).toContain('No installer here, so nothing was checked')
  expect(out.text).toContain('plugin-only install')
  expect(seen.runs).toEqual([])
})

test('/mm-evidence lists the check commands of the turn and whether each exited 0', async ($, on) => {
  world(on, { tool: (e: any) => (e.command === 'npm run lint' ? { result: 'lint failed', isError: true, text: 'lint failed' } : { result: {} }) })
  expect((await $.command.run({ command: 'mm-evidence' })).text).toBe('No test, typecheck, lint, build or preflight command ran in the latest turn.')
  await runTurn($, [{ tool: 'Bash', command: 'npm test' }, { tool: 'Bash', command: 'npm run lint' }, { tool: 'Bash', command: 'ls' }], 'Ran them.')
  expect((await $.command.run({ command: 'mm-evidence' })).text).toBe('Check commands in the latest turn: 2 ran, 1 failed.\nexit 0   npm test\nFAILED   npm run lint')
  await runTurn($, [], 'Nothing.')
  expect((await $.command.run({ command: 'mm-evidence' })).text).toContain('No test')
})

test('a slash command that fails answers with the failure instead of going silent', async ($, on) => {
  world(on, {
    run: () => {
      throw new Error('spawn failed')
    },
  })
  expect((await $.command.run({ command: 'mm-next' })).text).toContain('/mm-next failed')
})

for (const surface of ['terminal', 'desktop'] as const) {
  test('band on ' + surface + ': one line with the facts of one `status --json` call, above what others draw', async ($, on) => {
    const seen = world(on, { surfaces: [surface] })
    on('ui.render', ($: any, e: any) => {
      const { Text } = $.ui.resolve(e)
      return Text({ children: ['theirs'] })
    })
    await $.session.start({ ...START, surface })
    const ui = await $.ui.mount({ ...BAND, surface })
    expect(await band($, ui, /field web/)).toBe('MasterMind · field web · 50 misses, last 2026-11-07 · next: blueprint (004-invitations)')
    expect(await ui.find({ type: 'Text', text: 'theirs' })).toBeDefined()
    expect(seen.runs).toEqual([[CLI, 'status', '--json']])
    expect(seen.status.filter((s) => s !== undefined)).toEqual([])
    await ui.unmount()
  })
}

test('band: a survey holding the band is left alone', async ($, on) => {
  world(on)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal', props: { ...BAND.props, hasSurvey: true } })
  expect(await ui.find({ type: 'Text', text: /MasterMind/ })).toBe(undefined)
  await ui.unmount()
})

test('band: with no CLI it says status unavailable and nothing fails', async ($, on) => {
  const seen = world(on, { files: [] })
  await $.session.start(START)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await band($, ui, /status unavailable/)).toBe('MasterMind · status unavailable')
  expect(seen.runs).toEqual([])
  await ui.unmount()
})

test('band: a CLI that answers garbage or an error reads as status unavailable', async ($, on) => {
  world(on, { run: () => ({ exitCode: 0, stdout: 'not json', stderr: '' }) })
  await $.session.start(START)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await band($, ui, /status unavailable/)).toBe('MasterMind · status unavailable')
  await ui.unmount()
})

test('VS Code has no band: the status line appears only when something needs attention', async ($, on) => {
  const seen = world(on, { surfaces: ['vscode'], run: (argv) => (argv[2] === '--json' ? { exitCode: 0, stdout: JSON.stringify({ ...STATUS, field: { name: null, level: 0 } }), stderr: '' } : cliRun(argv)) })
  await $.session.start({ ...START, surface: 'vscode' })
  await settle($, () => seen.status.some((s) => s !== undefined))
  expect(seen.status[seen.status.length - 1]).toBe('no field pack: say init · 50 misses, last 2026-11-07 · next: blueprint (004-invitations)')
})

test('VS Code: with a field pack and nothing wrong the status line stays clear', async ($, on) => {
  const seen = world(on, { surfaces: ['vscode'] })
  await $.session.start({ ...START, surface: 'vscode' })
  await settle($, () => seen.runs.length > 0 && seen.status.length > 0)
  expect(seen.status.filter((s) => s !== undefined)).toEqual([])
})

test('claude -p draws nowhere: no status line is set at all', async ($, on) => {
  const seen = world(on, { surfaces: [] })
  await $.session.start({ cwd: ROOT, surface: null, isInteractive: false })
  await settle($, () => seen.runs.length > 0)
  await $.session.measure({ context: { window: 200000, tokens: 190000, percent: 95 }, rateLimits: [], changed: ['context'] })
  expect(seen.status).toEqual([])
})

test('status refreshes after a turn that changed something, and not after one that only read', async ($, on) => {
  const seen = world(on, { tool: (e: any) => (e.tool === 'Bash' ? { result: {}, isReadOnly: true } : { result: {} }) })
  await runTurn($, [{ tool: 'Bash', command: 'ls' }, { tool: 'Read', file_path: ROOT + '/a.ts' }], 'It has two files.')
  expect(seen.runs).toEqual([])
  await runTurn($, [edit], 'Edited.\nnot checked: nothing')
  await settle($, () => seen.runs.length > 0)
  expect(seen.runs).toEqual([[CLI, 'status', '--json']])
})

test('handoff hint: one toast when context crosses the threshold, re-armed when it falls below', async ($, on) => {
  const seen = world(on)
  const at = (percent: number) => $.session.measure({ context: { window: 200000, tokens: percent * 2000, percent }, rateLimits: [], changed: ['context'] })
  await at(50)
  expect(seen.toasts).toEqual([])
  await at(72)
  await at(75)
  await at(90)
  expect(seen.toasts).toEqual(['context 72% full: say handoff, or run /handoff, to save the state of this work before it compacts'])
  await at(40)
  await at(71)
  expect(seen.toasts.length).toBe(2)
  expect(seen.logs).toEqual([])
})

test('handoff hint: the threshold is the setting, and 0 turns it off', { options: { handoffAt: 0 } }, async ($, on) => {
  const seen = world(on)
  await $.session.measure({ context: { window: 200000, tokens: 198000, percent: 99 }, rateLimits: [], changed: ['context'] })
  expect(seen.toasts).toEqual([])
})

test('handoff hint: a lower threshold fires sooner', { options: { handoffAt: 30 } }, async ($, on) => {
  const seen = world(on)
  await $.session.measure({ context: { window: 200000, tokens: 70000, percent: 35 }, rateLimits: [], changed: ['context'] })
  expect(seen.toasts.length).toBe(1)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await band($, ui, /context 35%/)).toContain('context 35%: say handoff')
  await ui.unmount()
})

test('verdict notice: an edit, a completion claim and no "not checked:" line give one line to the user', async ($, on) => {
  const seen = world(on)
  await runTurn($, [edit], 'Fixed the retry loop. Done.')
  expect(seen.logs).toEqual(['that answer says the work is finished but carries no verdict with a "not checked:" line. Ask "verdict?" before relying on it.'])
})

test('verdict notice: stays quiet on a read-only turn, an aborted turn, a subagent turn and a question', async ($, on) => {
  const seen = world(on, { tool: (e: any) => (e.command === 'ls -la' ? { result: {}, isReadOnly: true } : { result: {} }) })
  const reads = ['ls -la', 'cat README.md', 'git status', 'git diff HEAD~1', 'git log --oneline -5', 'rg TODO src', 'grep -rn foo .', 'find . -name "*.ts"']
  await runTurn($, reads.map((command) => ({ tool: 'Bash', command })), 'Done reading: it is finished and complete.')
  await runTurn($, [{ tool: 'Read', file_path: ROOT + '/a.ts' }, { tool: 'Grep', pattern: 'x' }], 'All done.')
  await runTurn($, [edit], 'Done.', { isAborted: true, reason: 'aborted' })
  await runTurn($, [edit], 'Done.', { reason: 'error' })
  await runTurn($, [edit], 'Done.', { agentId: 'agent-7' })
  await runTurn($, [edit], 'I changed the loop and it is done. Should I also update the tests?')
  expect(seen.logs).toEqual([])
})

test('verdict notice: Bash that changes something counts, `find -delete` included', async ($, on) => {
  const seen = world(on)
  await runTurn($, [{ tool: 'Bash', command: 'find . -name "*.bak" -delete' }], 'Cleaned up, all done.')
  await runTurn($, [{ tool: 'Bash', command: 'echo hi > out.txt' }], 'Implemented.')
  expect(seen.logs.length).toBe(2)
})

test('verdict notice: a refused or failed edit changed nothing', async ($, on) => {
  const seen = world(on, { tool: (e: any) => (e.old_string === 'a' ? { deny: 'not allowed' } : { result: 'no match', isError: true }) })
  await runTurn($, [edit, { ...edit, old_string: 'zz' }], 'Done.')
  expect(seen.logs).toEqual([])
})

test('verdict notice: nudge off silences it', { options: { nudge: 'off' } }, async ($, on) => {
  const seen = world(on)
  await runTurn($, [edit], 'Done. All tests pass.')
  await $.agent.spawn({ prompt: 'review the diff', description: 'review', subagentType: 'fork' } as any)
  expect(seen.logs).toEqual([])
})

test('evidence receipt: a reported check with no check command in the turn gives one line', async ($, on) => {
  const seen = world(on)
  await runTurn($, [edit], 'Updated the parser.\nDone: all tests pass, typecheck clean.\nnot checked: nothing')
  expect(seen.logs).toEqual(['that answer reports a check, but no test, typecheck, lint, build or preflight command has passed since the last change. /mm-evidence lists what ran this turn.'])
})

test('evidence receipt: quiet when a check command ran, in the main loop or a subagent', async ($, on) => {
  const seen = world(on)
  await runTurn($, [edit, { tool: 'Bash', command: 'npm test' }], 'Done: 37/37 tests pass.\nnot checked: nothing')
  await runTurn($, [edit, { tool: 'Bash', command: 'bash scripts/preflight.sh', agentId: 'agent-2' }], 'Done: verified.\nnot checked: nothing')
  expect(seen.logs).toEqual([])
})

test('evidence receipt: a check that ran after the latest change still stands in a later turn, until something changes again', async ($, on) => {
  const seen = world(on)
  await runTurn($, [edit, { tool: 'Bash', command: 'npm test' }], 'Edited and ran the suite.\nnot checked: nothing')
  await runTurn($, [], 'Yes: all tests pass.')
  expect(seen.logs).toEqual([])
  await runTurn($, [{ tool: 'Bash', command: 'npm test' }, edit], 'Updated again.\nDone: all tests pass.\nnot checked: nothing')
  expect(seen.logs.length).toBe(1)
  expect(seen.logs[0]).toContain('since the last change')
})

test('evidence receipt: a failed run is not evidence, and a session that changed nothing draws no receipt', async ($, on) => {
  const seen = world(on, { tool: (e: any) => (e.command === 'npm test' ? { result: 'red', isError: true } : { result: {} }) })
  await runTurn($, [], 'I verified the config has 3 keys.')
  expect(seen.logs).toEqual([])
  await runTurn($, [edit, { tool: 'Bash', command: 'npm test' }], 'Done: all tests pass.\nnot checked: nothing')
  expect(seen.logs.length).toBe(1)
})

test('a command that changes and then checks counts as both', async ($, on) => {
  const seen = world(on)
  await runTurn($, [{ tool: 'Bash', command: 'echo x > src/a.js && npm test' }], 'Done.')
  expect(seen.logs.length).toBe(1)
  expect((await $.command.run({ command: 'mm-evidence' })).text).toContain('1 ran, 0 failed')
  await runTurn($, [{ tool: 'Bash', command: 'rm tests/old.test.js' }], 'Removed it; tests pass.\nnot checked: nothing')
  expect(seen.logs.length).toBe(2)
})

test('evidence receipt: plain prose about checks not run does not trip it', async ($, on) => {
  const seen = world(on)
  await runTurn($, [edit], 'Done, not fully checked.\nnot checked: the tests were not run and the change is not verified')
  expect(seen.logs).toEqual([])
})

test('delegation: running subagents are counted with their model or fork, resumed ones skipped', async ($, on) => {
  let n = 0
  world(on, { spawn: (e: any) => ({ model: e.fork ? 'inherit' : 'claude-sonnet-5', agentId: e.resume?.agentId ?? 'agent-' + (n += 1) }) })
  await $.agent.spawn({ prompt: 'map the modules', description: 'explore', subagentType: 'Explore' } as any)
  await $.agent.spawn({ prompt: 'try the other approach', description: 'side quest', subagentType: 'fork', fork: true } as any)
  await $.agent.spawn({ prompt: 'carry on', description: 'explore', subagentType: 'Explore', resume: { agentId: 'agent-9' } } as any)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await band($, ui, /agents/)).toContain('2 agents (claude-sonnet-5, fork)')
  await $.turn.complete({ turnId: 'sub-1', answer: 'mapped', durationMs: 1, isAborted: false, reason: 'answer', agentId: 'agent-1' })
  expect(await band($, ui, /1 agent \(/)).toContain('1 agent (fork)')
  await ui.unmount()
})

test('delegation: a denied spawn is not counted', async ($, on) => {
  world(on, { spawn: () => ({ deny: 'no' }) })
  await $.agent.spawn({ prompt: 'x', description: 'x', subagentType: 'Explore' } as any).catch(() => undefined)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /agent/ })).toBe(undefined)
  await ui.unmount()
})

test('delegation: a review sent to a fork gets the clean-context line; other spawns do not', async ($, on) => {
  const seen = world(on)
  await $.agent.spawn({ prompt: 'map the modules', description: 'explore', subagentType: 'fork', fork: true } as any)
  await $.agent.spawn({ prompt: 'Review this diff against the requirement', description: 'code review', subagentType: 'mastermind:code-reviewer' } as any)
  expect(seen.logs).toEqual([])
  await $.agent.spawn({ prompt: 'Review this diff against the requirement', description: 'code review', subagentType: 'fork', fork: true } as any)
  expect(seen.logs).toEqual(['this reviewer is a fork. A fork inherits the context that wrote the work: not a clean-context review. The code-reviewer agent starts fresh.'])
})

test('kernel presence: no loaded instruction file holds the kernel, so the band says how to fix it', async ($, on) => {
  const seen = world(on, { files: [] })
  const blocks = [{ name: 'claudeMd', text: '# My project' }]
  const files = [{ path: ROOT + '/CLAUDE.md', kind: 'project', content: '# My project\nUse tabs.' }]
  const out = await $.prompt.context({ blocks, instructionFiles: files } as any)
  expect(out.blocks).toEqual(blocks)
  expect(out.instructionFiles).toEqual(files)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await band($, ui, /kernel/)).toBe('MasterMind · kernel not loaded: run npx mastermind-brain · reading status')
  expect(seen.debug).toEqual(['mastermind-mod: kernel not loaded (instruction files)'])
  await ui.unmount()
})

test('kernel presence: a loaded instruction file with the kernel heading, imports included, is enough', async ($, on) => {
  world(on)
  const files = [
    { path: ROOT + '/.claude/CLAUDE.md', kind: 'project', content: '@.mastermind/CLAUDE.md' },
    { path: ROOT + '/.mastermind/CLAUDE.md', kind: 'project', content: KERNEL, parent: ROOT + '/.claude/CLAUDE.md' },
  ]
  await $.prompt.context({ blocks: [], instructionFiles: files } as any)
  await $.prompt.context({ blocks: [], instructionFiles: [] } as any)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /kernel not loaded/ })).toBe(undefined)
  await ui.unmount()
})

test('kernel presence: a kernel the session hook delivered counts, as in a plugin-only install', async ($, on) => {
  const seen = world(on, { files: [] })
  const row = { message: { type: 'user', role: 'user', isMeta: true, content: [{ type: 'text', text: '<mastermind-brain>\n' + KERNEL + '\n</mastermind-brain>' }] }, door: 'hook-context', origin: { kind: 'hook', event: 'SessionStart' }, uuid: 'u-1' }
  const other = { ...row, uuid: 'u-0', message: { ...row.message, content: [{ type: 'text', text: 'Lint runs on save.' }] } }
  await $.session.append(other as any)
  expect(seen.debug).toEqual([])
  const kept = await $.session.append(row as any)
  expect(kept.message.content).toEqual(row.message.content)
  await $.prompt.context({ blocks: [], instructionFiles: [] } as any)
  expect(seen.debug).toEqual(['mastermind-mod: kernel loaded (session hook)'])
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /kernel not loaded/ })).toBe(undefined)
  await ui.unmount()
})

test('kernel presence: unknown files (a hook above rewrote the text) decide nothing', async ($, on) => {
  const seen = world(on)
  await $.prompt.context({ blocks: [] } as any)
  expect(seen.debug).toEqual([])
})
