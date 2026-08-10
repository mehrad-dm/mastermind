# MasterMind Evals: proof, not vibes

> **Single-shot tasks are retired as of 2026-08-01.** Runs V1–V3 proved it on 13 of 13 such
> tasks: a frontier model baselines at 0.8–1.0 on any one-shot prompt, so those tasks cannot
> measure a trust layer regardless of what it does: every future run on them is a pre-paid
> null. `tasks/01–13` stay only as historical record and for weaker-model regression checks.
> **The living suite is `runs/v0.27-real/`**: a multi-file seed repo, underspecified prompts,
> planted hazards, agentic runs: scored by objective scripted checks first (tests green,
> landmine tripped, guard deleted, query count) and LLM judges only where opinion is
> unavoidable.

The honest problem: MasterMind claims to make an AI's output *better*, but a claim without measurement
is faith. This is the apparatus that turns it into evidence. It won't tell you MasterMind is good; it
tells you **by how much, on which tasks, with which model**: and where it doesn't help.

## Run both arms in the same turn

Spawn the with-skill and without-skill runs **together**, not baselines-later. Model versions move,
prompts drift, and a baseline collected an hour after the treatment is comparing two different worlds: 
the drift then reads as an effect. Same turn, same conditions, same everything but the skill.

Report per arm: **pass rate, tokens, wall time, mean and spread**, then the delta. Spread matters as
much as the mean; two runs at 0.9 and 0.3 is not "0.6", it's an unreliable skill.

**A skill that doesn't beat its own absence is dead weight.** That is the whole point of keeping a
control: without one there is no way to retire anything, and a library only grows. When a skill can't
show a delta, the honest options are to sharpen it, narrow it to where it does help, or drop it: and
"we like it" is not among them.

**And check the failure is real before writing guidance at all.** Run the control first: if a model
without the skill already does the right thing, there's nothing to fix. Guidance for a failure that
doesn't occur is a no-op that costs context on every future turn.

## The method (offline, rubric-based, baseline-vs-treatment)

For each task in `tasks/`:

1. **Two conditions, same model, same prompt.**
   - **baseline**: the model with *no* MasterMind loaded.
   - **treatment**: the same model with MasterMind **actually loaded** (see Fidelity below), *not* a
     hand-written summary of its principles.
