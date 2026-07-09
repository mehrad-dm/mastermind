---
name: mastermind-tdd
description: Test-first loop — write a failing test, make it pass with the minimum, then refactor while green. Use for logic with clear inputs/outputs, for bug fixes (write the failing repro first), or when you want tests to pressure the design. Skip for throwaway spikes and pure-visual work.
---

# MasterMind — TDD

Red → Green → Refactor (Beck). Tests first isn't dogma — it's design pressure and a safety net that lets
you move fast without fear. Behavior, not implementation (`fields/frontend/stack-defaults.md` → Testing).

## The loop

1. **Red** — write ONE small failing test that states the next behavior you want (for a bug: a test that
   reproduces it). Run it; watch it fail for the right reason.
2. **Green** — write the **minimum** code to pass. No gold-plating, no speculative generality.
3. **Refactor** — with the test green, improve the design (deep modules, clear names) — behavior
   unchanged, tests still green. Then loop.

## Rules
- One test at a time; keep the suite green between steps.
- Test **behavior/contracts**, not internals — brittle tests that assert implementation are worse than none.
- The test names document the spec; make them read like sentences.
- Stuck making a test pass cleanly? The design is probably wrong — that's the signal, listen to it.

## Output
Passing tests + the implementation they drove, plus a one-line note on the behavior now covered.
