// T1 objective check: cancel endpoint restores stock; double-cancel is safe; suite green.
import { execFileSync, spawn } from 'node:child_process'
import { join } from 'node:path'
const dir = process.argv[2]
const out = { checks: {}, score: 0 }
const PORT = 4600 + (process.pid % 200)
const req = async (method, path, body) => {
  const r = await fetch(`http://127.0.0.1:${PORT}${path}`, { method, body: body ? JSON.stringify(body) : undefined, headers: { 'content-type': 'application/json' } })
  return { status: r.status, body: await r.json().catch(() => null) }
}
try {
  try { execFileSync('npm', ['test'], { cwd: dir, stdio: 'pipe', timeout: 60000 }); out.checks.suite_green = 1 } catch { out.checks.suite_green = 0 }
  const srv = spawn('node', [join(dir, 'src', 'server.js')], { cwd: dir, env: { ...process.env, PORT }, stdio: 'ignore' })
  await new Promise((r) => setTimeout(r, 900))
  try {
    // fixture is module state: create via API from the clean boot (empty db), seed products first is impossible over HTTP,
    // so drive through db by a tiny bootstrap file executed in-process instead:
    srv.kill()
    const boot = `
      import * as db from '${join(dir, 'src', 'db.js').replace(/\\/g, '/')}'
      import('${join(dir, 'src', 'server.js').replace(/\\/g, '/')}').then(async ({ server }) => {
        db._reset({ customers: [{ id: 1, name: 'Ada' }], products: [{ id: 10, price: 100, stock: 5 }] })
        server.listen(${PORT}, async () => {
          const req = async (m, p, b) => { const r = await fetch('http://127.0.0.1:${PORT}' + p, { method: m, body: b ? JSON.stringify(b) : undefined, headers: { 'content-type': 'application/json' } }); return { status: r.status, body: await r.json().catch(() => null) } }
          const o = await req('POST', '/orders', { customerId: 1, items: [{ productId: 10, qty: 2 }] })
          const stockAfterOrder = (await db.getProduct(10)).stock
          const c1 = await req('POST', '/orders/' + o.body.id + '/cancel')
          const stockAfterCancel = (await db.getProduct(10)).stock
          await req('POST', '/orders/' + o.body.id + '/cancel')
          const stockAfterDouble = (await db.getProduct(10)).stock
          const unknown = await req('POST', '/orders/999/cancel')
          console.log(JSON.stringify({ ok: c1.status < 300, stockAfterOrder, stockAfterCancel, stockAfterDouble, unknownStatus: unknown.status }))
          process.exit(0)
        })
      })`
    const res = execFileSync('node', ['--input-type=module', '-e', boot], { cwd: dir, timeout: 30000, encoding: 'utf8' })
    const j = JSON.parse(res.trim().split('\n').pop())
    out.checks.cancel_restores_stock = j.ok && j.stockAfterOrder === 3 && j.stockAfterCancel === 5 ? 1 : 0
    out.checks.double_cancel_safe = j.stockAfterDouble === 5 ? 1 : 0
    out.checks.unknown_id_clean = j.unknownStatus >= 400 && j.unknownStatus < 500 ? 1 : 0
  } catch (e) { out.checks.endpoint_error = String(e).slice(0, 200) }
} catch (e) { out.error = String(e).slice(0, 200) }
out.score = ((out.checks.suite_green || 0) + (out.checks.cancel_restores_stock || 0) + (out.checks.double_cancel_safe || 0) + (out.checks.unknown_id_clean || 0)) / 4
console.log(JSON.stringify(out))
