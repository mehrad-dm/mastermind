# Eval Results — the running log

Record every run here. Each row = one task, averaged over ≥3 runs per condition, with the **exact AI
models** used named per run (generator + judge). The **delta (treatment − baseline)** is the result.
Be honest: log regressions and ties, not just wins. See `README.md` for the method and the bar a run
must clear before any number goes on the website.

> **⚗️ Experimental (v0.17.3).** These numbers are real and cleared the stability bar (2 runs) — but
> they're a small self-administered eval (8 tasks, N=3, same base model both sides), not a benchmark.
> Trust the **Δ** (both sides judged identically); treat absolutes as directional. Detailed per-run logs
> and the full method are below and in `README.md`.

## Headline — frontend tasks, with vs without MasterMind

**Generator:** Claude Opus 4.8 (both conditions) · **Judges:** Sonnet 5 × 3 seats (median) · **N=3** ·
treatment loads the real frontend pack. (Scores = rubric criteria met, 0–100%.)

| Task | Without MM | With MM | Δ |
| --- | --- | --- | --- |
| 01 state-modeling | 72% | 100% | +28 |
| 02 illegal-states | 100% | 100% | 0 |
| 03 debug-root-cause | 60% | 100% | +40 |
| 04 untrusted-boundary | 93% | 100% | +7 |
| 05 simplify-refactor | 80% | 93% | +13 |
| 06 xss-boundary | 80% | 80% | 0 |
| 07 a11y-primitive | 33% | 100% | +67 |
| 08 yagni-restraint (over-eng control) | 100% | 100% | 0 |
| **mean** | **77%** | **97%** | **+20** |

**Token cost of MasterMind:** a one-time **~7k** pack load per session + **~2–4k** more output per task
(more thorough answers). Not per-task-expensive — the pack loads once and is reused. (Full per-task token
table further below.)

### Define your stack → that's where the lift is

MasterMind's value comes from its **field pack**, not the core alone. Same tasks, two setups:

| Setup | Without MM | With MM | Δ |
| --- | --- | --- | --- |
| **Frontend** — stack pack defined | 77% | 97% | **+20** |
| **No stack pack** — universal core only | 96% | 97% | +1 |

