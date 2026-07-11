# Eval Results — the running log

Record every run here. Each row = one task, averaged over ≥3 runs per condition, with the **exact AI
models** used named per run (generator + judge). The **delta (treatment − baseline)** is the result.
Be honest: log regressions and ties, not just wins. See `README.md` for the method and the bar a run
must clear before any number goes on the website.

> **Reset to a clean template 2026-07-11 — no current numbers.** Prior preliminary runs (Run 1, Run 2,
> the Matt Pocock 3rd-condition experiment, and the task-03 fix verification) are **preserved in git
> history** — nothing was lost; they were just too preliminary/noisy to present as results. This table
> stays empty until a run clears the bar in `README.md` (8 tasks · N≥3 · 3-judge median · stable across
> two runs). Don't fabricate rows.

## Run template — copy this block per run, fill in, name the models

**Run N — YYYY-MM-DD · GEN-MODEL gen · JUDGE-MODEL(s) judge · N=k · MasterMind vX/commit**

| Task | Baseline | Treatment | Δ |
| --- | --- | --- | --- |
| 01 state-modeling | — | — | — |
| 02 illegal-states | — | — | — |
| 03 debug-root-cause | — | — | — |
| 04 untrusted-boundary | — | — | — |
| 05 simplify-refactor | — | — | — |
| 06 xss-boundary | — | — | — |
| 07 a11y-primitive | — | — | — |
| 08 yagni-restraint | — | — | — |
| **mean** | — | — | — |

_Setup (fill in): how baseline/treatment were generated, how the judge was blinded, inter-judge
agreement. Caveats. Verdict._

## How to read a result
- **Δ > 0 across tasks** — MasterMind is measurably helping *on these models/version*. Say by how much.
- **Δ ≈ 0** — the base model was already good here; not hurting, not the lever either.
- **Δ < 0 on any task** — a regression. The most valuable row: it tells you what to fix (feed a lesson
  back into the field pack, then re-measure — see git history for how the task-03 regression was closed).
