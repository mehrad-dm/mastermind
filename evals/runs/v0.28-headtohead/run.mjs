import { execFile } from 'node:child_process'
import { mkdirSync, existsSync, readFileSync, writeFileSync, cpSync, rmSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
const HERE = dirname(fileURLToPath(import.meta.url))
const SEED = join(HERE, '..', 'v0.27-real', 'seed')
const RAW = join(HERE, 'raw')
const WORK = '/tmp/mm-h2h'; mkdirSync(WORK, { recursive: true })
const OURS = readFileSync('/Users/zed/Desktop/Projects/mastermind/skills/debug/SKILL.md', 'utf8')
const RIVAL = readFileSync(process.env.RIVAL_PATH, 'utf8')
const PROMPT = "Customers report the cart preview total sometimes disagrees with the final order total for the same items. It makes no sense to me: both use the same prices. Find the actual cause and fix it correctly."
const strip = (s) => s.replace(/^---[\s\S]*?---\n/, '')
const ARMS = { none: null, ours: strip(OURS), rival: strip(RIVAL) }
const sh = (cmd, args, opts) => new Promise((res) => {
  execFile(cmd, args, { maxBuffer: 32e6, ...opts }, (err, stdout, stderr) => res({ err, stdout: String(stdout||''), stderr: String(stderr||'') }))
})
const jobs = []
for (const arm of Object.keys(ARMS)) for (let r = 1; r <= 3; r++) jobs.push({ arm, r })
let active = 0; const q = [...jobs]
await Promise.all(Array.from({ length: 4 }, async () => {
  for (;;) {
    const j = q.shift(); if (!j) return
    const out = join(RAW, `${j.arm}-r${j.r}.json`)
    if (existsSync(out)) continue
    const dir = join(WORK, `${j.arm}-r${j.r}`)
    rmSync(dir, { recursive: true, force: true }); cpSync(SEED, dir, { recursive: true })
    if (ARMS[j.arm]) writeFileSync(join(dir, 'CLAUDE.md'), ARMS[j.arm])
    const { stdout } = await sh('claude', ['-p','--setting-sources','project,local','--model','opus','--permission-mode','acceptEdits','--max-turns','30','--output-format','json',PROMPT], { cwd: dir })
    let res; try { res = JSON.parse(stdout) } catch { res = { result: stdout } }
    writeFileSync(out, JSON.stringify(res, null, 1))
    const chk = await sh('node', [join(HERE, 'check-d1.mjs'), dir])
    writeFileSync(join(RAW, `${j.arm}-r${j.r}.score.json`), chk.stdout || '{"score":0}')
    console.log(`${j.arm} r${j.r} → ${JSON.parse(chk.stdout||'{}').score}`)
  }
}))
const agg = {}
for (const arm of Object.keys(ARMS)) {
  const ss = []
  for (let r = 1; r <= 3; r++) { const f = join(RAW, `${arm}-r${r}.score.json`); if (existsSync(f)) ss.push(JSON.parse(readFileSync(f,'utf8')).score) }
  agg[arm] = { n: ss.length, mean: +(ss.reduce((a,b)=>a+b,0)/(ss.length||1)).toFixed(2), scores: ss }
}
writeFileSync(join(HERE, 'SUMMARY.json'), JSON.stringify(agg, null, 2))
console.log(JSON.stringify(agg))
