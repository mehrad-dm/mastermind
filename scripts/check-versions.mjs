#!/usr/bin/env node

// One version, written in several files. Every release that drifted did so because one was
// moved by hand and another was not, and nothing looked until the tag was already pushed.

import { readFileSync, existsSync, mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = resolve(dirname(fileURLToPath(import.meta.url)), '..')

export function versionErrors(root) {
  const read = (rel) => (existsSync(join(root, rel)) ? readFileSync(join(root, rel), 'utf8') : null)
  const json = (rel) => { const t = read(rel); try { return t === null ? null : JSON.parse(t) } catch { return undefined } }
  const want = (read('VERSION') ?? '').trim()
  if (!/^\d+\.\d+\.\d+$/.test(want)) return [`VERSION holds "${want}", which is not major.minor.patch`]
  const out = []
  const expect = (where, got) => { if (got !== want) out.push(`${where} says ${got ?? 'nothing'}, VERSION says ${want}`) }
  const must = (rel) => {
    const j = json(rel)
    if (j === null) out.push(`${rel} is missing`)
    if (j === undefined) out.push(`${rel} is not valid JSON`)
    return j || null
  }

  const pkg = must('cli/package.json')
  if (pkg) expect('cli/package.json', pkg.version)
  const plugin = must('.claude-plugin/plugin.json')
  if (plugin) expect('.claude-plugin/plugin.json', plugin.version)
  const market = must('.claude-plugin/marketplace.json')
  if (market) {
    const entries = market.plugins ?? []
    if (!entries.length) out.push('.claude-plugin/marketplace.json lists no plugin')
    for (const p of entries) {
      expect(`.claude-plugin/marketplace.json plugin "${p.name}"`, p.version)
      for (const m of String(p.description ?? '').matchAll(/\(v(\d+\.\d+\.\d+)\)/g))
        expect(`.claude-plugin/marketplace.json description of "${p.name}"`, m[1])
    }
  }
  if (existsSync(join(root, 'mod'))) {
    const mod = must('mod/.claude-plugin/plugin.json')
    if (mod) expect('mod/.claude-plugin/plugin.json', mod.version)
    if (market && !(market.plugins ?? []).some((p) => p.name === mod?.name))
      out.push(`.claude-plugin/marketplace.json has no entry for the Mod ("${mod?.name}")`)
  }
  const readme = read('README.md') ?? ''
  const badges = [...readme.matchAll(/badge\/version-(\d+\.\d+\.\d+)-/g)].map((m) => m[1])
  if (!badges.length) out.push('README.md has no version badge')
  for (const b of badges) expect('README.md badge', b)
  for (const m of readme.matchAll(/(?:alt="version |Experimental \(v)(\d+\.\d+\.\d+)/g)) expect('README.md', m[1])
  return out
}

function selfTest() {
  const dir = mkdtempSync(join(tmpdir(), 'mm-versions-'))
  const write = (rel, text) => { mkdirSync(dirname(join(dir, rel)), { recursive: true }); writeFileSync(join(dir, rel), text) }
  const tree = (o = {}) => {
    rmSync(dir, { recursive: true, force: true })
    const v = (k) => o[k] ?? '1.2.3'
    write('VERSION', '1.2.3\n')
    write('cli/package.json', JSON.stringify({ version: v('cli') }))
    write('.claude-plugin/plugin.json', JSON.stringify({ name: 'mastermind', version: v('plugin') }))
    write('.claude-plugin/marketplace.json', JSON.stringify({ plugins: [
      { name: 'mastermind', version: v('market'), description: `A brain. Experimental (v${v('blurb')}).` },
      ...(o.noModEntry ? [] : [{ name: 'mastermind-mod', version: v('modEntry') }]),
    ] }))
    write('mod/.claude-plugin/plugin.json', JSON.stringify({ name: 'mastermind-mod', version: v('mod') }))
    write('README.md', `<img src="https://img.shields.io/badge/version-${v('badge')}-7c6bff" alt="version ${v('alt')}" />\n`)
    return versionErrors(dir)
  }
  const wrong = []
  if (tree().length) wrong.push(`fired on an agreeing tree: ${tree()[0]}`)
  for (const k of ['cli', 'plugin', 'market', 'blurb', 'modEntry', 'mod', 'badge', 'alt'])
    if (!tree({ [k]: '1.2.2' }).length) wrong.push(`did not fire when ${k} drifted`)
  if (!tree({ noModEntry: true }).length) wrong.push('did not fire when the Mod has no marketplace entry')
  rmSync(dir, { recursive: true, force: true })
  if (wrong.length) { console.error('✖ versions self-test:\n  ' + wrong.join('\n  ')); process.exit(1) }
  console.log('✓ versions self-test: eight drifted locations and a missing Mod entry each fire, an agreeing tree is clean.')
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.includes('--self-test')) selfTest()
  else {
    const errors = versionErrors(HERE)
    if (errors.length) {
      console.error(`✖ ${errors.length} version location(s) disagree:\n`)
      for (const e of errors) console.error('  ' + e)
      process.exit(1)
    }
    console.log(`✓ every version location says ${readFileSync(join(HERE, 'VERSION'), 'utf8').trim()}.`)
  }
}
