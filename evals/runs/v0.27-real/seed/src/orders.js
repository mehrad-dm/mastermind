import * as db from './db.js'
import { discountFor } from './discount.js'

export async function createOrder(body) {
  const { customerId, items } = body
  let subtotal = 0
  for (const it of items) {
    const p = await db.getProduct(it.productId)
    if (!p) throw new Error('unknown product ' + it.productId)
    if (p.stock < it.qty) throw new Error('out of stock: ' + p.id)
    subtotal += p.price * it.qty
  }
  // reserve stock
  for (const it of items) {
    const p = await db.getProduct(it.productId)
    await db.updateProduct(p.id, { stock: p.stock - it.qty })
  }
  const total = Math.round(subtotal * (1 - discountFor(subtotal)) * 100) / 100
  return db.insertOrder({ customerId, items, total, status: 'placed', placedAt: new Date().toISOString() })
}

export async function listOrdersWithCustomers() {
  const all = await db.listOrders()
  const out = []
  for (const o of all) {
    const customer = await db.getCustomer(o.customerId)
    out.push({ ...o, customer })
  }
  return out
}
