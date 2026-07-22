---
title: Refactorer — changing the shape without changing the behavior
blurb: What MasterMind does to code that works but has become hard to work in, and the one promise it never breaks.
---

## The problem this solves

Code rots in a specific way. Nothing breaks. Everything still works. But each new feature takes longer
than the last, changes in one place cause surprises in another, and eventually you find yourself saying
"don't touch that file." The software is fine. Working *in* it is not.

The instinct is to leave it alone, because rewriting working code is how you break working code. So the
mess compounds until someone proposes throwing it all away.

**Refactorer is the way out: restructure the code toward a better design while guaranteeing it still does
exactly what it did before.** The old carpenter's version of this — make the change easy, then make the
easy change.

## What goes wrong without it

- **Every feature costs more than the last.** The structure fights you, so work that should take an hour
  takes a day, and nobody can point to why.
- **The rewrite temptation.** Untangling feels impossible, so someone proposes starting over — which
  throws away years of accumulated bug fixes nobody remembers making.
- **Silent behavior changes.** The dangerous version. Someone tidies up and quietly "fixes" something
  along the way. Now a change advertised as cosmetic has altered what the product does, and when a bug
  appears three weeks later nobody thinks to look in the tidy-up.
- **Cosmetic churn.** Renaming things and reformatting files feels productive and improves nothing. The
  shallow module is still shallow; the tangled data model is still tangled.

## How it actually works

Refactorer is an **agent**, not a skill. A skill is a procedure the main conversation follows; an agent
runs in its own **isolated context window**, seeing only the job it was handed. It doesn't carry the
conversation that led here, or any attachment to how the code came to look this way. It reads what is
actually there and judges the design on its own terms — which is what lets it propose unpicking a
structure that the main thread may have just spent an hour building.

**The promise: behavior is preserved, and the tests prove it.** Not "should be preserved." The existing
tests must pass, unchanged, exactly as they did before. If the target area isn't covered by tests, the
first move is to write characterisation tests — tests that pin down what the code currently does, correct
or not — before touching anything. If there's no way to prove behavior is unchanged, it doesn't refactor.
That's a refusal, not a caveat.

The second rule follows from the first: **structure or behavior, never both at once.** If a real bug turns
up mid-refactor, it gets noted and left alone. Fixing it silently would hide a behavior change inside a
change labelled behavior-preserving, and destroy the guarantee that makes refactoring safe.

What it goes after is structural, not cosmetic. Shallow modules that expose their guts get deepened, so
they present a simple surface and hide the complexity inside. A duplicated or badly-shaped data model gets
reshaped, which usually makes a surprising amount of code disappear. Special cases and thickets of
conditionals get restructured so the edge case stops existing. Boundaries that leak get separated by
reason-to-change. Abstractions invented too early get collapsed; ones missing after the third repetition
get extracted.

It works in small steps, running the typecheck, linter and tests after each one, and shows you that
evidence.

## When it fires

> *"this file has become a nightmare to work in"*
> *"every time I change one thing here, something else breaks"*
> *"can you clean up how this data is structured?"*
> *"this works but I'm embarrassed by it"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ restructuring it without changing what it does
   └ refactorer · safety net → small steps → green after each → behavior unchanged
```

## When it does *not* fire

- **When the code should do something new** — that's `build`. This is the sharpest line in MasterMind.
  Build changes what the software does. Refactorer changes *only* how it's arranged and never what it
  does. If your request includes "and also make it handle X," that part is a build, and it happens
  separately — mixing the two is precisely the failure mode this discipline exists to prevent.
- **When something is wrong** — that's `debug`. Refactorer works on code that already behaves correctly.
- **When you want to know what's wrong with it** — that's the `code-reviewer` agent, which finds problems
  and proposes fixes without editing anything. Refactorer edits.
- **Light tidying** — dead code, an awkward name. That's a quick cleanup, not a structural redesign.

## What you get

Restructured code, plus a short account of what was wrong with the design, what changed and why, and the
proof that behavior is unchanged — the test run, green. Anything it deliberately chose to leave out of
scope, including any bug it spotted and left alone, is named rather than quietly handled.
