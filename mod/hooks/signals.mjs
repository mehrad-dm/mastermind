// Pure text readers: what an answer claims, what a command is, what the status line says.
import { segments, unwrap } from './irreversible.mjs'

const KERNEL = /^#\s*MasterMind:/m
const VERDICT_LINE = /not checked[\s*_`]*:/i
const NOT_DONE = /\b(not|isn't|is not|wasn't|aren't|hasn't|haven't|has not|have not|never|nothing is|won't be|will not be|cannot be|can't be|needs to be|need to be|to be|what)\s+((yet|fully|quite|been|all|entirely|really)\s+)*[*_`]*(done|fixed|implemented|completed?|finished|shipped|ready)\b/gi
const CLAIM = /\b(done|fixed|implemented|completed?|finished|shipped|works now|now works|all set|ready to (use|merge|ship))\b(?![-`])/i
const UNVERIFIED = /\b(not|never|cannot be|can't be|could not be|couldn't be|isn't|wasn't|haven't|hasn't|didn't get|should be|must be|needs to be|to be|un)[\s-]*((yet|fully|independently|been|properly)\s+)*verified\b/gi
const HEDGED = /\b(if|once|when|until|unless|whether|make sure|ensure|before|no)\s+(the\s+|all\s+)?(tests?|checks?)\s+pass(es)?\b/gi
const CHECKED = /\b(tests?\s+(all\s+|now\s+|are\s+|is\s+)*(pass(es|ed|ing)?|green)|all\s+(\d+\s+)?(tests\s+)?(are\s+)?(pass(es|ed|ing)?|green)|\d+\s+passed|type-?\s?checks?\s+(is\s+|are\s+)?(clean|pass(es|ed)?|green)|lint(er|ing)?\s+(is\s+)?(clean|pass(es|ed)?|green)|build\s+(pass(es|ed)|succeed(s|ed)|is green)|verified)\b|(typecheck|lint|tests?|build)\s*✓/i
const RATIO = /\b(\d+)\/(\d+)\b(?!\/)\s*(tests?|checks?|specs?|assertions?|pass(ed|ing)?|green)\b/gi
const REVIEW = /\b(review(er|ers|ing|ed|s)?|audit|critique|double-check)\b/i

const SCRIPT_RUNS = new Set(['test', 'typecheck', 'type-check', 'lint', 'build', 'check', 'verify', 'preflight'])
const TOOLS = new Set(['vitest', 'jest', 'mocha', 'pytest', 'tsc', 'eslint', 'biome', 'ruff', 'mypy', 'pyright', 'rspec', 'phpunit', 'shellcheck'])
const BUILDERS = new Set(['cargo', 'go', 'make', 'just', 'gradle', 'mvn', 'dotnet', 'swift', 'deno'])
const VERBS = new Set(['test', 'check', 'clippy', 'build', 'vet', 'lint', 'verify'])
const SHELLS = new Set(['bash', 'sh', 'zsh', 'node', 'python', 'python3', 'ruby', 'deno', 'bun', 'tsx'])
const CHECK_FILE = /(^|\/)tests?\/[^/]+\.\w+$|\.test\.\w+$|\.spec\.\w+$|(^|\/)scripts\/(check|verify|preflight|lint)[\w.-]*$/

const READS = new Set(['ls', 'cat', 'head', 'tail', 'wc', 'pwd', 'echo', 'printf', 'rg', 'grep', 'egrep', 'fgrep', 'which', 'type', 'file', 'stat', 'du', 'df', 'whoami', 'uname', 'printenv', 'true', 'false', 'test', '[', '[[', 'cd', 'cut', 'tr', 'jq', 'diff', 'cmp', 'basename', 'dirname', 'realpath', 'readlink', 'nl', 'column', 'shasum', 'md5', 'uniq', 'sleep', 'export', 'ps', 'awk', 'read'])
const GIT_READS = new Set(['status', 'log', 'show', 'rev-parse', 'ls-files', 'ls-tree', 'blame', 'describe', 'shortlog', 'cat-file', 'merge-base', 'show-ref', 'grep'])
const BRAIN_READS = new Set(['status', 'skills', 'skill', 'agents', 'agent', 'route', 'wrong-log', 'conflicts', 'next'])
const LOOP_WORDS = new Set(['for', 'in', 'done', 'fi', 'esac', 'select', 'case'])

/** True when any loaded instruction file, or text a session hook added, holds the kernel heading. */
export const hasKernel = (texts) => texts.some((t) => KERNEL.test(String(t ?? '')))

export const hasVerdictLine = (answer) => VERDICT_LINE.test(String(answer ?? ''))

export const claimsCompletion = (answer) => CLAIM.test(String(answer ?? '').replace(NOT_DONE, ''))

export function isQuestion(answer) {
  const lines = String(answer ?? '').split('\n').map((l) => l.trim()).filter(Boolean)
  const last = (lines[lines.length - 1] ?? '').replace(/[\s*_`"')\]]+$/, '')
  return last.endsWith('?')
}

export function reportsCheck(answer) {
  const text = String(answer ?? '').replace(UNVERIFIED, '').replace(HEDGED, '')
  if (CHECKED.test(text)) return true
  RATIO.lastIndex = 0
  for (let m; (m = RATIO.exec(text)) !== null; ) if (m[1] === m[2] && Number(m[1]) > 0) return true
  return false
}

export const isReview = (text) => REVIEW.test(String(text ?? ''))

function reads(words) {
  const cmd = String(words[0]).split('/').pop()
  const args = words.slice(1)
  if (LOOP_WORDS.has(cmd)) return true
  if (args.length === 1 && /^(--version|-v|-V|--help|-h)$/.test(args[0])) return true
  if (READS.has(cmd)) return true
  if (cmd === 'find') return !args.some((a) => /^-(delete|exec|execdir|ok|okdir|fprint|fprintf|fls)$/.test(a))
  if (cmd === 'sed') return !args.some((a) => a.startsWith('--in-place') || /^-[A-Za-z]*i/.test(a))
  if (cmd === 'sort' || cmd === 'tree') return !args.some((a) => a === '-o' || a.startsWith('--output'))
  if (cmd === 'date') return !args.includes('-s')
  if (cmd === 'npm' || cmd === 'pnpm') return args[0] === 'ls' || args[0] === 'view'
  if (cmd === 'gh') return ['view', 'list', 'status', 'diff', 'checks'].includes(args[1])
  if (cmd === 'mastermind' || cmd === 'mastermind.mjs') return BRAIN_READS.has(args.find((a) => !a.startsWith('-')))
  if (cmd !== 'git') return false
  let i = 0
  while (i < args.length && args[i].startsWith('-')) i += args[i] === '-C' || args[i] === '-c' ? 2 : 1
  const sub = args[i]
  const rest = args.slice(i + 1)
  if (sub === 'diff') return !rest.some((a) => a.startsWith('--output'))
  if (GIT_READS.has(sub)) return true
  if (sub === 'branch' || sub === 'tag') return rest.every((a, n) => /^(-a|-r|-v|-vv|-l|--list|--all|--remotes|--show-current|--contains|--merged|--no-merged|--sort=.*)$/.test(a) || /^(-l|--list)$/.test(rest[n - 1] ?? ''))
  if (sub === 'remote') return rest.length === 0 || rest[0] === '-v' || rest[0] === 'get-url' || rest[0] === 'show'
  if (sub === 'config') return rest[0] === '--get' || rest[0] === '--list' || rest[0] === '-l'
  if (sub === 'stash' || sub === 'worktree') return rest[0] === 'list'
  return false
}

function checks(words) {
  const cmd = String(words[0]).split('/').pop()
  const args = words.slice(1)
  const pos = args.filter((a) => !a.startsWith('-'))
  if (cmd === 'npm' || cmd === 'pnpm' || cmd === 'yarn' || cmd === 'bun') {
    const script = String(pos[0] === 'run' ? pos[1] : pos[0]).split(':')[0]
    return SCRIPT_RUNS.has(script)
  }
  if (TOOLS.has(cmd)) return !args.some((a) => a === '--fix' || a === '--write' || a === 'format' || a === '--init')
  if (BUILDERS.has(cmd)) return VERBS.has(pos[0])
  if (cmd === 'claude') return pos[0] === 'plugin' && (pos[1] === 'validate' || pos[1] === 'test')
  if (cmd === 'node' && args.includes('--test')) return true
  if (SHELLS.has(cmd)) return pos.length > 0 && (CHECK_FILE.test(pos[0]) || (args.includes('--check') && /\.sh$/.test(pos[0])))
  return CHECK_FILE.test(String(words[0]))
}

/** Each step of a command as 'read', 'check' or 'change', in order. */
export function steps(command) {
  return segments(command).map((s) => {
    const words = unwrap(s.words)
    if (words === null) return 'change'
    if (words.length === 0) return 'read'
    if (checks(words)) return 'check'
    return !s.writes && reads(words) ? 'read' : 'change'
  })
}

/** True when every step of the command only reads: such a turn changed nothing. */
export const isReadOnlyBash = (command) => steps(command).every((s) => s === 'read')

/** True when a step of the command is a test, typecheck, lint, build or preflight run. */
export const isCheckCommand = (command) => steps(command).includes('check')

/**
 * The answer's shortfalls, as the lines the user is shown; empty when it holds up.
 * checksSinceChange: passing check commands run after the session's latest change, or null when
 * nothing has changed in the session yet.
 */
export function notices(answer, turn, checksSinceChange) {
  const out = []
  if (isQuestion(answer)) return out
  if (turn.changed && claimsCompletion(answer) && !hasVerdictLine(answer))
    out.push('that answer says the work is finished but carries no verdict with a "not checked:" line. Ask "verdict?" before relying on it.')
  if (checksSinceChange === 0 && reportsCheck(answer))
    out.push('that answer reports a check, but no test, typecheck, lint, build or preflight command has passed since the last change. /mm-evidence lists what ran this turn.')
  return out
}

/** What /mm-evidence prints for a turn. */
export function evidence(turn) {
  if (!turn.checks.length) return 'No test, typecheck, lint, build or preflight command ran in the latest turn.'
  const rows = turn.checks.map((c) => (c.ok ? 'exit 0   ' : 'FAILED   ') + c.command + (c.agent ? '   (in a subagent)' : ''))
  const failed = turn.checks.filter((c) => !c.ok).length
  return 'Check commands in the latest turn: ' + turn.checks.length + ' ran, ' + failed + ' failed.\n' + rows.join('\n')
}

/** True when the status line holds something the user should act on. */
export function needsAttention(facts, cfg) {
  const s = facts.status
  return facts.kernel === false || Boolean(s && s.field && s.field.name === null) || (cfg.handoffAt > 0 && (facts.percent ?? 0) >= cfg.handoffAt)
}

/** The one line the band and the status line show. */
export function statusLine(facts, cfg, agents) {
  const parts = ['MasterMind']
  const s = facts.status
  if (facts.kernel === false) parts.push('kernel not loaded: run npx mastermind-brain')
  if (!s) parts.push(s === null ? 'status unavailable' : 'reading status')
  else {
    parts.push(s.field && s.field.name ? 'field ' + s.field.name : 'no field pack: say init')
    if (s.misses && typeof s.misses.count === 'number')
      parts.push(s.misses.count + (s.misses.count === 1 ? ' miss' : ' misses') + (s.misses.last && s.misses.last.date ? ', last ' + s.misses.last.date : ''))
    if (s.next && s.next.skill) parts.push('next: ' + s.next.skill + (s.next.feature ? ' (' + s.next.feature + ')' : ''))
  }
  if (agents.length) parts.push(agents.length + (agents.length === 1 ? ' agent' : ' agents') + ' (' + [...new Set(agents)].join(', ') + ')')
  if (typeof facts.percent === 'number')
    parts.push('context ' + facts.percent + '%' + (cfg.handoffAt > 0 && facts.percent >= cfg.handoffAt ? ': run /handoff' : ''))
  return parts.join(' · ')
}
