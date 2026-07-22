---
title: Debug — finding the actual cause, not a convincing story
blurb: What MasterMind does when a bug refuses to die, and why "it works now" is the most dangerous sentence in debugging.
---

## The problem this solves

You hit a bug. You ask your AI. It reads the error, changes something plausible, and says *"this should
fix it."* Sometimes it does. Often the bug comes back next week wearing a different hat.

That's not because the model is bad at code. It's because nobody made it **prove** anything. Guessing is
faster than investigating, and an AI with no discipline will always take the faster path — confidently.

**Debug is the discipline that makes guessing impossible.**

## What goes wrong without it

Three failures show up again and again:

- **Patching the symptom.** The error stops appearing, but the cause is still there. The bug moves
  somewhere quieter instead of going away.
- **Fixing without a repro.** If you can't make the bug happen on demand, you can't tell whether you
  fixed it or just disturbed it. "It works now" often means "it's hiding now."
- **Theorising from memory.** Reasoning about what the code *probably* does, rather than reading what it
  actually does. This produces beautiful explanations for the wrong thing.

## How it actually works

MasterMind runs six phases, and it won't skip ahead:

**1. Reproduce it on demand.** Find the smallest reliable way to trigger the bug, and build a check that
goes *red* — a failing test, a script, a set of steps. This is the most-skipped step and the most
important one, because that red check is also the definition of "fixed." No repro, no fix.

**2. Narrow it down.** Bisect the search space — across commits, across the code path, with logging at
boundaries. Read the real code and the real data at the moment of failure, rather than reasoning about
what should be there.

**3. Form a hypothesis.** List the credible causes, ranked, and state what must be true for the top one
to be right. A hypothesis you can't test isn't a hypothesis, it's a hunch.

**4. Test the hypothesis before touching the fix.** Prove the mechanism first. This is the step that
separates understanding from coincidence.

**5. Fix the cause.** Not the symptom — the thing that made the symptom possible.

**6. Guard against its return.** Keep the red check, now green, so the bug can't come back unnoticed.

The rule underneath all six: **understand the mechanism before you change a line.** A fix you can't
explain isn't a fix — it's a coincidence that happens to be passing.

## When it fires

You don't type a command. Say any of these and MasterMind reaches for `debug`:

> *"this keeps happening and I don't know why"*
> *"it works locally but fails in CI"*
> *"the tests are flaky — sometimes green, sometimes red"*
> *"I've tried three things and it's still broken"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ tracking down the real cause — evidence, not guesses
   └ debug · reproduce → localize → hypothesize → fix → guard
```

## When it does *not* fire

- **An obvious mistake** — a typo, a wrong variable name. Six phases for a one-character fix is ceremony,
  and MasterMind skips it. Effort matches stakes.
- **Something slow rather than broken** — that's `perf`. Slowness is a measurement problem, not a
  correctness one, and they need opposite approaches. `perf` profiles before touching anything; `debug`
  reproduces before touching anything.
- **Proving a finished feature works** — that's `qa`.

## What you get

A fix you can explain, and a check that stops the bug returning silently. If MasterMind can't reproduce
the bug, it tells you that instead of shipping a guess — which is the honest answer, and usually a faster
route to the real cause than three speculative patches.
