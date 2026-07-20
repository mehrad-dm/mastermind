---
name: debug
description: Use when a bug isn't obvious, resists a quick fix, keeps coming back, or you're about to start guessing — "why is this broken", "this keeps happening", intermittent or flaky failures, a crash you can't explain, behaviour that makes no sense. Not for a typo or an obvious mistake.
---

# MasterMind — Debug

Hard bugs are lost by guessing and patching symptoms. This is the disciplined loop that finds the
actual cause. Bug: **$ARGUMENTS**. Grounded in `~/.mastermind/engineering/core/rigor.md` and `~/.mastermind/engineering/core/agent-loop.md`.

The cardinal rule: **understand the mechanism before you change a line.** A fix you can't explain is a
coincidence, not a fix.

## The six phases

1. **Reproduce deterministically.** Find the smallest reliable trigger and a check that goes red on the
   bug (a failing test, a script, a repro URL/steps). No repro → no fix; keep narrowing inputs until it
   fails on demand. This red check is also your definition of "fixed."

2. **Localize.** Bisect the space — git bisect across commits, binary-search the code path, add
   instrumentation/logs at boundaries. Read the *actual* code and the *actual* data/state at the
   failure point; don't theorize from memory. Narrow to the smallest region that still reproduces.

3. **Hypothesize.** List the credible causes (usually 2–4), ranked. State, for the top one, the exact
   mechanism: "X happens because Y is Z at line N." Reason from first principles and the runtime model,
   not from superstition.

4. **Test the hypothesis.** Prove or kill it with a targeted experiment — inspect the value, toggle the
   condition, add an assertion. Confirm the mechanism *before* fixing. If the experiment refutes it, go
   back to (3) with what you learned. Don't shotgun-change multiple things.

5. **Fix the root cause, not the symptom** (`~/.mastermind/engineering/core/rigor.md`). Address why the bad state was possible —
   ideally make it unrepresentable (types, invariants, a reshaped data structure so the edge case
   disappears — `~/.mastermind/engineering/core/mindset.md`). Never suppress an error to green the check.

6. **Verify + guard.** Confirm the red check now passes and nothing else broke (typecheck/lint/tests/
   build). **Add a regression test that would have caught this** — the bug must not be able to return
   silently. Show the evidence.

## After
Run **`levelup`** (capture) to record the class of bug and its lesson in the active field's
`lessons.md`, so MasterMind doesn't relearn it. Report: root cause, the fix, and the guard added.
