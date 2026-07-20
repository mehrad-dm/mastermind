---
name: qa
description: Use after finishing a feature or fix to confirm it actually works, when the user says "test this", "does it work", "verify this", "QA it", or before shipping something that has never been driven end-to-end. Also when the user asks for tests to be written or wants to work test-first.
---

# QA — prove it works (verify by default, tests on request)

Proving a change works is **never optional** — but that doesn't mean writing tests. Default to **verify**
(drive the real thing, watch what it does). Tests / TDD are a **project choice** — **offer them, don't
impose them.** After a build, the honest close is: *"Built it — want me to QA it? (I can verify it end-to-end,
and add tests / do it test-first if you want.)"*

## Mode 1 — Verify (the default; always do this)

1. **Define "works."** Restate the expected behavior + acceptance criteria in observable terms. If you
   can't say what correct looks like, you can't verify it.
2. **Pick the lightest real check.** Drive the actual thing over reasoning about it: run the app and click
   the flow, hit the endpoint, run the script/CLI, render the component. Reuse the project's run/dev
   command; don't build harness it doesn't have.
3. **Happy path, then the edges that matter** — empty, null, error, loading, zero/one/many, unauthorized,
   malformed, offline/slow (`~/.mastermind/engineering/core/rigor.md`). Observe *actual* output and state.
4. **Check the invisible** — typecheck, lint, build; console/network for errors; for UI, keyboard + focus,
   contrast, no layout shift/regression nearby.
5. **Report with evidence** — what you ran and what you observed (command output, response, screenshot).
   State confidence plainly. Couldn't run a check? Say so; never present unrun work as verified.

**Found a bug?** Fix the **root cause** (or route to `debug` if it's not obvious) — never suppress a symptom
to make a check pass. Verify against the **requirement**, not the code you just wrote (a hostile eye).

## Mode 2 — Test-first / TDD (thorough by default; keeping the files is the opt-in)

Test the product **fully and in detail** — writing tests (even test-first) to *prove* behavior across the
happy path and every edge is good QA, not overreach. Red → Green → Refactor:

1. **Red** — one small failing test stating the next behavior (for a bug: a test that reproduces it). Watch
   it fail for the right reason.
2. **Green** — the **minimum** code to pass. No gold-plating.
3. **Refactor** — improve the design while green; loop.

Test **behavior/contracts, not internals** (brittle implementation tests are worse than none). Test names
read like the spec. Struggling to make a test pass cleanly? The design is probably wrong — listen to it.

> **But don't silently leave test files in the user's repo.** After verifying, **ask what to keep:**
> *"Tested it thoroughly — want me to keep these tests as coverage, or remove them for now?"* Match the
> project: if it already has a suite, add to it; if it has none, don't impose one — the *files* are the
> user's call, even though the *testing* wasn't optional.

## Output
A plain verdict — works / doesn't — with the evidence and the edge cases exercised, plus any gaps you
couldn't cover (and why). If tests were written: note what they cover, then **ask whether to keep or
discard the test files** — never persist a test suite the user didn't agree to. If the project's
**`cycle-report`** preference is on (`.mastermind/prefs.md`), also run the **`report`** skill to save a
durable write-up; default off, so by default the verdict stays in chat.
