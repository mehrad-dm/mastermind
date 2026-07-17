---
id: document-endpoint-injection-idor
domain: backend
difficulty: medium
---

## Prompt

Security has flagged this Express endpoint from a document-storage app. Authentication middleware already runs before it and sets req.user = { id: number }. The db client supports parameterized queries as db.query(sql, [params]). Find and fix every problem — correctness and security — and return the corrected handler.

```js
app.get('/api/documents/:id', async (req, res) => {
  try {
    const rows = await db.query(
      `SELECT * FROM documents WHERE id = ${req.params.id}`
    );
    const doc = rows[0];
    res.json({ id: doc.id, title: doc.title, body: doc.body, owner_id: doc.owner_id });
  } catch (err) {
    res.status(500).json({ error: err.message, stack: err.stack, query: err.query });
  }
});
```

## Rubric

1. SQL injection is eliminated: the query uses parameterized placeholders (db.query('... WHERE id = ?', [id]) style), never string interpolation of request input
2. The IDOR is fixed: the handler verifies the document belongs to req.user.id (in the WHERE clause or an explicit ownership check) and denies access to other users' documents
3. Unauthorized access to an existing document and a truly missing document return an appropriate error status (404, or 403/404 pair) instead of crashing — the current code throws TypeError on rows[0].id when no row matches
4. The id parameter is validated (numeric/format check) with a 400 for malformed input, rather than passing arbitrary strings to the database
5. Error responses no longer leak internals: no err.message/stack/query in the 500 body (generic message; details go to server-side logging at most)
6. SELECT * is narrowed or the response is built from an explicit field allowlist so future sensitive columns are not exposed by default
