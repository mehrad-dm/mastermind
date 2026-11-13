---
title: Build: the whole loop, not just the typing
blurb: What MasterMind does when you ask for a feature, and why "it compiles" is not the same as "it works."
---

## The problem this solves

You ask for a feature. The AI writes code. It looks right. You paste it in, and three days later you
find out it breaks when the list is empty, or when the user is logged out, or when the network is slow.

The code wasn't wrong because the model can't write code. It was wrong because writing code is one part
of the job, and everything either side of it got skipped. Nobody worked out what the feature
actually had to do. Nobody read the surrounding code to match it. Nobody ran the thing and watched it
behave. Nobody looked at the finished diff with fresh, hostile eyes.

**Build is the discipline that puts the other parts back.**

## What goes wrong without it

- **The happy path only.** The feature works exactly once, with perfect input, on the developer's
  machine. Empty states, errors, loading, unauthorized users: all unhandled, because nobody listed them.
- **Code that doesn't belong.** Written in a style the rest of the project doesn't use, with a library
  the project doesn't have. It works, but every future change now has two conventions to satisfy.
- **Scope creep by helpfulness.** You asked for one thing and got four, including a refactor you didn't
  want and can no longer separate from the part you did.
- **"Done" declared without evidence.** The most expensive failure. Nothing was run; success was asserted.

## How it actually works

MasterMind works toward a set of outcomes, and scales them to the size of the job: a one-line change
skips most of this, a new foundation gets all of it.

**Understand.** Restate the real problem and the boundaries of it. Read the existing code and
conventions first. Do the asked task and nothing more.

**Design.** For anything spanning more than one file, work out the shape before writing: the pieces and
their boundaries, how data moves, the key types, and the list of edge cases that must be handled.

**Decide the stack.** Pick the simplest thing that fully solves the problem, following whatever the
project already uses. Deviate only with a stated reason.

**Implement.** Build against the design, handling the unhappy paths deliberately: empty, null, loading,
error, one, many, offline, unauthorized, malformed. No placeholder code left behind.

**Verify.** Drive the real thing. Typecheck, lint, build, run the project's existing tests, click the
actual flow. Show what was run and what happened. When a check cannot be run, MasterMind does the most
rigorous one it can and reports the work as "Done, not fully checked", naming what was not run.

**Review.** A change that touches more than one file, or touches authentication, money, a data
migration, a public contract or something irreversible, goes to a separate reviewer in a fresh context,
hunting for correctness, security and accessibility problems. The real ones are fixed and re-verified,
in at most three rounds. A smaller change gets a self-check, and the closing line says "self-checked".

**Report.** The evidence first, then the verdict, what was not checked, and what was decided for you.
Anything noticed along the way and left alone is listed as "Suggested (not done)".

There's an optional gate you can switch on per project: **plan first**. With it on, MasterMind stops
after the design and shows you the plan: goal, approach, exact files, steps: and waits for your
go-ahead before editing anything.

## When it fires

You don't type a command. Say any of these and MasterMind reaches for `build`:

> *"add a dark mode toggle to the settings page"*
> *"can you make the search box filter as I type"*
> *"implement the checkout step we talked about"*
> *"this form needs to save drafts"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ building this: will verify before handoff
   └ web pack · code-reviewer in a fresh context
```

## When it does *not* fire

- **A genuine one-liner**: a copy change, a wrong color, a renamed variable. The full treatment for a
  one-word fix is theatre, and MasterMind skips straight to doing it.
- **When the ask isn't clear yet**: that's `interview`. The difference matters: `interview` decides *what* to
  build and stops there, producing a written blueprint and no code. `build` produces working, verified
  code. If nobody can agree what "make it better" means, building first just produces a confident wrong
  answer faster. Spec first, then build from it.
- **Something already built that's broken**: that's `debug`. Build creates new behavior; debug explains
  existing misbehavior.
- **Proving a finished change works**: that's `qa`, which build already calls as its verify step.

## What you get

A change that handles the cases you'd have found in production, written in the style of the code around
it, with a record of what was actually run to prove it works. And when something couldn't be verified,
you're told that plainly rather than reassured.
