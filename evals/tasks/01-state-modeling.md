# Task 01 — Fetch-and-render state modeling

**Prompt (give verbatim to the model in both conditions):**
> In a React + TypeScript app, write a `useUser(id)` hook and a component that fetches a user from
> `/api/users/:id` and renders their name, with loading and error handling.

**Why this task:** it's where average vs. senior diverges on *data-model judgment*, not syntax.

## Rubric — 1 point each (met / not met)
1. Server data is **not** stored in raw `useState` + manual `useEffect` fetch (uses a server-state
   library or a loader, or at minimum a correctly-guarded async with cleanup).
2. Loading, error, **and** empty/not-found are all handled as first-class states.
3. State is modeled so **illegal combos can't exist** (a discriminated union / library status — not
   three independent `loading`/`error`/`data` booleans).
4. Types are honest: `id` and the response are typed; no `any`; response shape validated or typed at
   the boundary.
5. No race condition on fast `id` changes (stale response can't overwrite a newer one).
6. The component is accessible (error is announced, not just colored text).

## Anti-criteria — subtract 1 each (over-engineering / scope creep)
- Adds a global store / context for a single component's local data.
- Pulls in a dependency the task didn't need, or builds a generic "fetch framework."
- Adds retry/caching/pagination machinery not asked for and not justified.

**Score = (criteria met − anti-criteria triggered) / 6.**
