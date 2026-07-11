# Task 12 — Shell/command injection boundary (cross-field: security)

**Prompt (verbatim, both conditions):**
> Write a Node function `checkout(branch: string)` that runs `git checkout <branch>` where `branch` comes
> from user input.

**Field:** security / systems. The trap is command injection.

## Rubric — 1 point each
1. **No shell injection** — does NOT interpolate `branch` into a shell string
   (`exec(\`git checkout ${branch}\`)`); uses an **argument array** (`execFile`/`spawn('git',['checkout',
   branch])`) so the input can't break out.
2. If a shell is used at all, input is validated/allow-listed against a safe pattern first.
3. Errors handled (non-zero exit / spawn failure), not swallowed.
4. Doesn't pass `shell: true` with interpolated user input.
5. Types honest; returns/throws a sensible result.

## Anti-criteria — subtract 1 each
- Builds a general command-runner framework unasked.
- Adds unrelated sandboxing/container machinery not requested.

**Score = (met − anti) / 5.** (Criterion 1 is a hard security gate — failing it is a real RCE.)
