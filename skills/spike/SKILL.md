---
name: spike
description: Use when the right approach is genuinely unknown and reality will teach faster than planning — a risky unvalidated assumption, an unfamiliar integration, "will this even work", "try something quick". The result is explicitly throwaway and does not ship.
---

# MasterMind — Prototype

Tight feedback loops beat big plans when the path is unclear (`~/.mastermind/engineering/core/agent-loop.md`, `mindset.md` →
design it twice). A spike buys knowledge cheaply — as long as you don't mistake it for the product.

## Method

1. **Name the question** — the ONE risky unknown this spike will answer ("can the Worker stream a >20 MB
   file?", "does this library handle X?"). If there's no question, you don't need a prototype.
2. **Build the smallest thing that answers it** — hard-code, skip error handling, skip tests, skip
   polish. Speed over quality; it's throwaway.
3. **Extract the learning** — what did reality teach? Write down the answer and any surprises.
4. **Throw it away and rebuild to standard** — the real version gets the full loop (design, rigor,
   tests, review). **Do not ship the spike.**

## Rules
**Time-box: 5 build-and-run attempts, roughly 30 minutes** — one question needs a handful of tries, not a
day; proportionality over ceremony. An *attempt* is one edit → run → observe cycle against the named
question; count them out loud as you go, so the box is observable and not a vibe. Attempt 5 finished
without an answer = the box is spent, whatever the clock says.

**When it expires, stop — that's a result, not a failure.** Report: what you learned, what is still
unknown, and one recommendation — *proceed* (answer is yes, build it properly) / *different approach*
(this path is wrong, here's the next one) / *needs more investigation* (name what a second spike would
target). Then discard the code: it stays throwaway and does not ship, same as a spike that succeeded.

**Extending the box is a decision, not drift.** Only extend when the attempts narrowed the question
rather than wandering — say so explicitly, state the new bound (e.g. "3 more attempts"), and stop there.

Keep it isolated (a scratch branch/dir) so it can't leak into production. The deliverable is
the *learning*, not the code.

## Output
The answer to the question + the surprises, and a clear "now build it properly" recommendation (or a
"don't build it — here's why").
