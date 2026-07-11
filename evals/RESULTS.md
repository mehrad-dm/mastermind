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

## Run F1 — 2026-07-11 · first full fidelity run (real pack loaded)

**Generator:** Claude Opus 4.8 (both conditions) · **Judges:** Sonnet 5 + Haiku 4.5 + Fable 5 (3-judge
median) · **N=3** per condition · treatment reads the real pack + `mastermind-debug` (not a summary).

| Task | Baseline | Treatment | Δ |
| --- | --- | --- | --- |
| 01 state-modeling | 0.72 | 1.00 | +0.28 |
| 02 illegal-states | 0.87 | 0.93 | +0.07 |
| 03 debug-root-cause | 0.70 | 1.00 | +0.30 |
| 04 untrusted-boundary | 0.87 | 1.00 | +0.13 |
| 05 simplify-refactor | 0.67 | 0.93 | +0.27 |
| 06 xss-boundary | 0.73 | 0.80 | +0.07 |
| 07 a11y-primitive | 0.27 | 1.00 | +0.73 |
| 08 yagni-restraint | 1.00 | 1.00 | 0.00 |
| **mean** | **0.73** | **0.96** | **+0.23** |

**Tokens:** generation 24.7k + judging 98.6k = 123.3k output; ~862k total incl. file-reads; 30 agents; ~5.2 min.

**Read:** No regressions (task 03 fixed: −0.13 → +0.30). Biggest win a11y +0.73 (baseline 0.27 — plain
models ship inaccessible `<div>` dropdowns). Over-engineering control (task 08) tied 1.00/1.00 — the gain
is quality, not added complexity. **Caveats:** same base model both sides (Δ = "guidance in-context");
Haiku/Fable judges are lenient so *absolute* treatment (0.96) is inflated — trust the Δ; **needs a 2nd run
for stability** before any public number.

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
