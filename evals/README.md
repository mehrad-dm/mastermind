# MasterMind Evals — proof, not vibes

The honest problem: MasterMind claims to make an AI's output *better*, but a claim without measurement
is faith. This is the apparatus that turns it into evidence. It won't tell you MasterMind is good; it
tells you **by how much, on which tasks, with which model** — and where it doesn't help.

## The method (offline, rubric-based, baseline-vs-treatment)

For each task in `tasks/`:

1. **Two conditions, same model, same prompt.**
   - **baseline** — the model with *no* MasterMind loaded.
   - **treatment** — the same model with MasterMind loaded (`~/.mastermind` / the plugin).
2. **Score each output against the task's rubric** — a list of **objective, binary** criteria (met / not
   met). Prefer an **independent LLM-judge** given only the rubric + the two outputs, **blind to which is
   which** (shuffle order), required to quote evidence before scoring (per Anthropic's rubric-judge
   guidance). A human can score too; the rubric is the same.
3. **Record** the pass-rate per condition in `RESULTS.md`. The **delta (treatment − baseline)** is the
   result. Run each task **≥3 times** and average — single runs are noise.

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
- `tasks/*.md` — one task each: the prompt + an objective rubric (with anti-criteria).
- `judge-prompt.md` — the blind rubric-scoring prompt for an LLM-judge.
- `RESULTS.md` — the running log of scores (date · model · task · baseline · treatment · delta).
