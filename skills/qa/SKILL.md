---
name: qa
description: Use after finishing a feature or fix to confirm it actually works, when the user says "test this", "does it work", "verify this", "QA it", or before shipping something that has never been driven end-to-end. Also when the user asks for tests to be written or wants to work test-first.
---

# QA: prove it works (verify by default, tests on request)

Proving a change works is **mandatory**: though the proof is rarely a test suite. Default to **verify**
(drive the real thing, watch what it does). Tests / TDD are a **project choice**: **offer them, don't
impose them.** After a build, the honest close is: *"Built it: want me to QA it? (I can verify it end-to-end,
and add tests / do it test-first if you want.)"*

## Mode 1: Verify (the default; always do this)

1. **Write the checklist before you look.** Turn the expected behavior into a short list of criteria
   that are **each individually checkable**: one line per criterion, phrased so the answer is met or
   not met, never "looks fine". Write it *before* exercising anything, because a list written while
   looking is a list that describes what you found. If you can't say what correct looks like, you
   can't verify it.

   Prefer criteria a person could count or observe over ones needing an opinion: *"a second submit
   while pending is rejected"* beats *"handles concurrency well."* This list is what you report
   against in step 5, and what makes "it works" mean something.
2. **Pick the lightest real check.** Drive the actual thing over reasoning about it: run the app and click
   the flow, hit the endpoint, run the script/CLI, render the component. Reuse the project's run/dev
   command; reach for harness the project already has.
3. **Happy path, then the edges that matter**: empty, null, error, loading, zero/one/many, unauthorized,
   malformed, offline/slow (`~/.mastermind/engineering/core/rigor.md`). Observe *actual* output and state.
4. **Check the invisible**: typecheck, lint, build; console/network for errors; for UI, keyboard + focus,
   contrast, no layout shift/regression nearby.
5. **Report with evidence**: what you ran and what you observed (command output, response, screenshot).
   State confidence plainly. Couldn't run a check? Say so; never present unrun work as verified.

**Found a bug?** Fix the **root cause** (or route to `debug` if it's not obvious), never suppress a symptom
to make a check pass. Verify against the **requirement**, not the code you just wrote (a hostile eye).

## Mode 2: Test-first / TDD (thorough by default; writing the files is the opt-in)

Writing a test suite is a heavy optional step: **offer it, get a yes, then write.** You're in Mode 2 only
because the user asked for tests / test-first, or said yes to the offer after a build. Inside it, test the
product **fully and in detail**: writing tests (even test-first) to *prove* behavior across the happy path
and every edge is good QA, not overreach.

**A test written for a bug must be proven against it**: the revert-proof in `debug` phase 6
(`~/.mastermind/skills/debug/SKILL.md`) is the rule; it applies unchanged here.

**Get the yes before the first file lands.** Name where the tests would live and what they'd cover,
*"Want these as tests? They'd go in `<path>` and cover `<happy path + the edges that matter>`."*: and write
nothing to disk before it. **Proportionality, not ceremony:** if the project already has a suite and the
change belongs in it, adding the case *is* the normal way to work: do it and say so; the gate is for
*starting* a suite, or putting test files in a repo that has none.

Then Red → Green → Refactor:

1. **Red**: one small failing test stating the next behavior (for a bug: a test that reproduces it). Watch
   it fail for the right reason.
2. **Green**: the **minimum** code to pass. No gold-plating.
3. **Refactor**: improve the design while green; loop.

Test **behavior/contracts, not internals** (brittle implementation tests are worse than none). Test names
read like the spec. Struggling to make a test pass cleanly? The design is probably wrong, listen to it.

**The two ways a green suite lies.** A *tautological* test recomputes the expected value the way the
code does: `expect(add(a, b)).toBe(a + b)` passes whatever `add` does, so the expected value has to
come from somewhere independent: a hand-worked example, the spec, a known-good output. A *horizontally
sliced* suite tests a layer in bulk before anything runs end to end, which verifies **imagined**
behavior, one thin vertical slice that actually executes is worth more than a wall of green.

> **And don't silently leave test files in the user's repo.** They were agreed before they were written, so
> nothing arrives as a surprise, but close the loop: say what now exists and confirm it stays, *"Tested it
> thoroughly; keeping these tests in `<path>` as coverage unless you'd rather I remove them."* Match the
> project: if it already has a suite, add to it; if it has none, don't impose one: the *files* are the
> user's call, even though the *testing* wasn't optional.

## Output
A plain verdict: works / doesn't: with the evidence and the edge cases exercised, plus any gaps you
couldn't cover (and why). If tests were written: note what they cover and confirm they stay, never write
or persist a test suite the user didn't agree to first. If the project's
**`cycle-report`** preference is on (`.mastermind/prefs.md`), also run the **`report`** skill to save a
durable write-up; default off, so by default the verdict stays in chat.
