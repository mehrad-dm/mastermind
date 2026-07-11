# Eval Results — the running log

Record every run here. Each row = one task, one model, averaged over ≥3 runs per condition. The
**delta** (treatment − baseline) is the evidence. Be honest: log regressions and ties, not just wins.

## Run 1 — 2026-07-11 · self-administered smoke test

| Date | Model | MM ver | Task | Baseline | Treatment | Δ |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-07-11 | Claude Opus 4.8 | L3 (2889bc9) | 01 state-modeling | 0.33 | 1.00 | **+0.67** |
| 2026-07-11 | Claude Opus 4.8 | L3 (2889bc9) | 02 illegal-states | 0.60 | 1.00 | **+0.40** |
| 2026-07-11 | Claude Opus 4.8 | L3 (2889bc9) | 03 debug-root-cause | 0.00 | 1.00 | **+1.00** |
| 2026-07-11 | Claude Opus 4.8 | L3 (2889bc9) | 04 untrusted-boundary | 1.00 | 1.00 | **0.00** |
| | | | **mean** | **0.48** | **1.00** | **+0.52** |

**Setup:** baseline, treatment, and judge each ran in isolated subagents; the judge saw the two outputs
**A/B-shuffled and blind**, and had to quote evidence per criterion before scoring (`judge-prompt.md`).

**What it shows:** MasterMind-style guidance beat the plain baseline on 3/4 tasks and tied the 4th. The
tie (task 04) is honest signal, not noise — a strong model already does "parse, don't trust" well, so
there was little room to add. The biggest gaps were where *judgment* dominates: choosing a discriminated
union over boolean soup (01), and finding a re-render's structural root cause instead of sprinkling
`memo` (03).

**Caveats — read before believing this (this is a smoke test, not a benchmark):**
- **N = 1 per condition.** Below the protocol's ≥3. Single runs are noisy; treat as directional only.
- **Same base model in both conditions.** So Δ measures "MasterMind guidance *in-context*", NOT
  "MasterMind vs. a weaker model." A true baseline would be a model with no such guidance available.
- **Self-administered.** Generator and judge are the same model family — shared blind spots survive.
  Independent-model judging would be stronger.
- **4 tasks, frontend-only.** A smoke test, not SWE-bench. Rubrics encode *our* definition of good.

**Verdict:** first real evidence that the guidance moves rubric-measured quality up (+0.52 mean) without
triggering the over-engineering penalties — but it's preliminary. Rerun with N≥3 and an independent judge
before quoting these numbers anywhere that matters (e.g. the website).

---

> Add future runs above this line. Log regressions and ties honestly, not just wins. Don't fabricate rows.

## How to read a result
- **Δ > 0 across tasks** — MasterMind is measurably helping *on this model/version*. Say by how much.
- **Δ ≈ 0** — the model was already good here; MasterMind isn't hurting, but isn't the lever either.
- **Δ < 0 on any task** — a regression. Investigate; it likely means a rule is pushing over-engineering
  or the wrong default. This is the most valuable row — it tells you what to fix.
