#!/usr/bin/env node
// What a failed live session means. Kept apart from the scripts that spend model calls, so the
// rules can be tested on canned output: `node evals/classify.mjs --self-test`.
import { readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

// An account or service the harness cannot fix. No bare status number or "login": a session
// that discusses a 403 handler or a login form is doing its job.
export const ACCOUNT = new RegExp([
  'usage limit', 'rate[ _-]?limit', 'quota', 'credit balance', 'billing', 'overloaded',
  'not logged in', 'logged out', 'please (?:run )?/?log ?in', 'invalid api key', 'no api key',
  'authentication[ _](?:error|failed|required)', 'unauthorized', 'upgrade to (?:plus|pro)',
  'subscription (?:required|expired|inactive)', '(?:token|session|credentials?) (?:has |have |is |are )?expired',
  'not supported when using codex', 'invalid_request_error',
  '(?:status|error|code|http)[ :=]+(?:401|403|429)\\b', '\\b(?:401|403|429) (?:unauthorized|forbidden|too many requests)',
].join('|'), 'i')

const reason = (text) => {
  const hit = String(text).match(ACCOUNT)?.[0]
  return (hit || String(text).trim().split('\n')[0].slice(0, 60) || 'harness error').toLowerCase()
}

// Claude Code reports a failed call as records in its stream-json on stdout. Only those records
// and stderr are read, never what the model wrote. A run is an observation only when it exited 0
// and wrote a `result` record; the one exception is a session that ran out of turns, which exits 1
// after writing that record.
export function claudeInfra({ out = '', err = null, stderr = '' }) {
  if (err?.killed) return 'timed out'
  let records = 0
  let result = null
  for (const line of out.split('\n')) {
    let j
    try { j = JSON.parse(line) } catch { continue }
    if (!j || typeof j !== 'object') continue
    records++
    if (j.type === 'result') result = j
    if (j.type === 'result' && j.is_error && j.subtype !== 'error_max_turns') return reason(j.result ?? j.subtype ?? '')
    if (j.type === 'rate_limit_event' && j.rate_limit_info?.status === 'rejected') return 'rate limit'
    if (j.type === 'assistant' && (j.error || j.message?.model === '<synthetic>')) {
      const text = (j.message?.content ?? []).filter((c) => c.type === 'text').map((c) => c.text).join(' ')
      if (j.error || /^API Error/.test(text) || ACCOUNT.test(text)) return reason(`${j.error ?? ''} ${text}`)
    }
  }
  if (ACCOUNT.test(stderr)) return reason(stderr)
  if (!records && ACCOUNT.test(out)) return reason(out)
  const outOfTurns = result?.subtype === 'error_max_turns' && err?.code === 1 && !err.signal
  if (err && !outOfTurns) {
    const why = String(stderr).trim() ? `: ${reason(stderr)}` : ''
    return `claude exited ${err.signal ?? err.code ?? '?'}${why}`
  }
  if (!result) return records ? 'no result record' : out.trim() ? 'stdout is not stream-json' : 'no output'
  return null
}

// Which skill a Claude Code session reached. A fired skill is the Skill tool call. A user-only
// skill cannot be fired, so reaching it means opening its file from the kernel's menu: `menu:<name>`.
export function observed(raw, known, userOnly) {
  const viaMenu = (name) => (userOnly.has(name) ? `menu:${name}` : name)
  let memoryWrite = false
  let opened = null
  let text = ''
  for (const line of raw.split('\n')) {
    let j
    try { j = JSON.parse(line) } catch { continue }
    for (const c of j?.message?.content || []) {
      if (c.type === 'text') text += c.text + '\n'
      if (c.type !== 'tool_use') continue
      if (c.name === 'Skill' && c.input?.skill) return c.input.skill
      if (/^(Write|Edit)$/.test(c.name) && /\/memory\//.test(c.input?.file_path || '')) memoryWrite = true
      const file = c.name === 'Read' ? (c.input?.file_path || '').match(/skills\/([a-z][a-z-]*)\/SKILL\.md$/)?.[1] : null
      const asked = c.name === 'Bash' ? (c.input?.command || '').match(/mastermind(?:\.mjs)? skill ([a-z][a-z-]*)/)?.[1] : null
      if (!opened && known.includes(file || asked)) opened = file || asked
    }
  }
  if (opened && userOnly.has(opened)) return `menu:${opened}`
  if (memoryWrite) return viaMenu('levelup')
  const m = text.slice(0, 1200).match(/└\s*`?([a-z][a-z-]*)`?/)
  return m && known.includes(m[1]) ? viaMenu(m[1]) : null
}

export function hit(c, got, userOnly) {
  if (c.neverAutoFires) return !userOnly.has(got)
  if (c.forbidden) return !c.forbidden.includes(got)
  return !!(got && c.expected.map((e) => (userOnly.has(e) ? `menu:${e}` : e)).includes(got))
}

// One live session judged: a run that could not run is never a hit, so a negative case cannot
// pass on a session that produced nothing.
export function outcome(c, run, known, userOnly) {
  const infra = claudeInfra(run)
  if (infra) return { got: null, infra, hit: false }
  const got = observed(run.out ?? '', known, userOnly)
  return { got, infra: null, hit: hit(c, got, userOnly) }
}

// A Codex or Cursor call that threw. stdout is the model's answer, so it only counts when the
// process failed without printing one.
export function cliFailure({ stdout = '', stderr = '', message = '', killed = false, code = null, signal = null }) {
  if (killed || code === 'ETIMEDOUT' || signal === 'SIGTERM') return { kind: 'could not run', why: 'timed out' }
  const logs = `${stderr}\n${message}`
  if (ACCOUNT.test(logs)) return { kind: 'account', why: reason(logs) }
  if (ACCOUNT.test(stdout)) return { kind: 'account', why: reason(stdout) }
  return { kind: 'could not run', why: reason(stderr || message || stdout) }
}

// What a Codex or Cursor call printed when it exited 0. An account message or nothing at all is
// not an answer, so it is thrown as the failure it is instead of being scored as a routing miss.
export function cliAnswer(stdout) {
  const text = String(stdout ?? '')
  if (!text.trim()) throw Object.assign(new Error('the CLI exited 0 and printed nothing'), { stdout: text })
  if (ACCOUNT.test(text)) throw Object.assign(new Error('the CLI exited 0 with an account message'), { stdout: text })
  return text
}

// MM_CODEX_MODEL wins; otherwise the first model the catalog lists for this account.
export function codexModel(env, catalog) {
  if (env.MM_CODEX_MODEL) return env.MM_CODEX_MODEL
  try {
    const models = JSON.parse(catalog).models ?? []
    return (models.find((m) => m.visibility === 'list') ?? models[0])?.slug ?? null
  } catch { return null }
}

// Codex 0.150 and later skips a project's AGENTS.md unless the project is trusted.
export const codexTrust = (dir) => ['-c', `projects={ ${JSON.stringify(dir)} = { trust_level = "trusted" } }`]

// One case, REPS runs of each arm. A run that could not run is in neither count.
export function tally(runs) {
  const ran = runs.filter((r) => !r.failed)
  return {
    reps: ran.length,
    hits: ran.filter((r) => r.hit).length,
    control: ran.filter((r) => r.control).length,
    failed: runs.length - ran.length,
  }
}

export function verdict(cases) {
  if (cases.some((c) => c.account)) return { code: 2, why: 'account or quota' }
  const missed = cases.filter((c) => c.reps > 0 && c.hits * 2 <= c.reps)
  if (missed.length) return { code: 1, why: `${missed.length} case(s) did not route` }
  if (cases.some((c) => c.failed > 0)) return { code: 2, why: 'some sessions could not run' }
  return { code: 0, why: 'every case routed' }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url) && process.argv.includes('--self-test')) {
  const fx = JSON.parse(readFileSync(join(dirname(fileURLToPath(import.meta.url)), '..', 'scripts', 'fixtures', 'eval-outputs.json'), 'utf8'))
  const wrong = []
  const same = (a, b) => JSON.stringify(a) === JSON.stringify(b)
  for (const c of fx.claude) {
    const got = claudeInfra({ out: c.stdout.join('\n'), stderr: c.stderr ?? '', err: c.err ?? null })
    if ((got !== null) !== c.infra) wrong.push(`claude: ${c.name}: wanted ${c.infra ? 'an infrastructure failure' : 'a routing observation'}, got ${JSON.stringify(got)}`)
    const quiet = outcome({ neverAutoFires: true }, { out: c.stdout.join('\n'), stderr: c.stderr ?? '', err: c.err ?? null }, fx.known, new Set())
    if (c.infra && quiet.hit) wrong.push(`claude: ${c.name}: a negative case passed on a session that could not run`)
  }
  for (const c of fx.answer) {
    let got = 'answer'
    try { cliAnswer(c.stdout) } catch (e) { got = cliFailure(e).kind }
    if (got !== c.kind) wrong.push(`answer: ${c.name}: wanted ${c.kind}, got ${got}`)
  }
  for (const c of fx.cli) {
    const got = cliFailure(c.error).kind
    if (got !== c.kind) wrong.push(`cli: ${c.name}: wanted ${c.kind}, got ${got}`)
  }
  for (const c of fx.model) {
    const got = codexModel(c.env, typeof c.catalog === 'string' ? c.catalog : JSON.stringify(c.catalog))
    if (got !== c.want) wrong.push(`model: ${c.name}: wanted ${c.want}, got ${got}`)
  }
  for (const c of fx.verdict) {
    const got = verdict(c.runs.map(tally).map((t, i) => ({ ...t, account: c.account?.[i] ?? false }))).code
    if (got !== c.code) wrong.push(`verdict: ${c.name}: wanted exit ${c.code}, got ${got}`)
  }
  for (const c of fx.observed) {
    const userOnly = new Set(c.userOnly)
    const got = observed(c.stdout.join('\n'), fx.known, userOnly)
    if (got !== c.got) wrong.push(`observed: ${c.name}: wanted ${c.got}, got ${got}`)
    if (c.case && hit(c.case, got, userOnly) !== c.hit) wrong.push(`hit: ${c.name}: wanted ${c.hit}`)
  }
  if (!same(codexTrust('/tmp/a b'), ['-c', 'projects={ "/tmp/a b" = { trust_level = "trusted" } }'])) wrong.push('trust: the override is not valid TOML')
  if (wrong.length) { console.error('✖ eval classifiers:\n  ' + wrong.join('\n  ')); process.exit(1) }
  const bad = fx.claude.filter((c) => c.infra).length + fx.cli.length + fx.answer.filter((c) => c.kind !== 'answer').length
  const good = fx.claude.length + fx.cli.length + fx.answer.length + fx.model.length + fx.verdict.length + fx.observed.length - bad
  console.log(`✓ eval classifiers: ${bad} bad inputs fire, ${good} good inputs stay clean (${fx.claude.length} Claude Code outputs, ${fx.cli.length} CLI failures, ${fx.answer.length} exit-0 answers, ${fx.model.length} model picks, ${fx.verdict.length} verdicts, ${fx.observed.length} session readings).`)
}
