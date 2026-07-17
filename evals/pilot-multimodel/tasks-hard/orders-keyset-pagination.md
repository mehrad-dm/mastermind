---
id: orders-keyset-pagination
domain: backend
difficulty: hard
---

## Prompt

Rework this Express + node-postgres endpoint into a correct, efficient, safe listing API. It must return only the authenticated user's orders (req.userId is set by requireAuth), support sorting by a small set of allowed columns, and use cursor (keyset) pagination — the product team has banned OFFSET because pages shift when new orders arrive. Response shape: `{ items: [...], nextCursor: string | null }`.

```ts
app.get('/api/orders', requireAuth, async (req, res) => {
  const { page = 1, limit = 20, sort = 'created_at' } = req.query as any;
  const offset = (page - 1) * limit;
  const orders = await pool.query(
    `SELECT * FROM orders ORDER BY ${sort} DESC LIMIT ${limit} OFFSET ${offset}`
  );
  const result = [];
  for (const o of orders.rows) {
    const user = await pool.query('SELECT name, email FROM users WHERE id = $1', [o.user_id]);
    const items = await pool.query('SELECT * FROM order_items WHERE order_id = $1', [o.id]);
    result.push({ ...o, user: user.rows[0], items: items.rows });
  }
  res.json(result);
});
```

Tables: orders(id uuid, user_id uuid, created_at timestamptz, total bigint, status text), order_items(id, order_id, sku, qty, price bigint), users(id, name, email). Many orders share the same created_at (bulk imports). Return the complete fixed handler.

## Rubric

1. SQL injection is eliminated: sort is validated against an explicit whitelist of column names (mapped, not interpolated raw), and limit/cursor values are parameterized or strictly validated numbers — no template interpolation of request data into SQL.
2. Tenant scoping added: the query filters WHERE user_id = $userId — the original endpoint's leak of all users' orders (including other users' emails) is closed.
3. The N+1 is removed: order_items and user data are fetched via a JOIN with aggregation or one batched `WHERE order_id = ANY($1)` query — total queries per request is O(1), not O(rows).
4. Ordering has a deterministic tiebreaker: ORDER BY created_at DESC, id DESC (both keys), so rows sharing a timestamp are never skipped or duplicated across pages.
5. Keyset pagination is real: the WHERE clause uses composite comparison ((created_at, id) < ($1, $2)) or the equivalent expanded boolean — no OFFSET anywhere, and the cursor carries both keys.
6. The cursor is opaque (e.g., base64 of the key tuple) and defensively decoded: a malformed/tampered cursor yields a 400, never a 500 or a SQL error.
7. hasMore/nextCursor is computed correctly, e.g., by fetching limit+1 rows and slicing: a final page with exactly `limit` rows returns nextCursor null on the next call, and no row is dropped at the boundary.
8. limit is clamped to a sane range (e.g., 1–100) with a default; non-numeric or negative limit cannot produce NaN or an unbounded query.
9. Timestamp precision in the cursor cannot skip rows: created_at round-trips at full precision (ISO string with microseconds or epoch micros from the DB), or correctness is independently guaranteed by the id tiebreak in the comparison — millisecond truncation of a timestamptz is not silently relied on.
10. An empty result set returns 200 with { items: [], nextCursor: null }, and the first page (no cursor supplied) works without a dummy sentinel value in the SQL.
