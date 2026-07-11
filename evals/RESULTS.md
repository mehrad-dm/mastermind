# Eval Results — the running log

Record every run here. Each row = one task, one model, averaged over ≥3 runs per condition. The
**delta** (treatment − baseline) is the evidence. Be honest: log regressions and ties, not just wins.

## Run 2 — 2026-07-11 · N=3, independent judge (the stricter, more honest run)

Generators: Claude Opus 4.8 (3 baseline + 3 treatment, isolated subagents). **Judge: Claude Sonnet 5**
(a *different* model — reduces shared-blind-spot bias). N=3 per condition; scores below are per-task means.

| Model (gen) | Judge | MM ver | Task | Baseline | Treatment | Δ |
| --- | --- | --- | --- | --- | --- | --- |
| Opus 4.8 | Sonnet 5 | L3 (12f6088) | 01 state-modeling | 0.06 | 0.94 | **+0.88** |
| Opus 4.8 | Sonnet 5 | L3 (12f6088) | 02 illegal-states | 0.80 | 0.93 | **+0.13** |
| Opus 4.8 | Sonnet 5 | L3 (12f6088) | 03 debug-root-cause | 0.80 | 0.67 | **−0.13** |
| Opus 4.8 | Sonnet 5 | L3 (12f6088) | 04 untrusted-boundary | 1.00 | 1.00 | **0.00** |
| | | | **mean** | **0.66** | **0.89** | **+0.22** |

**What it actually shows (honest):**
- MasterMind's edge is **real but concentrated** where *data-model judgment* dominates: discriminated
  union + boundary validation + a11y on task 01 (huge gap), transition guards on task 02.
- It **tied** task 04 (a strong model already does "parse, don't trust") and **slightly lost** task 03 —
  even treatment reached for `memo`/`useDeferredValue` rather than the clean "move state down / lift
  children" structural fix, so it earned no edge, and one treatment got dinged for memo-reliance.
- **Independent judge → smaller, more credible delta** (+0.22 vs run-1's +0.52). Run 1's number was
  inflated by a same-model judge and a single weak baseline on task 03.

**New caveats surfaced this run (do not ignore):**
- **Judge noise is real.** On task 03 a treatment output scored 0.20 for "reflexive memo" while a
  near-identical baseline scored 0.80 — inconsistent grading of the same pattern. Trust the *direction*,
  not the third decimal.
- **Task 01 baseline (0.06) is likely too harsh** — the boolean-soup answers had a cancel-flag (arguably
  meeting crit 1/5); a fairer baseline is ~0.4. So the +0.88 is an upper bound; the true task-01 edge is
  smaller but still clearly positive.
- Same base model both conditions; 4 frontend tasks. Still a smoke test, not a benchmark.

**Verdict:** MasterMind measurably helps on architecture/data-model decisions and is neutral where the
base model is already strong — it does **not** uniformly improve everything, and it doesn't regress into
over-engineering (no anti-criteria triggered). This is **not yet a clean enough, high-enough signal to
put a headline number on the website.** Needs more tasks + multi-judge consensus before any public claim.

---

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
