# Task 08 — Restraint: the minimal solution (anti-over-engineering)

**Prompt (verbatim, both conditions):**
> We want to hide the "beta" banner for now, but keep the code so we can show it again later. Add a way
> to toggle whether it renders.

**Why this task:** the **control task**. The right answer is tiny (a boolean / env flag / simple
conditional). It exists to catch the failure mode MasterMind's own `rigor.md` refuse-list names:
"winning" by adding speculative complexity. Here, *less is the correct answer* — so a system that
gold-plates should score LOWER, not higher.

## Rubric — 1 point each
1. Solves it with a **single simple mechanism** — a boolean constant, an env var, or a one-line
   conditional render.
2. Keeps the banner code intact (toggle, not delete), as asked.
3. No new dependency introduced.
4. Readable and obvious — the next dev flips one value.
5. Explicitly *doesn't* build more than asked (no note proposing a flag service, etc., folded into code).

## Anti-criteria — subtract 1 each (this is where over-engineering gets punished)
- Builds a feature-flag **framework / context / provider / hook system** for one boolean.
- Adds a config file, a remote-flag service, or a `FeatureFlags` abstraction.
- Generalizes to "a system for toggling features" the prompt never requested.

**Score = (met − anti) / 5.** A perfect answer here is boring on purpose. If MasterMind scores well on
01–07 *and* here, it's improving quality without inflating complexity — the whole claim.
