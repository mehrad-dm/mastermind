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
# baseline: user-level settings and memory excluded, HOME untouched
cd /tmp/empty-dir      && claude -p --setting-sources project,local "<task>"
# treatment: same flag, same model; the ONLY difference is a project with MasterMind installed
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

- `tasks/*.md`: 15 single-shot tasks, retired as a measure of the trust layer (see the note at the
  top) and kept as history and for weaker-model regression checks.
  - 01 to 08, the original set: state modeling, illegal states, root-cause debugging, an untrusted
    API boundary, a simplifying refactor, an XSS boundary, an accessible dropdown, and a YAGNI
    **restraint** control (where over-engineering must lose).
  - 09 to 13, cross-field: a backend API handler, N+1 data access, an algorithm with edge-case
    traps, a shell-injection boundary, and resource cleanup on every path.
  - 14 and 15, the rules themselves: whether a rule holds when it is reworded, and whether the
    rigor gate holds under pressure.
- `runs/`: the living suite. `v0.27-real/` (the seed repository, the scripted checks and `run.mjs`),
  `v0.27-set2/` and `v0.28-headtohead/`, each with its `SUMMARY.json`.
- `pilot-multimodel/`: the multi-model pilot, with its own tasks and results.
- `mechanism-v0.24.0/`: keys, rubrics and outputs from the mechanism runs.
- `judge-prompt.md`: the blind rubric-scoring prompt for an LLM-judge.
- `RESULTS.md`: the running log of scores (date · model · task · baseline · treatment · delta).

## The five scripts

Two need no model and gate every pull request. Three drive a live session, cost money or quota,
and report "could not run" (exit 2) when the tool, the login or the quota is missing: that is
never counted as a pass, and never as a routing miss.

| Script | Live? | What it measures | Fails when |
| --- | --- | --- | --- |
| `agent-surface-routing.mjs` | no | every skill reaches the routing table for every request, and how often the keyword arrows land | a skill on disk is missing from the table, a request has more than three skills hinted, or fewer than `MIN_HINTED` percent (default 50) of the paraphrased requests are hinted |
| `agent-surface-cost.mjs --strict` | no | characters spent routing through the CLI against inlining every skill | the saving falls under `MIN_SAVING` percent (default 65) |
| `auto-invoke.mjs` | Claude Code | which skill a session invokes from a plain request, on a seeded repository | fewer than three in four sessions invoke the expected skill |
| `codex-routing.mjs` | Codex | which skill a `codex exec` session names, with the brain and in a bare project | a case does not route with the brain |
| `cursor-routing.mjs` | Cursor | the same, through the Cursor CLI (`cursor-agent` or `agent`) | a case does not route with the brain |

Settings, all optional:

- `auto-invoke.mjs`: `FULL=1` runs every case with three repetitions, `REPS`, `MODEL` (default
  `sonnet`), `POOL`, `ONLY=<text in the prompt>`, `CROWDED=1` adds foreign skill packs. With
  `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` set, the sessions run under a scratch `HOME`.
  Without one they need your own login, so they keep your `HOME` and auto-memory is pointed at a
  scratch directory.
- `codex-routing.mjs`: `REPS` (default 1), `MM_CODEX_MODEL` (default: the first model
  `codex debug models` lists for your account), `MM_CODEX` when the command is not `codex` on
  `PATH`, for example `MM_CODEX="npx -y @openai/codex"`. Each call marks its scratch project as
  trusted for that call only, because Codex 0.150 and later ignores `AGENTS.md` in a project it
  does not trust.
- `cursor-routing.mjs`: `REPS` (default 1), `MM_CURSOR` to name the binary.

No skill sets `disable-model-invocation`: hidden from the model, `help` and `signature` went from
2/2 to 0/2 on a plain request. Six skills run only on request (help, handoff, report, levelup, lint,
signature) and say so in their descriptions. One case in the default set asserts that a plain
end-of-day remark fires none of `handoff`, `report` or `levelup`. `auto-invoke.mjs` still reads the
flag, so a skill that sets it is scored by the menu route (opening its file or asking the CLI).

Both routing evals print the control beside the treatment for every case. The control is reported
and never gated: these skill names are guessable, so a bare session often names them too.

The prompts are written the way a user would speak and must not borrow a phrase from the
description of the skill they target: a prompt that reuses its target's own words measures string
matching. `node evals/auto-invoke.mjs --self-test` holds that line: it fails when a prompt shares
three words in a row with its target's description, and starts no session. The paraphrased set in
`agent-surface-routing.mjs` is the one deliberate exception, said so in that file.

`classify.mjs` holds the rules for telling a failed session from a routing miss, and
`node evals/classify.mjs --self-test` runs them against recorded output without a model. A Claude
Code session is an observation only when it exited 0 and wrote a `result` record (one that ran out
of turns exits 1 after writing it, and still counts). Any other exit, a signal, empty output or
text that is not stream-json is "could not run", so a negative case can never pass on a session
that produced nothing. A Codex or Cursor call that exits 0 with an account message or nothing at
all is "could not run" too, never a miss.
