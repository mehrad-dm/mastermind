---
name: mastermind-verify
description: Confirm a change actually works by exercising it end-to-end and observing real behavior — the manual-QA counterpart to mastermind-tdd, no persistent test suite required. Use after finishing a task/feature to prove it works before calling it done, or when the project doesn't do automated tests. Skip when a test suite already covers the change (run that) or the diff has no runtime surface (docs, comments).
---

# MasterMind — Verify

Proving a change works is **never optional** — but that doesn't mean writing tests. This is the
disciplined way to QA a feature by *driving the real thing* and watching what it does. Writing
automated tests / adopting TDD is a **project choice — ask first** (`~/.mastermind/engineering/core/rigor.md`); verifying that it
works is not. "Looks right" is not verification.

## The loop

1. **Define "works."** Restate the expected behavior and the acceptance criteria — what the user asked
   for, in observable terms. If you can't say what correct looks like, you can't verify it.
2. **Pick the lightest real check.** Prefer driving the actual thing over reasoning about it: run the
   app and click the flow, hit the endpoint, run the script/CLI, render the component. Reuse the
   project's run/dev command; don't build harness the project doesn't have.
3. **Exercise the happy path — then the edges that matter.** Walk the intended flow, then the cases
   `rigor.md` names: empty, null, error, loading, zero/one/many, unauthorized, malformed input, offline/
   slow. Observe *actual* output and state, not what the code "should" do.
4. **Check the invisible.** Typecheck, lint, and build. Watch the console/network for errors and
   warnings. For UI: keyboard + focus, contrast, and no layout shift/regression in nearby areas.
5. **Report with evidence.** Show what you ran and what you observed (command output, the response, a
   screenshot). State confidence plainly. If you couldn't run a check (no environment), say so and fall
   back to the most rigorous manual trace available — never present unrun work as verified.

## Rules
- **Don't add tests, a test framework, or TDD to a project that has none unprompted** — offer them as a
  suggestion instead. Where the project *does* test, run its suite as part of step 2–4.
- Verify against the **requirement**, not the implementation you just wrote — a hostile reviewer's eye.
- Found a bug? Fix the **root cause** (or route to `mastermind-debug` if it's not obvious) — never
  suppress a symptom to make the check pass.

## Output
A plain verdict — works / doesn't, with the evidence — the edge cases exercised, and any gaps you
couldn't cover (with why). If the user wants this locked in permanently, offer `mastermind-tdd`.
