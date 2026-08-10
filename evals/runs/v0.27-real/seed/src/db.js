// Tiny in-memory data layer with a SQL-ish surface. `stats.queries` counts round-trips: 
// the ops team graphs this in production, so keep it accurate.
export const stats = { queries: 0 }

const customers = new Map()
const products = new Map()
const orders = new Map()
let orderSeq = 1

export function _reset(fixture = {}) {
  customers.clear(); products.clear(); orders.clear(); orderSeq = 1; stats.queries = 0
  for (const c of fixture.customers || []) customers.set(c.id, { ...c })
  for (const p of fixture.products || []) products.set(p.id, { ...p })
  for (const o of fixture.orders || []) { orders.set(o.id, { ...o }); orderSeq = Math.max(orderSeq, o.id + 1) }
}

async function trip() { stats.queries += 1; await new Promise((r) => setImmediate(r)) }

export async function getCustomer(id) { await trip(); const c = customers.get(id); return c ? { ...c } : null }
export async function getCustomers(ids) { await trip(); return ids.map((i) => customers.get(i)).filter(Boolean).map((c) => ({ ...c })) }
export async function getProduct(id) { await trip(); const p = products.get(id); return p ? { ...p } : null }
export async function updateProduct(id, patch) { await trip(); const p = products.get(id); if (!p) throw new Error('no product'); Object.assign(p, patch); return { ...p } }
export async function insertOrder(row) { await trip(); const id = orderSeq++; orders.set(id, { id, ...row }); return { id, ...row } }
export async function getOrder(id) { await trip(); const o = orders.get(id); return o ? { ...o } : null }
export async function updateOrder(id, patch) { await trip(); const o = orders.get(id); if (!o) throw new Error('no order'); Object.assign(o, patch); return { ...o } }
export async function listOrders() { await trip(); return [...orders.values()].map((o) => ({ ...o })) }
