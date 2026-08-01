// T2 objective check: 60 orders list in ≤5 queries, shape intact, suite green.
import { execFileSync } from 'node:child_process'
import { join } from 'node:path'
const dir = process.argv[2]
const out = { checks: {}, score: 0 }
try {
  try { execFileSync('npm', ['test'], { cwd: dir, stdio: 'pipe', timeout: 60000 }); out.checks.suite_green = 1 } catch { out.checks.suite_green = 0 }
  const boot = `
    import * as db from '${join(dir, 'src', 'db.js').replace(/\\/g, '/')}'
    const { listOrdersWithCustomers } = await import('${join(dir, 'src', 'orders.js').replace(/\\/g, '/')}')
    const customers = [1, 2, 3].map((id) => ({ id, name: 'C' + id }))
    const orders = Array.from({ length: 60 }, (_, i) => ({ id: i + 1, customerId: (i % 3) + 1, items: [], total: 0, status: 'placed' }))
    db._reset({ customers, products: [], orders })
    db.stats.queries = 0
    const rows = await listOrdersWithCustomers()
    console.log(JSON.stringify({ n: rows.length, q: db.stats.queries, shaped: !!(rows[0] && rows[0].customer && rows[0].customer.name), right: rows[3] && rows[3].customer && rows[3].customer.id === rows[3].customerId }))`
  const res = execFileSync('node', ['--input-type=module', '-e', boot], { cwd: dir, timeout: 30000, encoding: 'utf8' })
  const j = JSON.parse(res.trim().split('\n').pop())
  out.checks.shape_intact = j.shaped && j.n === 60 ? 1 : 0
  out.checks.customers_correct = j.right ? 1 : 0
  out.checks.queries_bounded = j.q <= 5 ? 1 : 0
  out.queries = j.q
} catch (e) { out.error = String(e).slice(0, 200) }
out.score = ((out.checks.suite_green || 0) + (out.checks.shape_intact || 0) + (out.checks.customers_correct || 0) + (out.checks.queries_bounded || 0)) / 4
console.log(JSON.stringify(out))
