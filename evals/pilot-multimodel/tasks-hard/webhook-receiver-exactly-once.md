---
id: webhook-receiver-exactly-once
domain: backend
difficulty: hard
---

## Prompt

Harden this payment-webhook receiver (Express + node-postgres). The provider signs requests with HMAC-SHA256 over the raw body, sends headers `x-signature` (hex) and `x-timestamp` (unix seconds), retries any non-2xx response with at-least-once delivery, and each event has a unique `event.id`. Secrets can be rotated, so at any moment one or two secrets are active (`ACTIVE_SECRETS: string[]`). `sendReceiptEmail` is slow and can throw.

```ts
app.use(express.json());

app.post('/webhooks/payments', async (req, res) => {
  const sig = req.headers['x-signature'] as string;
  const expected = crypto
    .createHmac('sha256', ACTIVE_SECRETS[0])
    .update(JSON.stringify(req.body))
    .digest('hex');
  if (sig !== expected) {
    return res.status(401).send('bad signature, expected ' + expected);
  }
  const event = req.body;
  if (event.type === 'payment.succeeded') {
    await pool.query("UPDATE orders SET status = 'paid' WHERE id = $1", [event.orderId]);
    await sendReceiptEmail(event.orderId);
  }
  res.send('ok');
});
```

Requirements: correct signature verification, replay resistance, exactly-once business effect under provider retries and crashes, fast acknowledgment, and no information leaks. You may add DDL (include it) and an in-process queue/async worker sketch. Return the complete fixed route plus DDL.

## Rubric

1. The HMAC is computed over the raw request body bytes — express.raw() on this route or a rawBody capture via the json verify hook — not over JSON.stringify(req.body), whose re-serialization can differ from the wire bytes.
2. Signature comparison uses crypto.timingSafeEqual on equal-length buffers, with a length/format pre-check so mismatched lengths return 401 instead of throwing.
3. Verification iterates over all ACTIVE_SECRETS and accepts if any matches, so secret rotation cannot drop events.
4. Replay protection: x-timestamp is validated within a tolerance window (e.g., ±5 minutes) and is bound into the signed payload (or its use is otherwise justified); stale or missing timestamps are rejected before processing.
5. Idempotency is enforced in the database: event.id is inserted into a processed/inbox table with a unique constraint, and a conflict (duplicate delivery) short-circuits to a 2xx without re-running side effects — an in-memory Set is not accepted.
6. The duplicate-check insert and the order status update occur in the same database transaction, so a crash between them cannot record the event as processed without applying it (or apply it twice).
7. The email is decoupled from acknowledgment: the route returns 2xx after the transactional DB work, and sendReceiptEmail runs async (queued/outbox/fire-with-catch) so its failure or slowness can neither fail the webhook nor, on provider retry, re-run the DB update.
8. Unknown event types are acknowledged with 2xx (after signature verification) rather than 4xx/5xx, preventing endless provider retries.
9. Input hardening: malformed JSON or missing/mistyped event.id/orderId yields a controlled 400 without a crash, and the error path no longer leaks the expected signature or any secret material.
10. The order update verifies effect (rowCount checked; unknown orderId handled deliberately — logged/dead-lettered with a 2xx, or another documented policy), never a silent no-op treated as success without trace.
