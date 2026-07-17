---
id: transfer-endpoint-hardening
domain: backend
difficulty: hard
---

## Prompt

Fix this Express + node-postgres money-transfer endpoint. `requireAuth` middleware has already set `req.userId` (verified). The `accounts` table is (id uuid PK, owner_id uuid, balance bigint /* minor units */). You may add tables/DDL (include it) and use transactions via `pool.connect()`.

```ts
app.post('/api/transfer', requireAuth, async (req, res) => {
  const { fromAccountId, toAccountId, amount } = req.body;
  const from = await pool.query('SELECT * FROM accounts WHERE id = $1', [fromAccountId]);
  if (from.rows[0].balance < amount) {
    return res.status(400).json({ error: 'insufficient funds' });
  }
  await pool.query('UPDATE accounts SET balance = balance - $1 WHERE id = $2', [amount, fromAccountId]);
  await pool.query('UPDATE accounts SET balance = balance + $1 WHERE id = $2', [amount, toAccountId]);
  res.json({ ok: true, newBalance: from.rows[0].balance - amount });
});
```

Requirements: this must be safe under concurrent duplicate requests and client retries, safe against malicious account ids and amounts, must never partially apply, must never overdraw, and must not leak information about accounts the caller does not own. Return the complete fixed handler plus any DDL.

## Rubric

1. Authorization: the handler verifies fromAccountId is owned by req.userId; failure returns the same status/body as 'account not found' (404-style), so the endpoint is not an oracle for which account ids exist.
2. Debit and credit execute in a single database transaction on one connection (BEGIN/COMMIT with ROLLBACK on error and the client released in finally) — no partial transfer is possible.
3. The check-then-debit race is eliminated: either SELECT … FOR UPDATE before the balance check inside the transaction, or an atomic conditional UPDATE … SET balance = balance - $1 WHERE id = $2 AND balance >= $1 with rowCount checked — the plain pre-read comparison no longer gates the debit.
4. Deadlock between concurrent A→B and B→A transfers is prevented by a deterministic lock order (e.g., lock both rows ordered by id) or by a single atomic statement — and the code/comment shows this is deliberate.
5. Amount validation rejects non-numbers, NaN/Infinity, zero, negatives, and non-integers (balances are integer minor units); amount is also bounds-checked (e.g., <= a max or Number.isSafeInteger) before hitting the DB.
6. fromAccountId === toAccountId is explicitly rejected (or made a safe no-op) — it can neither corrupt the balance nor self-deadlock.
7. Idempotency: an Idempotency-Key (or equivalent client token) is stored with a unique constraint inside the same transaction as the transfer, so a retried request performs the debit at most once and the duplicate returns the original outcome, not a second transfer or a 500.
8. A nonexistent toAccountId yields a clean 4xx with the transfer rolled back — verified via rowCount on the credit (or FK/constraint handling), never a committed dangling debit or an unhandled 500.
9. The response's newBalance is read from the database after the debit inside the transaction — not computed from the stale pre-transaction read — and errors return generic messages with no stack traces, SQL errors, or other accounts' balances.
10. Malformed bodies (missing fields, non-string ids, invalid uuid) return 400 before any query; no code path can throw on from.rows[0] being undefined.
