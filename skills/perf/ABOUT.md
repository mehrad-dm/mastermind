---
title: Perf — making the correct thing fast, with numbers to prove it
blurb: What MasterMind does when something is slow, and why "feels faster" is not a result.
---

## The problem this solves

Something is slow. The page hangs, the query crawls, the app stutters when you scroll. You ask your AI to
speed it up, and it obliges — it adds caching here, memoises something there, rewrites a loop. The code
gets more complicated. Whether it got faster, nobody actually knows.

The trap is that slowness *looks* diagnosable by reading. It isn't. Programs spend their time in places
that surprise even the people who wrote them, and an AI reasoning from patterns will confidently optimize
the part that was never the problem.

**Perf is the discipline of not touching anything until you have a number.**

## What goes wrong without it

- **Optimizing by intuition.** The obvious suspect gets rewritten, the real bottleneck is untouched, and
  the code is now harder to read for no gain.
- **No before, so no after.** Without a measurement taken first, there's nothing to compare against. "It
  feels snappier" is a mood, not evidence.
- **Trading correctness for speed.** A shortcut that skips a check or returns stale data is faster and
  wrong. That isn't an optimization, it's a bug with better timings.
- **Death by micro-optimization.** Ten small tweaks that each save two percent, while a single tenfold
  hotspot sits untouched.

## How it actually works

MasterMind works through five steps in order:

**1. Reproduce and measure.** Trigger the slowness under realistic conditions and capture a real number —
elapsed time, frame rate, query milliseconds, request latency, bundle size, memory. That number is written
down as the "before." No number, no optimizing.

**2. Profile instead of guessing.** Use the right instrument for the domain — a browser performance panel,
a flame graph, a database query plan — and find where the time genuinely goes. Usually a small fraction of
the code accounts for most of the delay. The profiler decides what that is, not a hunch.

**3. Fix the biggest thing.** One change, aimed at the largest contributor. The preferred fix is almost
always *doing less work* — caching a result, batching requests, adding an index, loading later, paging
through data — rather than doing the same work marginally faster.

**4. Verify the win.** Measure again, the same way, and confirm the number actually moved. Then confirm
behavior is unchanged, because a faster version that quietly returns something different is a regression
wearing a disguise.

**5. Guard it.** Record the metric — a budget, a note, a performance test — so a future change that
reverses the win is visible rather than silent.

## When it fires

You don't type a command. Say something like this and MasterMind reaches for `perf`:

> *"why is this page taking so long to load"*
> *"the app stutters when I scroll the list"*
> *"this report query times out on big accounts"*
> *"the build takes four minutes, can you make it faster"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ perf · measure → profile → fix the biggest → verify → guard
```

## When it does *not* fire

- **Something is wrong, not slow** — that's `debug`. The distinction matters more than it sounds. A bug
  needs a reproduction that fails; slowness needs a measurement that's too high. `debug` asks *why is this
  answer wrong*, `perf` assumes the answer is right and asks *why does it take so long*. Using the wrong
  one wastes the whole session — profiling a correctness bug tells you nothing, and hunting a root cause
  for slowness just produces theories.
- **Proving a finished feature works end to end** — that's `qa`. Perf verifies a number moved; qa verifies
  the behavior is correct.
- **Tidying code that isn't slow** — restructuring for clarity is refactoring. Perf only justifies a change
  when a measurement backs it.

## What you get

A specific bottleneck named, one targeted change, and two numbers — before and after — so you can see the
size of the win rather than take it on faith. If the profile shows the slowness isn't where you assumed,
MasterMind tells you that, even when it means the fix you asked for was the wrong one.
