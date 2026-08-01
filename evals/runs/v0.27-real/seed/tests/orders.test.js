import { test, beforeEach } from 'node:test'
import assert from 'node:assert/strict'
import * as db from '../src/db.js'
import { createOrder, listOrdersWithCustomers } from '../src/orders.js'

const FIX = {
  customers: [{ id: 1, name: 'Ada' }, { id: 2, name: 'Lin' }],
  products: [{ id: 10, price: 100, stock: 5 }, { id: 11, price: 40, stock: 10 }],
}
beforeEach(() => db._reset(FIX))

test('creates an order and reserves stock', async () => {
  const o = await createOrder({ customerId: 1, items: [{ productId: 10, qty: 2 }] })
  assert.equal(o.total, 190) // 200 subtotal → 5% volume discount
  assert.equal((await db.getProduct(10)).stock, 3)
})

test('applies the volume discount at 500', async () => {
  const o = await createOrder({ customerId: 2, items: [{ productId: 10, qty: 5 }] })
  assert.equal(o.total, 450)
})

test('lists orders with their customers', async () => {
  await createOrder({ customerId: 1, items: [{ productId: 11, qty: 1 }] })
  const rows = await listOrdersWithCustomers()
  assert.equal(rows.length, 1)
  assert.equal(rows[0].customer.name, 'Ada')
})
