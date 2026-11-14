---
name: debug
description: "Use when a bug's cause is unknown: it resists a quick fix, keeps coming back, is intermittent, or you are about to guess. Not for a typo or an obvious mistake, not for slowness (`performance`)."
---

# MasterMind: Debug

Hard bugs are lost by guessing and patching symptoms. This is the disciplined loop that finds the
actual cause. Bug: **$ARGUMENTS**. Grounded in `~/.mastermind/engineering/core/rigor.md` and `~/.mastermind/engineering/core/agent-loop.md`.

The cardinal rule: **understand the mechanism before you change a line.** A fix you can't explain is a
coincidence, not a fix.

**When the user asked why, not for a fix,** run phases 1 to 4, report the mechanism, and stop. Phases
5 and 6 run when they ask for the fix (kernel → Question or request).

## The six phases

1. **Build the feedback loop. This phase is the skill**: the rest is mechanical once it exists.

   You need **one command you have already run at least once**, whose invocation and output you can
   paste. It has to be *red-capable* (it fails right now, because of this bug), *deterministic*,
   *fast enough to run repeatedly*, and *runnable by you without a human driving a UI*. Reach for the
   cheapest rung that gives you that: a failing test · a `curl` · a CLI invocation with a saved
   snapshot · a headless browser script · a replayed captured request · a throwaway harness · a
   property/fuzz loop · a bisection harness · a differential run against a known-good version.

   **No red-capable command, no phase 2.** If you catch yourself reading code to build a theory before
   that command exists, stop and go build it, theorising over a bug you cannot trigger is the single
   most expensive habit in debugging. This same command is your definition of "fixed."
   **If it still won't reproduce after honest effort:** stop: a bug you can't reproduce earns a fix only
   once it does, and never claim it's fixed. Ship instrumentation instead (logging/assertions at the suspect
   boundaries) so the next occurrence is diagnosable, state explicitly what you ruled out and how, and
   hand back with that evidence. "I couldn't reproduce it" is the honest answer, and usually a faster
   route to the real cause than three speculative patches.

2. **Localize.** Bisect the space: git bisect across commits, binary-search the code path, add
   instrumentation/logs at boundaries. Read the *actual* code and the *actual* data/state at the
   failure point rather than theorizing from memory. Narrow to the smallest region that still reproduces.

   Two localization moves that pay for themselves:
   - **Diff against a working sibling.** Find the closest thing in this codebase that does work, and
     list *every* difference: config, imports, call order, environment, without ruling any out as
     "can't matter". The bug is usually in the difference you dismissed.
   - **For multi-component paths** (CI → build → deploy, API → service → DB): log what *enters* and
     *exits* each boundary, run the red command once, and read off *which hop* corrupted it. One
     instrumented run beats five theories about the middle.

3. **Hypothesize.** List the credible causes (usually 2–4), ranked. State, for the top one, the exact
   mechanism: "X happens because Y is Z at line N." Reason from first principles and the runtime model,
   not from superstition.

4. **Test the hypothesis.** Prove or kill it with a targeted experiment: inspect the value, toggle the
   condition, add an assertion. Confirm the mechanism *before* fixing. If the experiment refutes it, go
   back to (3) with what you learned. Change one thing at a time. **Budget: three refuted
   hypotheses.** Three misses means the framing is wrong, not the ranking: stop generating candidates and
   widen the search: challenge an assumption you took on faith, distrust the reported symptom, or return
   to (2) and bisect harder (commits, environment, data) until the region shrinks.

   **Three attempted fixes that didn't hold means the architecture is the bug.** Not the fourth
   hypothesis, the frame. When a bug keeps sliding out from under working fixes, you're patching a
   layer that can't express the invariant: state owned in two places, an ordering nobody guarantees, a
   boundary that lets the bad value through. Stop fixing and say that. *"Three fixes held in isolation
   and failed in combination: this needs the ownership moved, not another patch"* is a finding, and a
   more valuable one than a fourth attempt.

   The same signals in **your own** drafting, caught before they cost a cycle: *"it's probably X"*
   (a hypothesis skipping its experiment), *"quick fix for now, investigate later"* (a symptom patch
   naming itself), *"let me try one more thing"* (the budget objecting). Each one means: back to the
   phase you were about to skip.

   Some phrases from your user are the same signal, arriving earlier: *"is that not happening?"* means
   you asserted without checking. *"stop guessing"* means you're proposing fixes without a mechanism.
   *"it's still broken"* after a confident fix means the reproduction never covered the real case.

5. **Fix the root cause, not the symptom** (`~/.mastermind/engineering/core/rigor.md`). Address why the bad state was possible,
   and make it unrepresentable where the design allows (types, invariants, a reshaped data structure so the edge case
   disappears, `~/.mastermind/engineering/core/mindset.md`). Never suppress an error to green the check.
   Before patching a function, search every caller of it. When several share the bug, fix it once,
   where they all pass through, not at the one caller that reported it.

6. **Verify + guard.** Confirm the red check now passes and nothing else broke (typecheck/lint/tests/
   build). **Add the guard that would have caught this**: an assertion or invariant at the boundary. A test
   case is offered under Suggested (not done), never written unasked. The bug must not be able to return silently. Show the evidence.

   **Prove the guard guards:** with the new test green, revert the fix, the test must go red, then
   restore. A guard that stays green without the fix is testing something else; thirty seconds here
   buys the only proof that the regression can't come back unseen.

## After
Report: root cause, the fix, and the guard added. When the bug taught a durable lesson about this
stack, run **`levelup`** (capture) to record its class in the active field's `lessons.md`.
