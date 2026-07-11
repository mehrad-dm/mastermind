# Task 13 — Resource cleanup on all paths (cross-field: systems)

**Prompt (verbatim, both conditions):**
> Write a function that opens a file, reads and transforms its contents, and writes the result to another
> file. Make sure file handles are always released, even on error.

**Field:** systems / correctness. The trap is a leaked handle on the error path.

## Rubric — 1 point each
1. **Handles are released on every path** — `try/finally` (or a with-resource / `using` / stream
   `pipeline`), so a throw mid-way still closes them. Not just a close on the happy path.
2. **Read AND write errors are handled**, not swallowed (they propagate or are dealt with deliberately).
3. No leak if the transform throws (the opened handle(s) still close).
4. Async is correct — awaited, no dangling promises; no partial/torn write left silently.
5. Types honest.

## Anti-criteria — subtract 1 each
- Builds a generic resource-manager/pool abstraction the prompt didn't ask for.
- Adds retry/streaming-framework machinery beyond the ask.

**Score = (met − anti) / 5.**
