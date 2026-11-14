import { expect, test } from 'claude-code/testing'
import { irreversible } from '../hooks/irreversible.mjs'
import { claimsCompletion, hasVerdictLine, isCheckCommand, isReadOnlyBash, notices, reportsCheck } from '../hooks/signals.mjs'
import { BAND, KERNEL, NEXT_TEXT, ROOT, START, runTurn, settle, world } from './kit'

const ROUTINE = [
  'mastermind status --json',
  'mastermind next',
  'mastermind wrong-log',
  'mastermind skills',
  'mastermind skill build',
  'mastermind route "why is this slow?"',
  '.mastermind/bin/mastermind next',
  '~/.mastermind/bin/mastermind wrong-log --json',
  'node cli/bin/mastermind.mjs conflicts',
  'node scripts/check-links.mjs',
  'node scripts/check-integrity.mjs',
  'node scripts/lint-brain.mjs',
  'bash scripts/preflight.sh',
  'bash tests/install.test.sh',
  'bash tests/agent-surface.test.sh',
  'bash install.sh --check',
  'HOME=/tmp/sandbox MM_NO_NETWORK=1 bash install.sh --check',
  'git status',
  'git status --short',
  'git diff',
  'git diff --stat HEAD~1',
  'git log --oneline -5',
  'git add -A',
  'git add mod/ .claude-plugin/',
  'git commit -m "release: v0.34.0"',
  'git commit -m "fix: ask before git push --force"',
  'git switch -c dev/0.34',
  'git switch master',
  'git branch',
  'git branch --show-current',
  'git branch feature/x',
  'npx mastermind-brain check',
  'npx mastermind-brain',
  'npx mastermind-brain update',
  'claude plugin validate mod/.claude-plugin/plugin.json --strict',
  'claude plugin test mod',
]

test('compat: the hold stays out of the way of the commands MasterMind\'s skills and scripts run', async ($, on) => {
  world(on)
  expect(ROUTINE.filter((c) => irreversible(c) !== null)).toEqual([])
  for (const command of ROUTINE) expect((await $.tool.check({ tool: 'Bash', input: { command }, approver: 'person' } as any)).decision).toBe('allow')
})

test('compat: the hold fires on what prime directive 3 says to ask about, and says so in the kernel\'s words', async ($, on) => {
  world(on)
  const asked = async (input: any, tool = 'Bash') => (await $.tool.check({ tool, input, approver: 'person' } as any)) as { decision: string; reason: string }
  const push = await asked({ command: 'git push origin dev/0.34' })
  const publish = await asked({ command: 'npm publish' })
  const tag = await asked({ command: 'git push origin v0.34.0' })
  const remove = await asked({ command: 'rm -rf engineering' })
  const outside = await asked({ file_path: '/home/u/.mastermind/CLAUDE.md' }, 'Write')
  for (const out of [push, publish, tag, remove, outside]) {
    expect(out.decision).toBe('ask')
    expect(out.reason).toContain('approval once is not approval again')
    expect(out.reason.includes('\n')).toBe(false)
  }
  expect(push.reason).toContain('ask before push, publish or deploy')
  expect(publish.reason).toContain('ask before push, publish or deploy')
  expect(remove.reason).toContain('ask before deleting or overwriting what you did not create')
  expect(outside.reason).toContain('ask before writing outside the project')
})

test('compat: approval once is not approval again, so the same push asks every time', async ($, on) => {
  world(on)
  for (let i = 0; i < 3; i += 1) expect((await $.tool.check({ tool: 'Bash', input: { command: 'git push' }, approver: 'person' } as any)).decision).toBe('ask')
})

const VERDICTS = [
  'Done: the retry loop handles the expired token; `npm test` 37/37.\nnot checked: nothing\ndecided for you: nothing',
  '**Done, not fully checked**: fixed and typechecked.\n`not checked:` the Safari path\n`decided for you:` kept the old cache key',
  'Not done: the migration is blocked on a decision.\nnot checked: nothing\ndecided for you: nothing',
  'Wrong thing: the slow part is the query, not the render. Nothing is fixed yet.\nnot checked: the production data volume\ndecided for you: scope trimmed to the diagnosis',
  '🧠 verified ▸ 37/37 tests · typecheck ✓ · Done\n   not checked: nothing\n   decided for you: nothing',
]

test('compat: every verdict form the kernel defines is accepted, with the "decided for you:" line', async ($, on) => {
  const seen = world(on)
  const edit = { tool: 'Edit', file_path: ROOT + '/src/a.ts', old_string: 'a', new_string: 'b' }
  for (const answer of VERDICTS) {
    expect(hasVerdictLine(answer)).toBe(true)
    await runTurn($, [edit, { tool: 'Bash', command: 'npm test' }], answer)
  }
  expect(seen.logs).toEqual([])
})

test('compat: "Not done" and "Wrong thing" are not completion claims; "Done" without the line is', async () => {
  const changed = { changed: true, checks: [{ command: 'npm test', ok: true, agent: false }] }
  expect(claimsCompletion('Not done: blocked on the schema decision.')).toBe(false)
  expect(claimsCompletion('Wrong thing: this is not the problem worth solving.')).toBe(false)
  expect(notices('Not done: blocked on the schema decision.', changed, 1)).toEqual([])
  expect(notices('Wrong thing: the query is the slow part.', changed, 1)).toEqual([])
  expect(notices('Done: it works.', changed, 1).length).toBe(1)
  expect(notices('Done, not fully checked: it works as far as I took it.', changed, 1).length).toBe(1)
  expect(notices('Done: it works.\ndecided for you: nothing', changed, 1).length).toBe(1)
  expect(notices('Done: it works.', { changed: false, checks: [] }, 0)).toEqual([])
})

