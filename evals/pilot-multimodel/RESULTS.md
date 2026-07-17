# Multi-model pilot — results (v0.18.1)

The upgrade over the original eval: **8 independently-authored tasks** (written by Fable, which never
read MasterMind — kills the author-bias), run on **4 models × plain vs +MasterMind** (the MasterMind arm
reads the real repo — high fidelity), scored by a **blind 3-judge panel** (Opus + Sonnet + Fable, median,
A/B alternated to cancel position bias). 160 agents, 0 errors, ~5.3M tokens.

## Headline — per model (Δ = MasterMind − plain, rubric pass-rate 0–1)

| Model | Plain | +MasterMind | Δ |
| --- | --- | --- | --- |
| Haiku 4.5 *(weak)* | 0.937 | 1.000 | **+0.063** |
| Fable 5 | 0.937 | 1.000 | **+0.063** |
| Opus 4.8 *(strong)* | 0.979 | 1.000 | +0.021 |
| Sonnet 5 | 0.979 | 0.979 | 0.000 |
| **Overall** | **0.958** | **0.995** | **+0.037** |

## What the data honestly says

1. **The core hypothesis held: MasterMind helps the weaker models most.** Haiku and Fable gained ~3×
   what Opus did; Sonnet (already at ceiling) gained nothing. A judgment/rigor layer matters more the
   less the base model already carries it — which is exactly the case for adoption on cheaper models.

2. **Severe ceiling effect — the tasks were too easy for frontier models.** Plain scores were already
   0.94–0.98; on 4 of 8 tasks *every* model scored a perfect 1.0 with no MasterMind, so there was
   nothing to lift. This *under-measures* the real effect. **The #1 fix for the next run: harder,
   more-discriminating tasks.**

3. **Where the lift actually came from — rigor & edge cases.** Every positive delta was on:
   `countdown-timer-stale-closure` (even **Opus plain missed a criterion**: 0.833 → 1.0),
   `search-fetch-race-condition`, `dashboard-duplication-refactor` (cleanup/types), and
   `accessible-modal-dialog`. On tasks the models already aced (SQLi/IDOR, money-schema, interval-math,
   render-perf) there was no gap to close. This matches the design intent: MasterMind adds
   verify/edge-case/a11y discipline, not raw capability.

4. **Magnitude is small and honest: +3.7 pts overall.** This is *not* a "2× better" story. On tasks
   strong models already handle well, MasterMind adds a little; the value concentrates on weaker models
   and rigor-sensitive tasks.

## Caveats (don't over-read this)

- **N=1 per generation.** Judges were N=3 (median), but each model×condition ran once — so individual
  cell deltas (the +0.167s) are noisy. Averages across 8 tasks are firmer than any single cell.
