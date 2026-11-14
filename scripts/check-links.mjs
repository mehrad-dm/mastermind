#!/usr/bin/env node
import { readFileSync, readdirSync, existsSync, mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve, dirname, relative, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const STALE_MONTHS = 6
const CONCURRENCY = 8
const TIMEOUT_MS = 12000
const UA = 'Mozilla/5.0 (compatible; MasterMind-linkcheck/1.0; +https://mastermind.mehrad.me)'

// TLDs we treat as real when a bare domain appears in prose (allowlist = fewer false hits).
const TLDS = 'com|dev|org|io|net|guru|gg|es|xyz'
// Matched against the path inside the repository, so a checkout under a folder such as `_work/`
// is scanned like any other.
const SKIP = [/(^|\/)ui-ux-pro-max\//, /(^|\/)lab\//, /(^|\/)ROUTER\.md$/]

const EXCLUDE_DIRS = new Set(['.git', '.claude', '.cursor', '.agents', '.mastermind', 'node_modules', '.eval-run', 'lab', 'private', 'local'])
const EXCLUDE_FILES = new Set(['CHANGELOG.md'])
const MANIFESTS = ['.claude-plugin/plugin.json', '.claude-plugin/marketplace.json']

const RESERVED = /^(?:https?:\/\/)?(?:[a-z0-9-]+\.)*(?:example\.(?:com|net|org)|localhost|invalid|test)(?:[:/]|$)/i
const FULL = /https?:\/\/[^\s)\]"'`<>·,;]+/g
// domain must be followed by a non-alphanumeric, so `navigator.connection` isn't read as `navigator.co`.
const BARE = new RegExp(`\\b((?:[a-z0-9-]+\\.)+(?:${TLDS}))(?![a-z0-9])(\\/[^\\s)\\]"'\`<>·,;]*)?`, 'gi')
const DATE = /verif\w*[^\n]*?(20\d\d)-(\d\d)/i
const clean = (u) => u.replace(/[.,;:]+$/, '') // trailing punctuation from prose
const RELATIVE = /\[[^\]]*\]\((?!https?:|mailto:|#)([^)\s]+)\)/g
const ATTRIBUTE = /\b(?:src|href)=["']([^"']+)["']/g
const EXTERNAL = /^(?:[a-z][a-z0-9+.-]*:|#|\/\/)/i

// Every file link a Markdown page makes: `[text](path)` and an HTML `src` or `href`.
function localLinks(text) {
  const out = []
  for (const m of text.matchAll(RELATIVE)) out.push(m[1])
  for (const m of text.matchAll(ATTRIBUTE)) if (!EXTERNAL.test(m[1])) out.push(m[1])
  return out
}

function collect(root) {
  const rel = (p) => relative(root, p).split(sep).join('/')
  const walk = (d) =>
    readdirSync(d, { withFileTypes: true }).flatMap((e) => {
      const p = join(d, e.name)
      if (SKIP.some((s) => s.test(rel(p) + (e.isDirectory() ? '/' : '')))) return []
      if (e.isDirectory()) return EXCLUDE_DIRS.has(e.name) ? [] : walk(p)
      return e.name.endsWith('.md') && !EXCLUDE_FILES.has(e.name) ? [p] : []
    })
  const files = [...walk(root), ...MANIFESTS.map((m) => join(root, m)).filter((m) => existsSync(m))]
  const targets = new Map() // url -> Set(sourceFile)
  const add = (url, file) => {
    if (RESERVED.test(url)) return
    if (!targets.has(url)) targets.set(url, new Set())
    targets.get(url).add(rel(file))
  }
  const staleNotes = []
  const brokenLocal = []
  for (const f of files) {
    const text = readFileSync(f, 'utf8')
    for (const m of text.matchAll(FULL)) add(clean(m[0]), f)
    for (const m of text.matchAll(BARE)) add('https://' + clean(m[1] + (m[2] || '')), f)
    if (f.endsWith('.md')) {
      for (const link of localLinks(text)) {
        let target = link.split('#')[0].split('?')[0]
        try { target = decodeURI(target) } catch { /* left as written */ }
        if (!target) continue // pure anchor
        const abs = target.startsWith('/') ? join(root, target) : resolve(dirname(f), target)
        if (!existsSync(abs)) brokenLocal.push({ file: rel(f), target: link })
      }
    }
    const d = text.match(DATE)
    if (d) staleNotes.push({ file: rel(f), year: +d[1], month: +d[2] })
  }
  return { files, targets, staleNotes, brokenLocal }
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
  const box = mkdtempSync(join(tmpdir(), 'mm-links-'))
  const repo = join(box, '_work', 'mastermind')
  const put = (p, t) => { mkdirSync(dirname(join(repo, p)), { recursive: true }); writeFileSync(join(repo, p), t) }
  put('README.md', '[ok](docs/here.md) <img src="docs/gone.png"> [gone](docs/missing.md) <a href="https://example.com/x">x</a>\n')
  put('docs/here.md', '<img src="./here.md"> [anchor](#top) [mail](mailto:a@example.com)\n')
  put('engineering/fields/_template/field.md', '[gone](./missing-too.md)\n')
  put('lab/notes.md', '[gone](./skipped.md)\n')
  const found = collect(repo).brokenLocal.map((b) => `${b.file} ${b.target}`).sort()
  rmSync(box, { recursive: true, force: true })
  const wanted = ['README.md docs/gone.png', 'README.md docs/missing.md', 'engineering/fields/_template/field.md ./missing-too.md']
  if (JSON.stringify(found) !== JSON.stringify(wanted))
    wrong.push(`under a _work checkout the broken file links were ${JSON.stringify(found)}, wanted ${JSON.stringify(wanted)}`)
  if (wrong.length) { console.error('✖ links self-test:\n  ' + wrong.join('\n  ')); process.exit(1) }
  console.log(`✓ links self-test: ${2 + 3 + wanted.length} bad inputs fire, 5 good inputs stay clean (moved and dead URLs fail, a blocked one is "could not check", broken file links are found under a _work checkout).`)
  process.exit(0)
}

// --- run with a concurrency cap ----------------------------------------------
const { files, targets, staleNotes, brokenLocal } = process.argv.includes('--self-test') ? {} : collect(ROOT)

// Files in this repository only: nothing on the network, so a broken link here can fail a pull request.
function runLocal() {
  if (brokenLocal.length) {
    console.error(`✖ BROKEN FILE LINKS (${brokenLocal.length}): the target does not exist:`)
    for (const b of brokenLocal) console.error(`  ${b.target}\n           ← ${b.file}`)
    process.exit(1)
  }
  console.log(`✓ every file link resolves (${files.length} curated files; external links not checked by --local).`)
  process.exit(0)
}

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
else if (process.argv.includes('--local')) runLocal()
else run()
