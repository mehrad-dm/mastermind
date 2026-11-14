---
name: build
description: "Use when implementing any feature, change or fix whose scope is clear enough to start: \"build me X\", \"add this feature\", \"implement this\", \"make this work\", \"can you create\". Small features included: they still need verifying before \"done\". Not for a literal one-line edit, an ask whose scope is unsettled (`interview`), or a bug with no known cause (`debug`)."
---

# MasterMind: Build

Implement the task end to end and hand it back verified. Task: **$ARGUMENTS**.

Scale effort to the task (`~/.mastermind/engineering/core/principles.md`): a trivial change is
implement and verify; a foundation gets everything below.

**Spec-first work.** When the task qualifies for the full flow in
`~/.mastermind/engineering/core/spec-driven.md`, run its steps first: `specify`, then `interview` on
the spec, `blueprint`, `breakdown`, and `analyze` when it touches money, auth or data. Then build from
the task list below.

## Building from a task list

When the feature folder has a `tasks.md`, it is the plan. Implement and verify each task. Review runs
once per story, on that story's diff, at its checkpoint. The rules:

- **Work in order, phase by phase.** Tasks marked `[P]` may run together; everything else waits for the
  task before it.
- **Tick a box only after that task's own check passes**: the file exists, the command is green, the
  behavior is observed. Never tick ahead.
- **Stop at each story checkpoint.** Run the story's independent test and show the evidence before
  starting the next story.
- **A task that cannot be done as written** is reported, with the reason. Never improvise around it, and
  never tick it.
- **A test task's check is its failure.** Write the test, run it, and see it fail for the reason the task
  names before writing the code. A test that passes on first run proves nothing yet.
- **Plans change through their own skill.** A task that needs a different spec or plan stops and goes
  back to `specify` or `blueprint`. A product answer the user gives lands in the spec's Clarifications.
- **Record every technical ruling you make.** When the documents leave a reversible technical choice
  open, decide it and add one line under the task: `Ruling: <what> · <why> · <cost if wrong>`. List all
  of them in the final report. A product choice is never a ruling: it goes to the user.
- **Set the spec's status to `building`** at the first task. After the last task, run `converge`, and
  treat the feature as done only when it reports converged. At each story checkpoint, run `mastermind
  next` and end with the step it names.

## What a finished build has

These are outcomes, not a script. Reach each one in the order the task needs. A small change needs
only the stated reading, the code and the proof.

**A stated reading of the ask.** Open with one line that says how you read it, so a misread surfaces
before the code exists: *"Reading this as: a bulk-import screen for ops staff, optimised for recovering
from bad rows rather than for speed."* Do the asked task and nothing more
(`~/.mastermind/engineering/core/rigor.md` → Stay in scope).

**The existing code, read before you write.** Match its conventions. Learn the stack first when it is
unfamiliar (`~/.mastermind/engineering/core/agent-loop.md` → Learn the stack before you build).

**A design sized to the change.** The kernel names when the `architect` agent is used: a decision that
crosses a module boundary, the data model or a public API. Below that, design it yourself. Either way:

- **Cut the work into thin vertical slices, never horizontal layers.** A slice crosses every layer and
  is visible when it lands. Building all the data layer, then all the API, then all the UI hides every
  integration failure until the end.
- **Show the shape before you write it.** Types, signatures, the call stack, the file layout: the
  forms in `~/.mastermind/skills/clarify/SKILL.md`. One screen. A call tree is cheaper to correct than
  the code under it.

**A stack choice with a reason.** Apply the active field's `stack-defaults.md` when a field pack
exists. Choose the simplest thing that fully works; deviate only for a stated reason.

> **Plan-first gate (opt-in, off by default).** If the project's **`plan-first`** preference is on
> (`.mastermind/prefs.md`: `plan-first: on`): or the user asks to "plan first": **plan first, then edit.**
> Present a concise plan: the **goal**, the **approach**, the **files you'll touch**, the **steps**, and
> any risk/decision worth a look.
>
> **The bar:** clear enough for *a capable engineer with no context on this project* to follow without
> asking you anything. That means **exact file paths**, not "the auth module"; **bite-sized steps**, not
> "implement the feature"; and a stated way to **tell each step worked**. A plan records decisions, not
> code: a plan longer than the code it describes has written the code instead. Then **stop and wait for
> the user's go-ahead** (they opted in, so this overrides the usual "decide and do"). If they adjust it,
> fold that in and re-show. **On approval, announce `🧠 MasterMind ▸ implementing the plan`, then
> implement.** Skip the gate for a trivial one-liner.

**Code written to rigor** (`~/.mastermind/engineering/core/rigor.md`). The unhappy paths are handled:
null, empty, loading, error, zero, one, many, offline, unauthorized, malformed. Types are honest. No
placeholders, no dead code. It reads like the surrounding code.

**Proof that it works.** Drive the real thing: typecheck, lint, build, the project's **existing**
tests, and for a UI the actual flow (the `qa` skill has the ladder). Show the evidence; never assert
success. A check that cannot run is handled by the rule in
`~/.mastermind/engineering/core/rigor.md` → After writing: the verdict is then **Done, not fully
checked**, never "not done". Fix root causes. **Don't add tests or a test
framework unprompted.** Tests that a task list or the constitution requires are not unprompted.
Otherwise, offer tests as one line under **Suggested (not done)**.

**A review, when the kernel's threshold requires one.** The kernel states the threshold; it is not
restated here. When it applies, send the diff and the requirement to the `code-reviewer` agent in a
fresh context, never to a fork of this session. Below the threshold, self-check and say "self-checked"
in the closing line. For a reviewed change:

- **Fix the must-fix findings** (correctness, security, accessibility), then re-verify. Gap-hunting
  nits are optional.
- **A re-review looks only at the earlier findings and the diff that fixed them.** Anything new it
  notices elsewhere is reported once and does not extend the loop.
- **Three rounds at most** (`~/.mastermind/engineering/core/agent-loop.md` → stop conditions). Two
  consecutive rounds with no new finding end the loop early.
- **After the last round, decide each open finding in writing**: fixed · *parked* (real but not
  blocking, with the reason) · *blocked* (load-bearing, needs the user). Three rounds without
  convergence means the disagreement is about the design, not this diff.
- **Never adjudicate early to escape a round, and never drop a finding silently.** Every finding
  exits as fixed, parked with a reason, or blocked, and the user can see which.
- **End the last round with one question to the reviewer: "What did this change miss?"** It is asked
  once. Act on an answer that affects correctness or a stated requirement; list the rest.

**A report.** The evidence first, then the verdict with its `not checked:` and `decided for you:`
lines (the kernel has the form). Commit or open a PR only when asked. Run `levelup` (capture) only when
the work produced a durable lesson or a correction. If the project's **`cycle-report`** preference is
on (`.mastermind/prefs.md`: `markdown`/`html`, or `ask` → offer once), also follow the `report` skill.
The default is off.

## What you noticed but left alone

You will pass broken windows on the way: a stale import, a misleading name, a function that wants
splitting. Fixing them buries the change you were asked for in a diff nobody can review. Collect them
in the kernel's **Suggested (not done)** list; `~/.mastermind/engineering/core/rigor.md` → Stay in
scope has the format.

## Non-negotiables

Correctness, security, accessibility are never traded for speed. If an approach is wrong or unsafe,
say so once with the better option (`~/.mastermind/engineering/core/rigor.md` refuse-list), then proceed.
