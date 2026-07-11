# Task 02 — Make illegal states unrepresentable

**Prompt (verbatim, both conditions):**
> Model the state of a checkout payment step in TypeScript: it can be idle, submitting, succeeded (with
> a confirmation id), or failed (with an error message). Write the type and a reducer.

**Why this task:** directly probes the "good taste = the special case disappears" principle — a data-model
decision an average answer gets subtly wrong with boolean/optional soup.

## Rubric — 1 point each
1. Uses a **discriminated union** keyed by `status` — not a bag of optionals
   (`{ submitting?: boolean; error?: string; id?: string }`).
2. The confirmation id exists **only** on the succeeded variant; the error **only** on the failed variant
   (you cannot construct a succeeded-with-an-error value).
3. The reducer's actions are typed, and transitions are explicit (no `default: return state` swallowing
   unknown actions silently).
4. No `any`, no non-null `!` to paper over the model; illegal transitions are unreachable or rejected.
5. Names reveal intent (`status`, variant names read as domain language).

## Anti-criteria — subtract 1 each
- Introduces a state-machine library for a 4-state reducer.
- Adds statuses/fields beyond the four requested.
- Over-generalizes into a reusable "async state" abstraction unasked.

**Score = (met − anti) / 5.**
