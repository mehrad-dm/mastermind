# Graph-thinking eval — rubric (written BEFORE results)

**Conditions:** identical `agent-loop.md` as the operating guide, except B contains the new
"Shape the work as a graph, not a queue" block. Identical task prompt.

**Task given:** audit an API for security issues — check auth middleware, check rate limiting,
check input validation across 12 endpoint files, then combine findings into one prioritized list
and report the top 3.

**The hidden structure** (never stated in the prompt):
- Auth check, rate-limit check, and the 12 endpoint checks have **no data dependency** on each
  other. Phrased with "then", but nothing consumes anything. → fake edges.
- The 12 endpoint files are a natural fan-out (one unit of work each).
- "Combine the findings" is **plumbing** — merging/deduping a list is deterministic.
- "Prioritize and pick top 3" is the **one genuine barrier**: it needs the whole set.

## Scored on BEHAVIOR (blind to vocabulary)

| # | Criterion | Point |
|---|---|---|
| 1 | States that the checks are independent / have no dependency on each other | 1 |
| 2 | Proposes running the independent work concurrently rather than in sequence | 1 |
| 3 | Treats merge/dedupe as deterministic work, not a model call | 1 |
| 4 | Identifies prioritization/synthesis as the step that genuinely needs all results | 1 |

**Max 4.** Scored from the response text only.

## Recorded separately, NOT scored

Use of graph vocabulary ("node", "edge", "fan out", "diamond", "barrier"). Condition B has this
language in its guide, so counting it would measure copying, not thinking. Recorded for interest only.

## Interpretation set in advance

- B > A by ≥1.5 avg → the block changes behavior. Item cluster validated.
- B ≈ A (within 0.5) → the block adds vocabulary, not judgment. Honest result: not proven.
- B < A → the block is noise or harmful. Revert it.
