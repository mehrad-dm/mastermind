# Task 11 — Algorithm with edge-case traps (cross-field: algorithms)

**Prompt (verbatim, both conditions):**
> Write a function `median(nums: number[]): number` that returns the median of an array of numbers.

**Field:** algorithms / general correctness. Small, but full of edge traps.

## Rubric — 1 point each
1. **Empty input handled honestly** — throws or a documented sentinel, not a silent `NaN`/`undefined`
   pretending to be a number.
2. **Even length averages the two middle elements**; odd length returns the middle. (The classic bug is
   returning one middle element for even length.)
3. **Does not mutate the caller's array** (sorts a copy).
4. Sorts **numerically** (`(a,b)=>a-b`), not lexicographically (`[10,9].sort()` → `[10,9]` bug).
5. Typed honestly; reasonable complexity (O(n log n) sort is fine).

## Anti-criteria — subtract 1 each
- Pulls in a stats/lodash library for a one-function task.
- Over-generalizes (percentiles/quantile engine) beyond "median".

**Score = (met − anti) / 5.**
