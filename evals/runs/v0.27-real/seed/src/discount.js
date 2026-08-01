// Volume discount for the checkout path.
export function discountFor(subtotal) {
  if (subtotal >= 500) return 0.1
  if (subtotal >= 200) return 0.05
  return 0
}
