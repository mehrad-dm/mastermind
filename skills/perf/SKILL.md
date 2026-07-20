---
name: perf
description: Use when something is slow — "why is this slow", "optimize this", "make it faster", jank, lag, a slow query, slow page load, slow render, slow build, high memory, a timeout. Not for correctness bugs; that's debug.
---

# Perf — measure, find the real bottleneck, fix the biggest, verify

Slowness has a **real, measurable cause**. The cardinal sin is optimizing by intuition — you'll spend
effort on the wrong thing and maybe trade away correctness for nothing. Get data first.

## The loop

1. **Reproduce + measure.** Get a real number under a realistic scenario — wall-clock, FPS/frame time,
   query ms (`EXPLAIN ANALYZE`), request latency, bundle size, memory. No number, no optimizing. Write it
   down; it's your before.
2. **Find the bottleneck — profile, don't guess.** Use the right instrument (browser Performance panel /
   React Profiler, a flame graph, DB query plan, a tracer) and find *where the time actually goes* — the
   ~20% causing ~80%. Suspects, by domain:
   - **Frontend:** unnecessary re-renders, unmemoized expensive work, big unvirtualized lists, request
     waterfalls, oversized bundles/images, layout thrash.
   - **Backend/data:** N+1 queries, a missing index, full scans, sync I/O on the hot path, no caching,
     chatty network calls, unbounded result sets.
3. **Fix the biggest one.** Make the single change with the most impact; resist micro-optimizing noise.
   Prefer *doing less work* (cache, batch, index, memoize, defer, paginate) over doing the same work faster.
4. **Verify the win.** Re-measure the same way — confirm the number actually moved, and that **behavior
   and correctness are unchanged** (`core/rigor.md`). A "faster" version that's subtly wrong is a regression.
5. **Guard it.** Note the metric (a comment, a budget, a perf test) so the regression is visible next time.

## Gotchas
- **Measure before *and* after** — "feels faster" is not a result; a number that moved is.
- **Profile, don't pattern-match.** The obvious suspect is often not the bottleneck — the profiler decides.
- **Correctness is not on the table.** Never trade a correct result for speed; if a fix changes behavior,
  it's not a perf fix.
- **Biggest first.** One 10× hotspot beats ten 5% tweaks; stop when the number is good enough (match effort
  to stakes), not when you've micro-optimized everything.
- **Not `debug`** (a wrong result) and **not `qa`** (proving it works) — this is *make the correct thing fast*.