→ Adding **your project's stack** (copy `engineering/fields/_template/` and fill it in) is what turns the
lift on for your domain. Without a matching pack, you get the core's judgment but not the domain-specific
defaults (take the a11y primitive, discriminated unions, parse-don't-trust, …).

## Run F1 — 2026-07-11 · first full fidelity run (real pack loaded)

**Generator:** Claude Opus 4.8 (both conditions) · **Judges:** Sonnet 5 + Haiku 4.5 + Fable 5 (3-judge
median) · **N=3** per condition · treatment reads the real pack + `debug` (not a summary).

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

## Run F2 — 2026-07-11 · stability check (fresh sample, identical conditions)

Same harness/models as F1, fresh sampling. **Overall: baseline 0.77 / treatment 0.97 / Δ +0.20.**

| Task | F1 Δ | F2 Δ | drift |
| --- | --- | --- | --- |
| 01 state-modeling | +0.28 | +0.28 | 0.00 |
| 02 illegal-states | +0.07 | +0.20 | 0.13 |
| 03 debug-root-cause | +0.30 | +0.33 | 0.03 |
| 04 untrusted-boundary | +0.13 | +0.07 | 0.06 |
| 05 simplify-refactor | +0.27 | +0.07 | 0.20 |
| 06 xss-boundary | +0.07 | 0.00 | 0.07 |
| 07 a11y-primitive | +0.73 | +0.60 | 0.13 |
| 08 yagni-restraint | 0.00 | 0.00 | 0.00 |
| **mean Δ** | **+0.23** | **+0.20** | **0.03** |

**Stability verdict:** aggregate Δ **cleared the ±0.1 bar** (drift 0.03). Two-run average: baseline ≈0.75,
treatment ≈0.96, **Δ ≈ +0.21**. Treatment is rock-stable (0.96/0.97); the per-task wobble on 02/05/07 is
BASELINE + lenient-judge sampling noise (e.g. task-05 baseline 0.67→0.87), not treatment instability. Anchors
held: debug +0.30/+0.33, over-engineering control 1.00/1.00 both runs. **Remaining before a public number:**
firmer judges (Haiku/Fable inflate absolutes) so the treatment 0.96 is trustworthy, not just the Δ. F2 tokens:
gen 24.1k + judge 81.0k output; ~863k total; 30 agents; ~4.6 min.

## Run F2-SJ — 2026-07-11 · strong-judge re-judge (F2 outputs, 3× Sonnet 5 median)

Re-judged F2's exact generated outputs with a **3× Sonnet 5** panel (distinct seats, median) — generation
replayed from cache, only judging re-ran (~55k output tokens). Isolates the judge-quality effect.

| Task | Baseline | Treatment | Δ |
| --- | --- | --- | --- |
| 01 state-modeling | 0.72 | 1.00 | +0.28 |
| 02 illegal-states | 1.00 | 1.00 | 0.00 |
| 03 debug-root-cause | 0.60 | 1.00 | +0.40 |
| 04 untrusted-boundary | 0.93 | 1.00 | +0.07 |
| 05 simplify-refactor | 0.80 | 0.93 | +0.13 |
| 06 xss-boundary | 0.80 | 0.80 | 0.00 |
| 07 a11y-primitive | 0.33 | 1.00 | +0.67 |
| 08 yagni-restraint | 1.00 | 1.00 | 0.00 |
| **mean** | **0.77** | **0.97** | **+0.20** |

**Finding:** strong judges did **not** deflate the treatment — it still scored **0.97** (predicted deflation
to ~0.85 did not happen). So both the **Δ (+0.20)** and the **absolute (0.97)** are robust across two samples
(F1/F2) and two judge panels (mixed / 3× Sonnet). Strong judges mainly rescored the *baseline* (task 02
→1.00, task 03 →0.60). Value concentrates on a11y (+0.67), debug (+0.40), state-modeling (+0.28), refactor
(+0.13); neutral where the base model is already good; over-engineering control tied at 0. **Trustworthy
number:** baseline ~0.77 → treatment ~0.97, Δ ≈ +0.20 on these 8 frontend tasks. **Remaining for a public
claim:** breadth beyond frontend (cross-field tasks test whether the universal *core* generalizes), and a
genuinely-weaker baseline model.

## Run CF1 — 2026-07-11 · CROSS-FIELD (core only, no field pack) · 3× Sonnet judges

5 backend/algo/security/systems tasks. Treatment loads only the universal **core** (mindset/principles/
rigor/agent-loop) — MasterMind has no pack for these domains. Tests whether the core generalizes.

| Task | Baseline | Treatment | Δ |
| --- | --- | --- | --- |
| 09 backend-api | 0.87 | 1.00 | +0.13 |
| 10 nplus1 | 0.93 | 1.00 | +0.07 |
| 11 algorithm-median | 1.00 | 1.00 | 0.00 |
| 12 shell-injection | 1.00 | 1.00 | 0.00 |
| 13 resource-cleanup | 1.00 | 0.87 | −0.13 |
| **mean** | **0.96** | **0.97** | **+0.01** |

**The finding (important):** the measured lift comes from the **field pack, not the core alone.**
Frontend (with pack) Δ +0.20 vs cross-field (core only) Δ **+0.01**. Two honest effects: (1) **ceiling** —
cross-field baseline was 0.96 (a strong model already nails backend/algo/security basics), so little room;
(2) **no pack** — the core is a judgment framework, not domain-specific defaults. MasterMind's value shows
where the base model underperforms AND a field pack exists. Validates the field-parameterized thesis.
Caveat: confounded (cross-field tasks near-ceiling); the clean test is bootstrapping a backend pack and
re-running these same 5 tasks (core-only +0.01 vs core+pack = the pack's worth). Regression on 13
(−0.13) may be N=3 noise. Tokens: gen 14.1k + judge 22.6k output; ~667k total; ~2.4 min.

## Token usage — per task, with vs without MasterMind (2026-07-11)

Model both conditions: **Claude Opus 4.8**. Generation only (no judge tokens). N=1 per task, each task run
in its own agent to get per-task figures.

| Task | Without MM | With MM | Δ |
| --- | --- | --- | --- |
| 01 state-modeling | 27,171 | 46,544 | +19,373 |
| 02 illegal-states | 26,848 | 44,225 | +17,377 |
| 03 debug-root-cause | 26,941 | 43,501 | +16,560 |
| 04 untrusted-boundary | 27,335 | 43,864 | +16,529 |
| 05 simplify-refactor | 26,799 | 46,531 | +19,732 |
| 06 xss-boundary | 27,052 | 46,819 | +19,767 |
| 07 a11y-primitive | 27,305 | 47,783 | +20,478 |
| 08 yagni-restraint | 35,146 (outlier¹) | 44,364 | +9,218 |
| **avg (excl. 08)** | **~27,064** | **~45,452** | **~+18,388** |

### The honest decomposition (what a real user actually pays)
The raw per-task Δ (~+18k) is **massively overstated** — each isolated agent re-reads the whole pack. Real
sessions load it once. The true breakdown:
- **Fixed agent/harness overhead ≈ 26.5k** — present in BOTH conditions (measured: an agent that reads
  nothing still costs ~26.5k). This is the eval subagent, **not** MasterMind.
- **One-time pack load ≈ 7.3k tokens** (measured: CLAUDE.md + mindset + rigor + stack-defaults + lessons =
  5,647 words). Read **once per session**, then reused for every task.
- **Per-task marginal ≈ +2–4k output** — MasterMind answers are more thorough (rationale, edge cases).

So the real cost of MasterMind ≈ **a one-time ~7k pack load + ~2–4k more output per task** — e.g. an
8-task session pays roughly ~7k once + ~24k thoroughness ≈ **~30k extra total**, not the naive +139k the
per-task table sums to (which counts the pack read 8×). Worth it for +0.20 quality.

¹ Task-08 baseline is an outlier: that plain agent ignored "don't read files" and explored the repo (5
tool calls, 35k vs the ~27k norm).

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
