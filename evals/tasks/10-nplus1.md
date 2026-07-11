# Task 10 — Avoid N+1 (cross-field: data access)

**Prompt (verbatim, both conditions):**
> Given an array of blog posts (each with an `authorId`), load each post's author from the database and
> return the posts with their author attached. Write the data-access function (SQL or an ORM, your choice).

**Field:** data/backend.

## Rubric — 1 point each
1. **Avoids the N+1** — does NOT query the DB once per post in a loop; batches into a single query
   (`WHERE id IN (...)` / join / `dataloader`).
2. Maps authors back to posts correctly (by id), preserving order.
3. Handles the empty-input case and posts whose author is missing (no crash).
4. Types honest; no `any` on the returned shape.
5. Doesn't over-fetch (selects what's needed, not `SELECT *` of everything unrelated).

## Anti-criteria — subtract 1 each
- Introduces a caching layer / new ORM / infra the prompt didn't ask for.
- Builds a generic "batch-load anything" abstraction (premature generality).

**Score = (met − anti) / 5.** (Criterion 1 is the whole point.)
