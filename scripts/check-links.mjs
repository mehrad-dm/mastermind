#!/usr/bin/env node
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs'
import { join, resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const STALE_MONTHS = 6
const CONCURRENCY = 8
const TIMEOUT_MS = 12000
const UA = 'Mozilla/5.0 (compatible; MasterMind-linkcheck/1.0; +https://mastermind.mehrad.me)'

// TLDs we treat as real when a bare domain appears in prose (allowlist = fewer false hits).
const TLDS = 'com|dev|org|io|net|guru|gg|es|xyz'
const SKIP = ['/ui-ux-pro-max/', '/lab/', '/_', 'ROUTER.md']   // /_ skips all _-prefixed scaffolding

const EXCLUDE_DIRS = new Set(['.git', '.github', '.claude', '.cursor', '.agents', 'node_modules', '.eval-run', 'lab', 'private', 'local'])
const EXCLUDE_FILES = new Set(['CHANGELOG.md'])

// --- collect curated markdown files ------------------------------------------
const walk = (d) =>
  readdirSync(d, { withFileTypes: true }).flatMap((e) => {
    const p = join(d, e.name)
    if (SKIP.some((s) => p.includes(s))) return []
    if (e.isDirectory()) return EXCLUDE_DIRS.has(e.name) ? [] : walk(p)
    return e.name.endsWith('.md') && !EXCLUDE_FILES.has(e.name) ? [p] : []
  })

const MANIFESTS = ['.claude-plugin/plugin.json', '.claude-plugin/marketplace.json']
const files = [...walk(ROOT), ...MANIFESTS.map((m) => join(ROOT, m))]

// --- extract candidate links + staleness dates -------------------------------
const targets = new Map() // url -> Set(sourceFile)
const RESERVED = /^(?:https?:\/\/)?(?:[a-z0-9-]+\.)*(?:example\.(?:com|net|org)|localhost|invalid|test)(?:[:/]|$)/i
const add = (url, file) => {
  if (RESERVED.test(url)) return
  if (!targets.has(url)) targets.set(url, new Set())
  targets.get(url).add(file.replace(ROOT + '/', ''))
}
const staleNotes = []

const FULL = /https?:\/\/[^\s)\]"'`<>·,;]+/g
// domain must be followed by a non-alphanumeric, so `navigator.connection` isn't read as `navigator.co`.
const BARE = new RegExp(`\\b((?:[a-z0-9-]+\\.)+(?:${TLDS}))(?![a-z0-9])(\\/[^\\s)\\]"'\`<>·,;]*)?`, 'gi')
const DATE = /verif\w*[^\n]*?(20\d\d)-(\d\d)/i

const clean = (u) => u.replace(/[.,;:]+$/, '') // trailing punctuation from prose