2. **Score each output against the task's rubric**: a list of **objective, binary** criteria (met / not
   met). Use an **independent LLM-judge** (a *different* model than the one under test) given only the
   rubric + the outputs, **blind to which is which** (shuffle order), required to quote evidence before
   scoring (per Anthropic's rubric-judge guidance). A human can score too; the rubric is the same.
3. **Record** the pass-rate per condition in `RESULTS.md`. The **delta (treatment − baseline)** is the
   result. Run each task **≥3 times** and average: single runs are noise.

### Fidelity: test the real mechanism, not a summary (learned the hard way)

Runs 1–2 gave the treatment agent a *hand-written summary* of MasterMind's principles. That is **low
fidelity**: it tests "does a good prompt help," not "does MasterMind help." The real mechanism is the
**actual pack loaded + the matching skill invoked**. So a treatment run must:
- **Load the real files**: the agent reads the actual `CLAUDE.md` kernel + the relevant
  `engineering/core/*` and `engineering/fields/<field>/{stack-defaults,lessons}.md`, not a paraphrase.
- **Invoke the matching skill** for the task type: e.g. `debug` for a bug/perf task,
  `code-reviewer` for a review. That's how a real session behaves.

**This is not cosmetic: it changes the result.** On task 03 (debugging), the summary-treatment *lost*
(0.67 vs 0.80 baseline); the **real-pack** treatment **won (1.00 vs 0.80)**: and produced the structural
fix unaided, one run citing `lessons.md` directly. Lower fidelity *understated* MasterMind and hid that a
captured lesson actually surfaces. Cost: the agent spends tokens reading the pack, worth it for an
honest number. (Baseline stays a plain model with nothing loaded: that's the fair "without".)

### Isolation: a subagent is NOT a clean baseline (learned the hard way, 2026-07-21)

The mirror image of the fidelity trap. If the "without MasterMind" condition is a **subagent spawned from
a session that has MasterMind loaded**, it inherits the brain from the session harness and is *not* a
baseline. This produced a null result that looked real: control and treatment both scored 4/4, because
both *were* MasterMind.

The tell: the control emitted the `🧠 MasterMind ▸` mark it should have had no way to know about.

**Removing the files mid-session does not fix it**: verified directly: with `~/.claude/CLAUDE.md`
deleted, a spawned subagent still behaved as MasterMind, because the session's harness already carried it.

**What actually works: a separate process**, which re-reads config at startup. Prefer the flag; it
mutates nothing:

```bash
# baseline — user-level settings and memory excluded, HOME untouched
cd /tmp/empty-dir      && claude -p --setting-sources project,local "<task>"
# treatment — same flag, same model; the ONLY difference is a project with MasterMind installed
cd /my-mastermind-proj && claude -p --setting-sources project,local "<task>"
```

`--setting-sources project,local` drops user-level config, so the global brain never loads. Verified
2026-07-26: a plain run answers *"MasterMind here, yes"*; the same run with the flag answers *"No: I'm
running as Claude, not MasterMind."* Because **both arms use the same flag**, blinding is symmetric: 
neither arm is the special-cased one, which is its own advantage over parking files.

The older method: `mv ~/.claude/CLAUDE.md /tmp/parked`, run, then move it back: also works but edits the
developer's own global setup, and a crash mid-run leaves it parked. Use it only if the flag is unavailable.
A fresh `HOME` is cleaner still but has no credentials, so it can't run.

### Give every run its own working directory (learned the hard way, 2026-07-26)

Runs of the same arm sharing one directory **grade each other**. Run 1 writes `useUser.ts`; runs 2 and 3
find those files and: correctly, per `rigor.md`, decline to overwrite existing work and *review* it
instead of authoring a solution. The tell: an output that says "these already existed, so I verified them."
Copy a pristine seed project per run.

And **ask both arms for the solution in the reply**, in byte-identical words. The treatment arm is agentic
and writes files; a baseline answers in chat. Without it you compare a chat answer against "done: see
`src/`", which scores where the output landed rather than how good it is.

**Check every baseline for contamination before trusting a Δ.** A control that scores suspiciously well,
or uses vocabulary only the treatment should know, is contaminated: not evidence of "no effect."

### The bar for a public claim (learned from Runs 1–2)
A single judge is noisy (Run 2 graded the same pattern 0.20 in one output and 0.80 in another). Before
any number goes on the website:
- **≥3 independent judges** per output; take the **median** score per criterion (majority vote). Report
  inter-judge agreement: if judges disagree wildly on a task, the rubric is ambiguous; fix it.
- **All ≥8 tasks**, N≥3 generations per condition.
- **Stable across two separate runs** (deltas within ~±0.1). One good run is a fluke, not evidence.
- A genuinely different baseline (a weaker/plain model) would strengthen it further; until then, be
  explicit the delta is "guidance in-context," not "vs. a weaker model."

## What we measure (and why it's honest)

- **Quality** = rubric criteria met. Criteria encode MasterMind's own principles (correctness, edge
  cases, right data model, no reinvented a11y), so passing them *is* "wrote good code."
- **Over-engineering penalty**: every rubric ends with anti-criteria (speculative abstraction,
  unrequested scope, needless deps). This stops MasterMind from "winning" by adding complexity: the
  exact failure its own `rigor.md` refuse-list warns about.
- **Delta, not absolute**: a frontier model already scores well; the question is whether MasterMind
  moves the needle *and doesn't regress* anything.

## Running it

There is no magic button, and pretending otherwise would be the dishonesty this whole file exists to
kill. Producing numbers means actually running each task in both conditions and scoring: by hand or
by wiring `judge-prompt.md` into whatever agent runner you use. The harness is the tasks + rubrics +
protocol; the evidence is what you get when you run them. Re-run per model and per MasterMind version: 
results drift as both change.

## Honest limitations

- **Small N**: a handful of tasks is a smoke test, not a benchmark like SWE-bench. Treat it as signal.
- **Judge bias**: LLM judges have known biases (length, position); blind + shuffled + evidence-first
  mitigates, doesn't eliminate. Spot-check against a human.
- **Construct validity**: the rubrics encode *our* definition of good. They're defensible, not
  objective truth. Improve them as they're proven too lax or too strict.

## Files
- `tasks/*.md`: 8 tasks: data-modeling, illegal-states, debugging, untrusted API, refactor/simplify,
  XSS boundary, a11y primitive, and a YAGNI **restraint** control (where over-engineering must lose).
- `judge-prompt.md`: the blind rubric-scoring prompt for an LLM-judge.
- `RESULTS.md`: the running log of scores (date · model · task · baseline · treatment · delta).
