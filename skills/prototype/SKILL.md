---
name: prototype
description: "Use when the right approach is unknown and trying it will teach faster than planning: a risky assumption, an unfamiliar integration, a doubt that it can work at all. The result is throwaway and does not ship."
---

# MasterMind: Prototype

Tight feedback loops beat big plans when the path is unclear (`~/.mastermind/engineering/core/agent-loop.md`, `mindset.md` →
design it twice). A prototype buys knowledge cheaply: the discipline is keeping it knowledge, not product.

## Method

1. **Name the question**: the ONE risky unknown this prototype will answer ("can the Worker stream a >20 MB
   file?", "does this library handle X?"). One named question is the entry price, find it first.
2. **Build the smallest thing that answers it**: hard-code, skip error handling, skip tests, skip
   polish. Speed over quality; it's throwaway.
3. **Extract the learning**: what did reality teach? Write down the answer and any surprises.
4. **Throw it away and rebuild to standard**: the real version gets the full loop (design, rigor,
   tests, review). **Ship the rebuild; the prototype gets discarded.**

## Rules
**Time-box: three build-and-run attempts**, the loop limit in `core/agent-loop.md`. An *attempt* is one
edit → run → observe cycle against the named question; number each attempt in your updates, so the box
is observable. Attempt 3 finished without an answer = the box is spent, whatever the clock says.

**When it expires, stop. That's a result, not a failure.** Report: what you learned, what is still
unknown, and one recommendation: *proceed* (answer is yes, build it properly) / *different approach*
(this path is wrong, here's the next one) / *needs more investigation* (name what a second prototype would
target). Then discard the code: it stays throwaway and does not ship, same as a prototype that succeeded.

**Extending the box is the user's call.** When the attempts narrowed the question, say so in the
report and recommend a second prototype with its own question; do not extend it yourself.

Keep it isolated (a scratch branch/dir) so it can't leak into production. The deliverable is
the *learning*, not the code.

## Output
The answer to the question + the surprises, and a clear "now build it properly" recommendation (or a
"don't build it, here's why"). When the prototype served a feature in `specs/`, record the question and
the answer in that feature's `research.md`, so `blueprint` builds on it instead of re-asking it.