test('compat: verdict and claim wording as models really write it', async () => {
  for (const a of ['**Not checked**: nothing', '_not checked_: the Safari path', '`not checked:` nothing', '**not checked:** nothing']) expect([a, hasVerdictLine(a)]).toEqual([a, true])
  for (const a of ['The refactor is complete.', 'Implementation complete.', 'It now works.', 'Done.', 'All fixed.']) expect([a, claimsCompletion(a)]).toEqual([a, true])
  for (const a of ['It has not been fixed.', 'This is not fully done.', "It isn't quite done.", 'Here is what needs to be done next.', 'Verdict: Not *done*', 'Uses a fixed-width font.', "It hasn't been implemented."])
    expect([a, claimsCompletion(a)]).toEqual([a, false])
  for (const a of ['not fully verified', "I haven't verified this", 'make sure tests pass before merging', 'if tests pass, merge', 'on 11/11', 'step 3/3', '50/50 chance']) expect([a, reportsCheck(a)]).toEqual([a, false])
  for (const a of ['all tests are passing', '12 passed, 0 failed', 'type check passes', '24/24 tests', 'verified ▸ 37/37 tests']) expect([a, reportsCheck(a)]).toEqual([a, true])
})

test('compat: the kernel\'s closing line counts as a reported check, and its own gates count as check commands', async () => {
  expect(reportsCheck('🧠 verified ▸ 37/37 tests · typecheck ✓ · 2 issues found and fixed before handoff')).toBe(true)
  expect(reportsCheck('Done, not fully checked.\nnot checked: the change is not verified on Safari')).toBe(false)
  expect(reportsCheck('Changed 3 of the files on 2026/11/14.')).toBe(false)
  for (const c of ['bash scripts/preflight.sh', 'node scripts/check-links.mjs', 'bash tests/install.test.sh', 'npm test', 'npx tsc --noEmit', 'pnpm run lint', 'npm run build', 'claude plugin test mod', 'bash install.sh --check', 'cargo test', 'pytest -q'])
    expect([c, isCheckCommand(c)]).toEqual([c, true])
  for (const c of ['ls tests', 'cat scripts/preflight.sh', 'git status', 'mkdir -p tests/unit', 'echo test', 'git commit -m "add tests"'])
    expect([c, isCheckCommand(c)]).toEqual([c, false])
})

test('compat: reading the brain is not a change', async () => {
  for (const c of ['ls', 'cat a.md', 'git status', 'git diff', 'git log -3', 'rg kernel', 'grep -rn x .', 'find . -name "*.md"', 'mastermind next', '.mastermind/bin/mastermind wrong-log', 'git branch --show-current', 'ls 2>/dev/null | head -3', 'node --version'])
    expect([c, isReadOnlyBash(c)]).toEqual([c, true])
  for (const c of ['find . -name "*.bak" -delete', 'sed -i "" s/a/b/ f', 'echo x > f', 'git add -A', 'git commit -m x', 'npm install', 'rm f', 'git branch -D x', 'mastermind update', 'ls && touch f'])
    expect([c, isReadOnlyBash(c)]).toEqual([c, false])
})

test('compat: /mm-next is `mastermind next`, nothing added or removed', async ($, on) => {
  world(on)
  expect((await $.command.run({ command: 'mm-next' })).text).toBe(NEXT_TEXT)
})

test('compat: a project with no MasterMind install loads, answers and holds without an error', async ($, on) => {
  const seen = world(on, { files: [] })
  await $.session.start(START)
  expect((await $.command.run({ command: 'mm-status' })).text).toContain('status unavailable')
  for (const command of ['mm-wrong-log', 'mm-next']) expect((await $.command.run({ command })).text).toContain('no mastermind CLI')
  expect((await $.command.run({ command: 'mm-check' })).text).toContain('No installer here')
  expect((await $.command.run({ command: 'mm-evidence' })).text).toContain('No test')
  expect((await $.tool.check({ tool: 'Bash', input: { command: 'git push' }, approver: 'person' } as any)).decision).toBe('ask')
  expect(seen.runs).toEqual([])
  expect(seen.logs).toEqual([])
})

test('compat: a plugin-only install is told about the kernel only when the session hook did not deliver it', async ($, on) => {
  world(on, { files: [] })
  await $.session.append({ message: { type: 'user', role: 'user', isMeta: true, content: [{ type: 'text', text: KERNEL }] }, door: 'hook-context', origin: { kind: 'hook', event: 'SessionStart' }, uuid: 'u-2' } as any)
  await $.prompt.context({ blocks: [], instructionFiles: [] } as any)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  let line: any
  await settle($, async () => (line = await ui.find({ type: 'Text', text: /MasterMind/ })) !== undefined)
  expect(line.text.includes('kernel not loaded')).toBe(false)
  await ui.unmount()
})

test('compat: under claude -p the hooks run, nothing draws, and the hold defers', async ($, on) => {
  const seen = world(on, { surfaces: [] })
  await $.session.start({ cwd: ROOT, surface: null, isInteractive: false })
  expect((await $.tool.check({ tool: 'Bash', input: { command: 'git push' } } as any)).decision).toBe('allow')
  await runTurn($, [{ tool: 'Edit', file_path: ROOT + '/src/a.ts', old_string: 'a', new_string: 'b' }], 'ok')
  await settle($, () => seen.runs.length > 0)
  expect(seen.status).toEqual([])
})
