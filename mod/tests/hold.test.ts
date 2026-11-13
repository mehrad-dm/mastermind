import { expect, test } from 'claude-code/testing'
import { ROOT, world } from './kit'

const bash = (command: string, approver?: 'person' | 'host') => ({ tool: 'Bash', input: { command }, ...(approver ? { approver } : {}) })
const write = (tool: string, input: Record<string, string>, approver?: 'person') => ({ tool, input, ...(approver ? { approver } : {}) })

test('hold: an allowed push becomes an ask, with the reason the dialog shows', async ($, on) => {
  world(on, { check: () => ({ decision: 'allow', rule: 'Bash(git push:*)' }) })
  const out = await $.tool.check(bash('git push origin main', 'person'))
  expect(out.decision).toBe('ask')
  expect(out.reason).toContain('MasterMind hold: git push')
  expect(out.reason).toContain('ask before push, publish or deploy')
  expect(out.reason).toContain('approval once is not approval again')
})

test('hold: an ask the engine already made becomes the person\'s, with the MasterMind reason', async ($, on) => {
  world(on, { check: () => ({ decision: 'ask', reason: 'mode' }) })
  const out = await $.tool.check(bash('rm -rf src', 'person'))
  expect(out.decision).toBe('ask')
  expect(out.reason).toContain('ask before deleting or overwriting what you did not create')
})

test('hold: a host that answers permission prompts is asked too', async ($, on) => {
  world(on)
  expect((await $.tool.check(bash('npm publish', 'host'))).decision).toBe('ask')
})

test('hold: an engine deny comes back untouched', async ($, on) => {
  world(on, { check: () => ({ decision: 'deny', reason: 'a deny rule', rule: 'Bash(git push:*)' }) })
  const out = await $.tool.check(bash('git push -f', 'person'))
  expect(out.decision).toBe('deny')
  expect(out.reason).toBe('a deny rule')
  expect(out.rule).toBe('Bash(git push:*)')
})

test('hold: a harmless command keeps the engine\'s answer, and no path is looked up for it', async ($, on) => {
  const seen = world(on)
  for (const c of ['ls -la', 'git status', 'npm test', 'echo "git push"']) expect((await $.tool.check(bash(c, 'person'))).decision).toBe('allow')
  expect(seen.calls).toEqual([])
})

test('hold: it never answers allow for a held command while someone can be asked', async ($, on) => {
  let engine = 'allow'
  world(on, { check: () => ({ decision: engine }) })
  const held = ['git push', 'git push -f', 'git reset --hard', 'git clean -fd', 'git branch -D x', 'git checkout -- .', 'git restore .', 'rm -rf src', 'npm publish', 'vercel --prod', 'gh release create v1', 'gh pr merge 3', 'docker push a/b', 'terraform apply', 'kubectl delete pod x', 'psql -c "drop table x"']
  for (engine of ['allow', 'ask']) for (const c of held) expect((await $.tool.check(bash(c, 'person'))).decision).toBe('ask')
  engine = 'deny'
  for (const c of held) expect((await $.tool.check(bash(c, 'person'))).decision).toBe('deny')
})

test('hold: rm under the session temp directory or on a regenerable folder in the project is not held', async ($, on) => {
  world(on)
  expect((await $.tool.check(bash('rm -rf /var/folders/x/T/scratch', 'person'))).decision).toBe('allow')
  expect((await $.tool.check(bash('rm -rf ' + ROOT + '/node_modules', 'person'))).decision).toBe('allow')
  expect((await $.tool.check(bash('rm -rf /elsewhere/node_modules', 'person'))).decision).toBe('ask')
})

test('headless defer (the default): with nobody to ask, the permission rules decide', async ($, on) => {
  let engine = 'allow'
  world(on, { check: () => ({ decision: engine }) })
  expect((await $.tool.check(bash('git push'))).decision).toBe('allow')
  engine = 'ask'
  expect((await $.tool.check(bash('git push'))).decision).toBe('ask')
  expect((await $.tool.check(bash('git push'))).reason).toBe(undefined)
})

test('headless deny: with nobody to ask, the command is refused and the model reads why', { options: { headless: 'deny' } }, async ($, on) => {
  world(on)
  const out = await $.tool.check(bash('git push origin main'))
  expect(out.decision).toBe('deny')
  expect(out.reason).toContain('MasterMind hold: git push')
  expect((await $.tool.check(bash('ls'))).decision).toBe('allow')
  expect((await $.tool.check(bash('git push', 'person'))).decision).toBe('ask')
})

test('hold off: nothing is held', { options: { hold: 'off' } }, async ($, on) => {
  world(on)
  expect((await $.tool.check(bash('git push -f', 'person'))).decision).toBe('allow')
  expect((await $.tool.check(write('Write', { file_path: '/home/u/.zshrc' }, 'person'))).decision).toBe('allow')
})

