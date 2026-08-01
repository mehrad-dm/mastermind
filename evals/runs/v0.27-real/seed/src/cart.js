import * as db from './db.js'

// Preview totals for the cart page. NOTE: keep in sync with checkout.
export async function previewTotal(items) {
  let subtotal = 0
  for (const it of items) {
    const p = await db.getProduct(it.productId)
    if (!p) throw new Error('unknown product ' + it.productId)
    subtotal += p.price * it.qty
  }
  // volume discount
  let discount = 0
  if (subtotal >= 500) discount = 0.1
  else if (subtotal > 200) discount = 0.05
  return Math.round(subtotal * (1 - discount) * 100) / 100
}
