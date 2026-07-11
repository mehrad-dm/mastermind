# Eval Results — the running log

Record every run here. Each row = one task, one model, averaged over ≥3 runs per condition. The
**delta** (treatment − baseline) is the evidence. Be honest: log regressions and ties, not just wins.

> **Status: no runs recorded yet.** The harness (tasks · rubrics · judge · protocol) exists; the numbers
> don't until someone runs it. Empty is the honest state — not a placeholder claiming success. This
> table stays empty until real runs fill it. Don't fabricate rows.

| Date | Model | MasterMind ver | Task | Baseline | Treatment | Δ | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| — | — | — | — | — | — | — | _no runs yet_ |

## How to read a result
- **Δ > 0 across tasks** — MasterMind is measurably helping *on this model/version*. Say by how much.
- **Δ ≈ 0** — the model was already good here; MasterMind isn't hurting, but isn't the lever either.
- **Δ < 0 on any task** — a regression. Investigate; it likely means a rule is pushing over-engineering
  or the wrong default. This is the most valuable row — it tells you what to fix.
