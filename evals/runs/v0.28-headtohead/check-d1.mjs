import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
const dir = process.argv[2]
const out = { checks: {}, score: 0 }
try {
  try { execFileSync('npm', ['test'], { cwd: dir, stdio: 'pipe', timeout: 60000 }); out.checks.suite_green = 1 } catch { out.checks.suite_green = 0 }
  const boot = `
    import * as db from '${join(dir, 'src', 'db.js')}'
    const { createOrder } = await import('${join(dir, 'src', 'orders.js')}')
    const { previewTotal } = await import('${join(dir, 'src', 'cart.js')}')
    db._reset({ customers: [{ id: 1, name: 'A' }], products: [{ id: 10, price: 100, stock: 99 }, { id: 11, price: 50, stock: 99 }] })
    const items = [{ productId: 10, qty: 2 }]            // subtotal exactly 200, the drift point
    const p1 = await previewTotal(items)
    const o1 = await createOrder({ customerId: 1, items })
    const items2 = [{ productId: 11, qty: 7 }]           // 350, mid-band agreement
    const p2 = await previewTotal(items2)
    const o2 = await createOrder({ customerId: 1, items: items2 })
    console.log(JSON.stringify({ agree200: p1 === o1.total, agree350: p2 === o2.total }))`
  const res = execFileSync('node', ['--input-type=module', '-e', boot], { cwd: dir, timeout: 30000, encoding: 'utf8' })
  const j = JSON.parse(res.trim().split('\n').pop())
  out.checks.totals_agree = j.agree200 && j.agree350 ? 1 : 0
  const cart = readFileSync(join(dir, 'src', 'cart.js'), 'utf8')
  out.checks.ssot_fix = /from '.\/discount\.js'|from ".\/discount\.js"/.test(cart) ? 1 : 0
} catch (e) { out.error = String(e).slice(0, 200) }
out.score = ((out.checks.suite_green || 0) + (out.checks.totals_agree || 0) + (out.checks.ssot_fix || 0)) / 3
console.log(JSON.stringify(out))
