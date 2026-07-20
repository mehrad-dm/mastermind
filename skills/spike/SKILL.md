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
Time-box it. Keep it isolated (a scratch branch/dir) so it can't leak into production. The deliverable is
the *learning*, not the code.

## Output
The answer to the question + the surprises, and a clear "now build it properly" recommendation (or a
"don't build it — here's why").