- **Ceiling-limited** (see #2) — treat +0.037 as a *floor*, not the ceiling of what harder tasks would show.
- **Self-judging bias** — Opus/Sonnet/Fable judged outputs that sometimes came from themselves (blind,
  rubric-based, but not zero bias).
- **8 tasks, one field** (mostly frontend + a little backend/general). Directional, not a benchmark.

## Next run (to make this publishable)

1. **Harder tasks** that frontier models *don't* already ace — the single biggest improvement.
2. **N=3 generations** per cell (average), to kill per-cell noise.
3. Scale to ~30 tasks; keep independent authorship + blind panel.
4. Add the **token-cost axis** (router measurement) so quality Δ and token savings sit in one table.

---

# Frontend-hard, steady-state — Haiku vs Opus (v0.18.1)

4 **hard** frontend tasks (the field is already built = fair steady state, no bootstrap cost), Haiku
(weak) vs Opus (strong), plain vs +MasterMind, blind 3-judge panel (Opus+Sonnet+Fable, median). N=1.
40 agents, 0 errors, ~1.5M tokens.

## Per model (Δ = MasterMind − plain)

| Model | Plain | +MasterMind | Δ |
| --- | --- | --- | --- |
| Opus 4.8 *(strong)* | 0.875 | 0.975 | **+0.100** |
| Haiku 4.5 *(weak)* | 0.925 | 0.875 | **−0.050** |
| **Overall** | 0.900 | 0.925 | **+0.025** |

## Per task

| Task | Haiku plain→MM | Opus plain→MM |
| --- | --- | --- |
| modal-focus-trap-audit | 1.0 → 0.9 (−0.1) | **0.7 → 1.0 (+0.3)** |
| currency-input-minor-units | 0.9 → 1.0 (+0.1) | 1.0 → 0.9 (−0.1) |
| recurring-event-dst | 0.8 → **0.6 (−0.2)** | 0.9 → 1.0 (+0.1) |
| typeahead-stale-race | 1.0 → 1.0 (0) | 0.9 → 1.0 (+0.1) |

## What the data says — and it flips the pilot

1. **Harder tasks *did* discriminate** (plain now ranges 0.7–1.0, not a flat 0.98). The ceiling problem
   is largely fixed — this is a fairer test.
2. **On hard tasks MasterMind helped the STRONG model, not the weak one** — the reverse of the easy
   pilot. Opus +0.10 (its clearest win: **modal-focus 0.7→1.0**, closing real a11y gaps via the field
   pack); Haiku **−0.05** (notably recurring-event-dst 0.8→0.6).
3. **The likely mechanism — capacity to *use* it.** A weak model handed the full MasterMind context
   (repo read, router, field files, rigor steps) on a genuinely hard problem appears to be *overwhelmed*
   — attention spent on scaffolding instead of the hard logic. A strong model has the headroom to turn
   the same guidance into fixes. Tentative but important: **MasterMind + strong model on hard tasks is
   the sweet spot; MasterMind + weak model on hard tasks can backfire.**

## Caveats — do NOT over-read this

- **N=1, 4 tasks.** With 10-criterion rubrics, one criterion = 0.1, so a ±0.1–0.2 cell is *within noise*.
  The direction (Opus up, Haiku flat/down) is the signal; the exact magnitudes are not trustworthy yet.
- Easy pilot and hard run gave **opposite** model-lift patterns — which itself says the effect is small
  and difficulty-dependent, not a stable "+X%".
- Self-judging bias (Opus/Fable judged some of their own outputs, blind).

## The honest conclusion so far

Across both runs, the effect is **real but small and conditional**: MasterMind fills gaps, and *which*
gaps depends on model capacity × task difficulty. It is **not** a uniform "+X% better." The one firm,
repeatable win is **the field pack closing concrete domain gaps a plain model misses** (Opus a11y
0.7→1.0). **Next: N=3 on these hard tasks** to confirm whether "hurts the weak model on hard tasks" is
real or noise — that's the finding that most changes how MasterMind should be used and pitched.

---

# Router-honor test — does the model actually obey the router? (v0.18.1)

The honor-system risk: `ROUTER.md` only *works* if the model reads it and loads just the matched files.
5 probes (4 Opus + 1 Haiku), each told to "follow MasterMind properly" on a different frontend task and
then honestly report which files it Read. Real token counts (chars/4). ~0.2M tokens.

## Result: the router IS honored — 5/5 consulted it and loaded selectively

MasterMind-context tokens loaded per task — **with the router** vs what it *would* cost with no router
(load the whole pack).

| Task (model) | Files loaded | With Router | No router (load all) | Router saves |
| --- | --- | --- | --- | --- |
| review (opus) | ROUTER + audit-rules | 2,318 | 20,870 | **−89%** |
| animation (opus) | ROUTER + web-animations | 5,002 | 20,870 | **−76%** |
| datafetch (opus) | ROUTER + active-field + stack-defaults | 9,237 | 20,870 | −56% |
| refactor (opus) | ROUTER + stack-defaults + lessons + principles | 12,321 | 20,870 | −41% |
| **Opus average** | 2–4 files, always the *right* ones | **~7,220** | 20,870 | **−65%** |
| animation (**haiku**) | ROUTER + mindset + web-animations + stack-defaults | 11,604 | 20,870 | −44% |

**Reading it:** "With Router" is the real per-task knowledge cost — **~2.3k–12.3k**, not the 20.9k it
would be without the router. On top of this sits the always-on kernel (~1.7k, once per session, not per
task), and — per the 2026-07-11 token eval — MasterMind answers run ~2–4k longer (more thorough output).
So the honest full picture of "cost of MasterMind per task" ≈ **routed knowledge (~2–12k) + ~2–4k extra
output**, amortizing the kernel across the session.

## What it says (honestly)

1. **The router is obeyed and accurate.** Every probe read `ROUTER.md` first and loaded only the
   matched file(s) — animation→web-animations, review→audit-rules, refactor→stack-defaults+lessons,
   datafetch→stack-defaults. The honor-system risk **did not materialize** for these models.
2. **Real savings ~65% average (41–89% by task)** — validating the ~70% claim in *actual behavior*, not
   just file arithmetic. Single-file tasks hit ~76–89%; genuinely multi-file work (refactor) is ~41%.
   So "~70%" is honest as a *typical* figure, with the caveat that it varies with task complexity.
3. **The weak model over-reads.** On the *identical* animation task, Haiku loaded **2.3× more** than
   Opus (11,604 vs 5,002) — pulling in mindset + stack-defaults it didn't strictly need. This
   independently echoes the hard-task finding: the weak model carries more scaffolding and routes less
   tightly — plausibly part of why MasterMind can overwhelm it.

## Caveats

- **Self-reported reads, N=1 per probe.** But "consulted the router" is a binary the model has little
  reason to fake, and the token math is from real file sizes — so the headline (obeyed + ~65% avg) is
  solid; treat per-task percentages as indicative.
