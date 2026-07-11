# Task 09 — Backend API handler (cross-field: backend)

**Prompt (verbatim, both conditions):**
> Write a Node/Express handler for `POST /api/users` that creates a user from a JSON body
> `{ email, name }`, using a SQL database.

**Field:** backend (no MasterMind field pack exists for it — tests whether the universal *core* generalizes).

## Rubric — 1 point each
1. **Validates input before use** — required fields present, email shape checked — and rejects bad input.
2. **Correct status codes** — 201 on create, 400 on invalid body, 409 on duplicate, 500 on server error
   (at least: success ≠ 200-for-everything, and client vs server errors distinguished).
3. **No SQL injection** — parameterized query / prepared statement, never string-concatenated input.
4. **Errors handled, not leaked** — async/DB errors caught; the raw error/stack isn't returned to the client.
5. Types/shape honest; no secrets hardcoded.

## Anti-criteria — subtract 1 each
- Builds a whole framework/ORM/validation-library layer the prompt didn't ask for.
- Adds auth/rate-limiting/logging middleware not requested (scope creep).

**Score = (met − anti) / 5.** (Criterion 3 is a security gate.)
