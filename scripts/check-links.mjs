#!/usr/bin/env node
/**
 * Freshness check for MasterMind's curated knowledge — keeps the curriculum honest.
 * Zero deps (Node 18+ global fetch). Run: `node scripts/check-links.mjs`.
 *
 * Scans the hand-authored field/core docs (NOT the vendored ui-ux-pro-max data, the
 * lab, or the generated ROUTER.md) and checks that every external site they point at
 * still resolves — full URLs and bare domains (v8.dev/blog). It deliberately does NOT
 * check `owner/repo` GitHub shorthand: that's indistinguishable from import paths
 * (`next/font`), lint rules (`react-hooks/exhaustive-deps`), and CSS values in prose,
 * and repos are already API-verified during `levelup`. Precision over recall — a noisy
 * checker gets ignored.
 *
 * Also warns when a curriculum's "verified as of YYYY-MM" note is older than 6 months
 * (a nudge to run `levelup refresh`). Meant for a SCHEDULED job, not a push gate:
 *   - exit 1  → at least one DEAD link (404/410/5xx/DNS) — needs a fix.
 *   - exit 0  → all good, or only BLOCKED (bot-gated) / STALE warnings.
 */
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const STALE_MONTHS = 6
const CONCURRENCY = 8
const TIMEOUT_MS = 12000
const UA = 'Mozilla/5.0 (compatible; MasterMind-linkcheck/1.0; +https://mastermind.mehrad.me)'

// TLDs we treat as real when a bare domain appears in prose (allowlist = fewer false hits).
const TLDS = 'com|dev|org|io|net|guru|gg|es|xyz'
const SKIP = ['/ui-ux-pro-max/', '/lab/', '/_template/', 'ROUTER.md']

// --- collect curated markdown files ------------------------------------------
const walk = (d) =>
  readdirSync(d, { withFileTypes: true }).flatMap((e) => {
    const p = join(d, e.name)
    if (SKIP.some((s) => p.includes(s))) return []
    if (e.isDirectory()) return walk(p)
    return e.name.endsWith('.md') ? [p] : []
  })

const files = walk(join(ROOT, 'engineering'))

// --- extract candidate links + staleness dates -------------------------------
const targets = new Map() // url -> Set(sourceFile)
const add = (url, file) => {
  if (!targets.has(url)) targets.set(url, new Set())
  targets.get(url).add(file.replace(ROOT + '/', ''))
}
const staleNotes = []

const FULL = /https?:\/\/[^\s)\]"'`<>·,;]+/g
// domain must be followed by a non-alphanumeric, so `navigator.connection` isn't read as `navigator.co`.
const BARE = new RegExp(`\\b((?:[a-z0-9-]+\\.)+(?:${TLDS}))(?![a-z0-9])(\\/[^\\s)\\]"'\`<>·,;]*)?`, 'gi')
const DATE = /verif\w*[^\n]*?(20\d\d)-(\d\d)/i

const clean = (u) => u.replace(/[.,;:]+$/, '') // trailing punctuation from prose

for (const f of files) {
  const text = readFileSync(f, 'utf8')
  for (const m of text.matchAll(FULL)) add(clean(m[0]), f)
  for (const m of text.matchAll(BARE)) add('https://' + clean(m[1] + (m[2] || '')), f)
  const d = text.match(DATE)
  if (d) staleNotes.push({ file: f.replace(ROOT + '/', ''), year: +d[1], month: +d[2] })
}

// --- check one URL -----------------------------------------------------------
async function check(url) {
  const opts = { redirect: 'follow', headers: { 'user-agent': UA }, signal: AbortSignal.timeout(TIMEOUT_MS) }
  try {
    let r = await fetch(url, { ...opts, method: 'HEAD' })
    if (r.status === 405 || r.status === 501 || r.status === 403) {
      // some servers reject HEAD or bots — retry with a light GET
      r = await fetch(url, { ...opts, method: 'GET', headers: { ...opts.headers, range: 'bytes=0-0' } })
    }
    if (r.status >= 200 && r.status < 400) return { url, kind: 'OK', status: r.status }
    if ([401, 403, 429].includes(r.status)) return { url, kind: 'BLOCKED', status: r.status }
    return { url, kind: 'DEAD', status: r.status }
  } catch (e) {
    const msg = String(e?.name === 'TimeoutError' ? 'timeout' : e?.cause?.code || e?.message || e)
    // DNS / connection failures are genuinely dead; timeouts are treated as transient warnings.
    if (msg === 'timeout') return { url, kind: 'BLOCKED', status: 'timeout' }
    return { url, kind: 'DEAD', status: msg }
  }
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
  const blocked = results.filter((r) => r.kind === 'BLOCKED')

  // staleness
  const now = new Date()
  const stale = staleNotes.filter((n) => (now.getFullYear() - n.year) * 12 + (now.getMonth() + 1 - n.month) > STALE_MONTHS)

  console.log(`\nMasterMind link check — ${urls.length} resources across ${files.length} curated files\n`)
  if (dead.length) {
    console.log(`✖ DEAD (${dead.length}) — fix these:`)
    for (const r of dead) console.log(`  ${String(r.status).padEnd(8)} ${r.url}\n           ← ${[...targets.get(r.url)].join(', ')}`)
    console.log('')
  }
  if (blocked.length) {
    console.log(`⚠ BLOCKED/transient (${blocked.length}) — reachable but bot-gated or slow; check by hand if unsure:`)
    for (const r of blocked) console.log(`  ${String(r.status).padEnd(8)} ${r.url}`)
    console.log('')
  }
  if (stale.length) {
    console.log(`◷ STALE (${stale.length}) — verified >${STALE_MONTHS} months ago; run \`levelup refresh\`:`)
    for (const s of stale) console.log(`  ${s.year}-${String(s.month).padStart(2, '0')}  ${s.file}`)
    console.log('')
  }
  if (!dead.length && !blocked.length && !stale.length) console.log('✓ all resources resolve and the curriculum is fresh.\n')
  else console.log(`Summary: ${results.filter((r) => r.kind === 'OK').length} ok · ${blocked.length} blocked · ${dead.length} dead · ${stale.length} stale.\n`)

  process.exit(dead.length ? 1 : 0)
}

run()