test('hold destructive-only: plain push, publish and deploy pass; destructive commands still ask', { options: { hold: 'destructive-only' } }, async ($, on) => {
  world(on)
  for (const c of ['git push origin main', 'npm publish', 'vercel --prod', 'gh pr merge 3']) expect((await $.tool.check(bash(c, 'person'))).decision).toBe('allow')
  for (const c of ['git push --force', 'git reset --hard', 'rm -rf src', 'kubectl delete ns x']) expect((await $.tool.check(bash(c, 'person'))).decision).toBe('ask')
  expect((await $.tool.check(write('Write', { file_path: '/home/u/.zshrc' }, 'person'))).decision).toBe('ask')
})

test('an unknown setting value falls back to the safe default', { options: { hold: 'sometimes', headless: 'maybe' } }, async ($, on) => {
  world(on)
  expect((await $.tool.check(bash('git push', 'person'))).decision).toBe('ask')
  expect((await $.tool.check(bash('git push'))).decision).toBe('allow')
})

test('when the hold itself fails, a risky command is refused and a harmless one is not', async ($, on) => {
  world(on, {
    check: () => {
      throw new Error('boom')
    },
  })
  const risky = await $.tool.check(bash('git push', 'person')).catch((e: unknown) => ({ decision: 'thrown', reason: String(e) }))
  expect(risky.decision).toBe('deny')
  expect(risky.reason).toContain('hold failed')
  const calm = await $.tool.check(bash('ls -la', 'person')).catch((e: unknown) => ({ decision: 'thrown', reason: String(e) }))
  expect(calm.decision).toBe('thrown')
})

test('write hold: a write outside the project asks, in the kernel\'s words', async ($, on) => {
  world(on)
  const out = await $.tool.check(write('Write', { file_path: '/home/u/.zshrc' }, 'person'))
  expect(out.decision).toBe('ask')
  expect(out.reason).toContain('MasterMind hold: Write /home/u/.zshrc writes outside this project')
  expect(out.reason).toContain('ask before writing outside the project')
  expect((await $.tool.check(write('Edit', { file_path: '~/.gitconfig' }, 'person'))).decision).toBe('ask')
  expect((await $.tool.check(write('MultiEdit', { file_path: '/etc/hosts' }, 'person'))).decision).toBe('ask')
  expect((await $.tool.check(write('NotebookEdit', { notebook_path: '/home/u/n.ipynb' }, 'person'))).decision).toBe('ask')
})

test('write hold: inside the project, a new folder included, and under the temp directory are left alone', async ($, on) => {
  world(on)
  for (const file_path of [ROOT + '/src/a.ts', ROOT + '/new/dir/b.ts', ROOT + '/fresh.md', '/tmp/scratch/x.txt', '/var/folders/x/T/work/y.txt'])
    expect([file_path, (await $.tool.check(write('Write', { file_path }, 'person'))).decision]).toEqual([file_path, 'allow'])
})

test('write hold: a path that leaves the project through a link, a dangling link or ".." asks', async ($, on) => {
  world(on, { real: { [ROOT + '/linked']: '/elsewhere/real', [ROOT + '/dangling']: null } })
  expect((await $.tool.check(write('Write', { file_path: ROOT + '/linked/a.ts' }, 'person'))).decision).toBe('ask')
  expect((await $.tool.check(write('Write', { file_path: ROOT + '/dangling' }, 'person'))).decision).toBe('ask')
  expect((await $.tool.check(write('Write', { file_path: ROOT + '/nope/../../outside.txt' }, 'person'))).decision).toBe('ask')
})

test('write hold: Claude Code\'s own plan and memory files are left alone, its settings are not', async ($, on) => {
  world(on)
  expect((await $.tool.check(write('Write', { file_path: '/home/u/.claude/plans/next.md' }, 'person'))).decision).toBe('allow')
  expect((await $.tool.check(write('Write', { file_path: '/home/u/.claude/projects/-work-proj/memory/MEMORY.md' }, 'person'))).decision).toBe('allow')
  expect((await $.tool.check(write('Edit', { file_path: '/home/u/.claude/settings.json' }, 'person'))).decision).toBe('ask')
  expect((await $.tool.check(write('Edit', { file_path: '/home/u/.claude/CLAUDE.md' }, 'person'))).decision).toBe('ask')
})

test('write hold: headless follows the same setting as the command hold', { options: { headless: 'deny' } }, async ($, on) => {
  world(on)
  const out = await $.tool.check(write('Write', { file_path: '/home/u/.zshrc' }))
  expect(out.decision).toBe('deny')
  expect(out.reason).toContain('writes outside this project')
  expect((await $.tool.check(write('Write', { file_path: ROOT + '/src/a.ts' }))).decision).toBe('allow')
})
