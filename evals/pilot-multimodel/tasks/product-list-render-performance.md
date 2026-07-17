---
id: product-list-render-performance
domain: frontend
difficulty: medium
---

## Prompt

This page renders 10,000 products and lags badly on every keystroke in the filter box. It also has a subtle bug: after visiting the page, the ORIGINAL products array elsewhere in the app appears reordered. Fix the performance and the bug without changing what the user sees.

```tsx
import { useState } from 'react';

type Product = { id: string; name: string; price: number; rating: number };

function Row({ product, onSelect }: { product: Product; onSelect: (id: string) => void }) {
  return (
    <li style={{ padding: 8, borderBottom: '1px solid #eee' }} onClick={() => onSelect(product.id)}>
      {product.name} — ${product.price} — {product.rating}★
    </li>
  );
}

export function ProductList({ products, onSelect }: { products: Product[]; onSelect: (id: string) => void }) {
  const [filter, setFilter] = useState('');
  const visible = products
    .sort((a, b) => b.rating - a.rating)
    .filter((p) => p.name.toLowerCase().includes(filter.toLowerCase()));
  return (
    <div>
      <input value={filter} onChange={(e) => setFilter(e.target.value)} />
      <ul>
        {visible.map((p, i) => (
          <Row key={i} product={p} onSelect={(id) => onSelect(id)} />
        ))}
      </ul>
    </div>
  );
}
```

Return the improved code and briefly note what each change fixes.

## Rubric

1. The props mutation bug is fixed: the products prop is no longer sorted in place (e.g. copied via [...products] or toSorted before sorting)
2. The sorted+filtered list is memoized (useMemo) with correct dependencies (products and filter), so it is not recomputed on unrelated re-renders
3. Rows use a stable unique key (product.id), not the array index
4. Row is wrapped in React.memo (or equivalent) AND receives a referentially stable onSelect (passed directly or via useCallback), so memoization actually prevents re-renders
5. Filtering behavior is unchanged: still case-insensitive substring match, still sorted by rating descending
6. The answer identifies that in-place sort mutated the caller's array (the stated reordering bug) rather than only addressing speed
