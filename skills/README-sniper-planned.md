# sniper — planned, not shipped

> **Status: coming soon.** This is a design note, deliberately **not** a `skills/sniper/`
> directory. A skill directory is installed and auto-invocable the moment it exists, so
> shipping an empty one would let the model route real work to a skill that does nothing.
> It also carries no `SKILL.md`/`ABOUT.md`, which `check-integrity.mjs` requires.

## The problem it solves

The current loop puts the user in the review seat. MasterMind produces work, the user reads
it, finds the mistakes, and reports them back. That is the single most annoying part of using
it — the human becomes the test suite.

`sniper` is the answer to *"do it in one shot so I don't have to check it."*

## What it can honestly promise — and what it cannot

**The goal is near-zero mistakes — and near-zero is the honest word.** Zero is not something any
prompt layer can promise, and claiming it would make this project the thing it warns against: the
first time it shipped a bug, the claim would be worthless and so would every other claim beside it.

**What it promises is a moved boundary.** The checking happens *before* handoff instead of after.
Not "there are no mistakes" but "the mistakes I could find, I already found and fixed — here is
what I checked, and here is what I could not."

**And near-zero is a target you can actually chase.** Every loop the model closes itself is one you
don't. The measure of success is how rarely you have to send it back — tracked in `evals/`, not
asserted here. Ship it any other way and it is marketing.

## Shape

One invocation runs the full loop to green, without returning between phases:

1. **Scope** — restate the task and the acceptance bar. Stop and ask only if genuinely ambiguous.
2. **Implement** — to the same standard as `build`.
3. **Adversarially self-review** — a separate pass that tries to *break* the work, not confirm it.
   Fresh-eyes, not the author's eyes; the review that finds nothing is the suspicious one.
4. **Verify** — run it. Tests, types, build, and the actual behavior end to end.
5. **Loop on red** — findings feed back to (2). Repeat until clean or the budget is spent.
6. **Report the evidence** — what ran, what passed, what was fixed on the way, and explicitly
   **what was not verified**. That last part is what makes it trustworthy rather than confident.

## Why it isn't built yet

Three things should land first, or `sniper` is a confident wrapper around unmeasured behavior:

- **The eval gap.** Run M1 is N=2 with a single judge. Until the panel exists, "one shot" is a
  feeling, not a measurement — and this is exactly the skill whose value must be measured.
- **Skill-TDD.** The method exists (`skills/levelup/authoring.md`) and has been applied to zero
  skills. A skill that claims to remove human review must be the *first* one proven to change
  behavior, by watching an agent fail without it.
- **Enforcement over advice.** Every real defect caught in v0.25.0 was caught by something that
  *fails* — the integrity checks, the test suites, the push guard. Nothing was caught by prose
  telling the model to be careful. `sniper` needs a verification step that can actually go red,
  not a paragraph asking it to try hard.

Build it after those, and it is a real capability. Build it before, and it is a promise the
evidence does not support.
