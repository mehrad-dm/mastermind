# Task 04 — Consume an untrusted API boundary

**Prompt (verbatim, both conditions):**
> Write a function `getRates()` that fetches JSON from a third-party endpoint
> `https://api.example.com/rates` and returns a typed list of `{ code: string; rate: number }`. It'll be
> used in a production frontend.

**Why this task:** probes the "parse, don't trust" boundary discipline and error honesty — the class of
bug that ships silently.

## Rubric — 1 point each
1. **Validates** the response shape at runtime (Zod/valibot/manual guard) — does not `as` the JSON into
   the type and hope.
2. Handles the failure paths: non-OK HTTP status, network error, and malformed/unexpected body — none
   swallowed silently.
3. Return type is honest about failure (throws a typed error, or returns a result/union) — not a bare
   cast that can lie at runtime.
4. No secrets or API keys hardcoded client-side; no `any` in the returned type.
5. Doesn't create a request waterfall / calls the endpoint once.

## Anti-criteria — subtract 1 each
- Builds a generic HTTP client / retry framework unasked.
- Adds caching, an axios dependency, or config layers the task didn't require.

**Score = (met − anti) / 5.**