const RELATIVE = /\[[^\]]*\]\((?!https?:|mailto:|#)([^)\s]+)\)/g
const brokenLocal = []

for (const f of files) {
  const text = readFileSync(f, 'utf8')
  for (const m of text.matchAll(FULL)) add(clean(m[0]), f)
  for (const m of text.matchAll(BARE)) add('https://' + clean(m[1] + (m[2] || '')), f)
  if (f.endsWith('.md')) {
    for (const m of text.matchAll(RELATIVE)) {
      const target = m[1].split('#')[0]
      if (!target) continue // pure anchor
      const abs = target.startsWith('/') ? join(ROOT, target) : resolve(dirname(f), target)
      if (!existsSync(abs)) brokenLocal.push({ file: f.replace(ROOT + '/', ''), target: m[1] })
    }
  }
  const d = text.match(DATE)
  if (d) staleNotes.push({ file: f.replace(ROOT + '/', ''), year: +d[1], month: +d[2] })
}

// --- check one URL -----------------------------------------------------------
// A redirect that only adds https, www, a trailing slash or a change of case is the same page.
const place = (u) => {
  const { host, pathname } = new URL(u)
  return (host.replace(/^www\./, '') + pathname.replace(/\/+$/, '')).toLowerCase()
}

async function check(url) {
  const opts = { redirect: 'follow', headers: { 'user-agent': UA }, signal: AbortSignal.timeout(TIMEOUT_MS) }
  try {
    let r = await fetch(url, { ...opts, method: 'HEAD' })
    if (r.status === 405 || r.status === 501 || r.status === 403) {
      // some servers reject HEAD or bots: retry with a light GET
      r = await fetch(url, { ...opts, method: 'GET', headers: { ...opts.headers, range: 'bytes=0-0' } })
    }
    if ([401, 403, 429].includes(r.status)) return { url, kind: 'BLOCKED', status: r.status }
    if (r.status < 200 || r.status >= 400) return { url, kind: 'DEAD', status: r.status }
    if (r.redirected && place(r.url) !== place(url)) return { url, kind: 'MOVED', status: r.status, to: r.url }
    return { url, kind: 'OK', status: r.status }
  } catch (e) {
    const msg = String(e?.name === 'TimeoutError' ? 'timeout' : e?.cause?.code || e?.message || e)
    const TRANSIENT = /^(timeout|ECONNRESET|ECONNREFUSED|ETIMEDOUT|EAI_AGAIN|EPIPE|UND_ERR_CONNECT_TIMEOUT|UND_ERR_SOCKET|CERT_|ERR_TLS|DEPTH_ZERO)/
    if (TRANSIENT.test(msg)) return { url, kind: 'BLOCKED', status: msg }
    return { url, kind: 'DEAD', status: msg }
  }
}

// 1 when something is wrong, 2 when nothing at all could be checked, else 0.
function exitCode(results, brokenLocal) {
  if (results.some((r) => r.kind === 'DEAD' || r.kind === 'MOVED') || brokenLocal.length) return 1
  return results.length && results.every((r) => r.kind === 'BLOCKED') ? 2 : 0
}

async function selfTest() {
  const { createServer } = await import('node:http')
  let port
  const server = createServer((req, res) => {
    const to = (location) => { res.writeHead(301, { location }); res.end() }
    const path = req.url.split('?')[0]
    if (path === '/ok' || path === '/new/' || path === '/slash/') { res.writeHead(200); res.end('ok') }
    else if (path === '/moved') to('/new/')
    else if (path === '/slash') to('/slash/')
    else if (path === '/other-host') to(`http://localhost:${port}/ok`)
    else if (path === '/blocked') { res.writeHead(403); res.end() }
    else { res.writeHead(404); res.end() }
  })
  await new Promise((r) => server.listen(0, r))
  port = server.address().port
  const want = { ok: 'OK', slash: 'OK', moved: 'MOVED', 'other-host': 'MOVED', blocked: 'BLOCKED', dead: 'DEAD' }
  const wrong = []
  for (const [path, kind] of Object.entries(want)) {
    const got = await check(`http://127.0.0.1:${port}/${path}`)
    if (got.kind !== kind) wrong.push(`/${path}: wanted ${kind}, got ${got.kind} (${got.status})`)
  }
  server.close()
  if (exitCode([{ kind: 'MOVED' }, { kind: 'OK' }], []) !== 1) wrong.push('a moved URL did not fail the run')
  if (exitCode([{ kind: 'BLOCKED' }, { kind: 'OK' }], []) !== 0) wrong.push('one unreachable URL failed a run that checked others')
  if (exitCode([{ kind: 'BLOCKED' }, { kind: 'BLOCKED' }], []) !== 2) wrong.push('a run that checked nothing did not report "could not check"')
  if (wrong.length) { console.error('✖ links self-test:\n  ' + wrong.join('\n  ')); process.exit(1) }
  console.log('✓ links self-test: a moved URL and a dead one fail, a blocked one is "could not check", a slash redirect is clean.')
  process.exit(0)
}

// --- run with a concurrency cap ----------------------------------------------
async function run() {
  const urls = [...targets.keys()].sort()
  const results = []
  let i = 0
  await Promise.all(
    Array.from({ length: Math.min(CONCURRENCY, urls.length) }, async () => {
      while (i < urls.length) results.push(await check(urls[i++]))
    }),
  )

  const dead = results.filter((r) => r.kind === 'DEAD')
  const moved = results.filter((r) => r.kind === 'MOVED')
  const blocked = results.filter((r) => r.kind === 'BLOCKED')

  // staleness
  const now = new Date()
  const stale = staleNotes.filter((n) => (now.getFullYear() - n.year) * 12 + (now.getMonth() + 1 - n.month) > STALE_MONTHS)

  console.log(`\nMasterMind link check: ${urls.length} resources across ${files.length} curated files\n`)
  if (dead.length) {
    console.log(`✖ DEAD (${dead.length}): fix these:`)
    for (const r of dead) console.log(`  ${String(r.status).padEnd(8)} ${r.url}\n           ← ${[...targets.get(r.url)].join(', ')}`)
    console.log('')
  }
  if (moved.length) {
    console.log(`✖ MOVED (${moved.length}): the page lives somewhere else now; cite the new address:`)
    for (const r of moved) console.log(`  ${r.url}\n        → ${r.to}\n           ← ${[...targets.get(r.url)].join(', ')}`)
    console.log('')
  }
  if (blocked.length) {
    console.log(`⚠ COULD NOT CHECK (${blocked.length}): bot-gated, rate-limited or timed out; these are unverified, not passed:`)
    for (const r of blocked) console.log(`  ${String(r.status).padEnd(8)} ${r.url}`)
    console.log('')
  }
  if (brokenLocal.length) {
    console.log(`✖ BROKEN FILE LINKS (${brokenLocal.length}): the target does not exist:`)
    for (const b of brokenLocal) console.log(`  ${b.target}\n           ← ${b.file}`)
    console.log('')
  }
  if (stale.length) {
    console.log(`◷ STALE (${stale.length}): verified >${STALE_MONTHS} months ago; run \`levelup refresh\`:`)
    for (const s of stale) console.log(`  ${s.year}-${String(s.month).padStart(2, '0')}  ${s.file}`)
    console.log('')
  }
  const code = exitCode(results, brokenLocal)
  const ok = results.filter((r) => r.kind === 'OK').length
  if (code === 2) console.log('· nothing could be checked from here, so no link was verified.\n')
  else if (!dead.length && !moved.length && !blocked.length && !stale.length && !brokenLocal.length)
    console.log('✓ all resources resolve and the curriculum is fresh.\n')
  else
    console.log(
      `Summary: ${ok} ok · ${moved.length} moved · ${dead.length} dead · ${brokenLocal.length} broken file links · ` +
        `${blocked.length} could not be checked · ${stale.length} stale.\n`,
    )

  process.exit(code)
}

if (process.argv.includes('--self-test')) selfTest()
else run()
