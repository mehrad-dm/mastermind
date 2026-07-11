# MasterMind Evals — proof, not vibes

The honest problem: MasterMind claims to make an AI's output *better*, but a claim without measurement
is faith. This is the apparatus that turns it into evidence. It won't tell you MasterMind is good; it
tells you **by how much, on which tasks, with which model** — and where it doesn't help.

## The method (offline, rubric-based, baseline-vs-treatment)

For each task in `tasks/`:

1. **Two conditions, same model, same prompt.**
   - **baseline** — the model with *no* MasterMind loaded.
   - **treatment** — the same model with MasterMind **actually loaded** (see Fidelity below), *not* a
     hand-written summary of its principles.
2. **Score each output against the task's rubric** — a list of **objective, binary** criteria (met / not
   met). Use an **independent LLM-judge** (a *different* model than the one under test) given only the
   rubric + the outputs, **blind to which is which** (shuffle order), required to quote evidence before
   scoring (per Anthropic's rubric-judge guidance). A human can score too; the rubric is the same.
3. **Record** the pass-rate per condition in `RESULTS.md`. The **delta (treatment − baseline)** is the
   result. Run each task **≥3 times** and average — single runs are noise.

### Fidelity — test the real mechanism, not a summary (learned the hard way)

Runs 1–2 gave the treatment agent a *hand-written summary* of MasterMind's principles. That is **low
fidelity** — it tests "does a good prompt help," not "does MasterMind help." The real mechanism is the
**actual pack loaded + the matching skill invoked**. So a treatment run must:
- **Load the real files** — the agent reads the actual `CLAUDE.md` kernel + the relevant
  `engineering/core/*` and `engineering/fields/<field>/{stack-defaults,lessons}.md`, not a paraphrase.
- **Invoke the matching skill** for the task type — e.g. `mastermind-debug` for a bug/perf task,
  `code-reviewer` for a review. That's how a real session behaves.

**This is not cosmetic — it changes the result.** On task 03 (debugging), the summary-treatment *lost*
(0.67 vs 0.80 baseline); the **real-pack** treatment **won (1.00 vs 0.80)** — and produced the structural
fix unaided, one run citing `lessons.md` directly. Lower fidelity *understated* MasterMind and hid that a
captured lesson actually surfaces. Cost: the agent spends tokens reading the pack — worth it for an
honest number. (Baseline stays a plain model with nothing loaded — that's the fair "without".)

### The bar for a public claim (learned from Runs 1–2)
A single judge is noisy (Run 2 graded the same pattern 0.20 in one output and 0.80 in another). Before
any number goes on the website:
- **≥3 independent judges** per output; take the **median** score per criterion (majority vote). Report
  inter-judge agreement — if judges disagree wildly on a task, the rubric is ambiguous; fix it.
- **All ≥8 tasks**, N≥3 generations per condition.
- **Stable across two separate runs** (deltas within ~±0.1). One good run is a fluke, not evidence.
- A genuinely different baseline (a weaker/plain model) would strengthen it further; until then, be
  explicit the delta is "guidance in-context," not "vs. a weaker model."

## What we measure (and why it's honest)

- **Quality** = rubric criteria met. Criteria encode MasterMind's own principles (correctness, edge
  cases, right data model, no reinvented a11y), so passing them *is* "wrote good code."
- **Over-engineering penalty** — every rubric ends with anti-criteria (speculative abstraction,
  unrequested scope, needless deps). This stops MasterMind from "winning" by adding complexity — the
  exact failure its own `rigor.md` refuse-list warns about.
- **Delta, not absolute** — a frontier model already scores well; the question is whether MasterMind
  moves the needle *and doesn't regress* anything.

## Running it

There is no magic button, and pretending otherwise would be the dishonesty this whole file exists to
kill. Producing numbers means actually running each task in both conditions and scoring — by hand or
by wiring `judge-prompt.md` into whatever agent runner you use. The harness is the tasks + rubrics +
protocol; the evidence is what you get when you run them. Re-run per model and per MasterMind version —
results drift as both change.

## Honest limitations

- **Small N** — a handful of tasks is a smoke test, not a benchmark like SWE-bench. Treat it as signal.
- **Judge bias** — LLM judges have known biases (length, position); blind + shuffled + evidence-first
  mitigates, doesn't eliminate. Spot-check against a human.
- **Construct validity** — the rubrics encode *our* definition of good. They're defensible, not
  objective truth. Improve them as they're proven too lax or too strict.

## Files
- `tasks/*.md` — 8 tasks: data-modeling, illegal-states, debugging, untrusted API, refactor/simplify,
  XSS boundary, a11y primitive, and a YAGNI **restraint** control (where over-engineering must lose).
- `judge-prompt.md` — the blind rubric-scoring prompt for an LLM-judge.
- `RESULTS.md` — the running log of scores (date · model · task · baseline · treatment · delta).
