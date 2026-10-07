---
name: build
description: "Use when implementing any non-trivial feature, change, or fix: \"build me X\", \"add this feature\", \"implement this\", \"make this work\", \"can you create\". Covers new functionality, meaningful changes to existing code, and anything where quality matters: including small features, which still need verifying before \"done\". Only a literal one-line edit skips this."
---

# MasterMind: Build

The single "do it the genius way, end to end" workflow. It runs the loop from `~/.mastermind/engineering/core/agent-loop.md`,
pulling in the specialist agents and the field pack at each phase. Task: **$ARGUMENTS**.

Scale effort to the task (`~/.mastermind/engineering/core/principles.md`): a trivial change skips straight to implement+verify;
a foundation gets the full loop. Match the ceremony to what the task warrants.

**Spec-first work.** When the task qualifies for the full flow in
`~/.mastermind/engineering/core/spec-driven.md`, run its steps in place of steps 1 to 3: `specify`, then
`interview` on the spec, `blueprint`, `breakdown`, and `analyze` when it touches money, auth or data.
Then build from the task list below.

## Building from a task list

When the feature folder has a `tasks.md`, it is the plan. Steps 4 and 5 run per task. Step 6 runs once
per story, on that story's diff, at its checkpoint. The rules:

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
  treat the feature as done only when it reports converged.

## The loop

1. **Understand: and say how you read it.** Open with one line stating your interpretation, so a
   misread surfaces now instead of after the code exists: *"Reading this as: a bulk-import screen for
   ops staff, optimised for recovering from bad rows rather than for speed."* Then restate the real
   problem and its scope/lifespan; do the asked task and nothing more
   (`~/.mastermind/engineering/core/rigor.md` → Stay in scope). Read the relevant existing code and conventions first (delegate
   wide reading to a subagent to protect context); learn the stack if unfamiliar (`~/.mastermind/engineering/core/agent-loop.md`
   → Learn the stack first). Match the codebase.

2. **Design** (non-trivial only): invoke the **`architect`** agent to produce the blueprint:
   module/component boundaries + interfaces, state model, data flow, key types, edge-case list. For a
   multi-file or unfamiliar change, write the design/spec down before coding. Skip for a clear one-file fix.
   **Cut the work into thin vertical slices, never horizontal layers.** A slice crosses every layer
   and is visible when it lands. Left alone a model builds horizontally, all the data layer, then all
   the API, then all the UI, which is faster to write and hides every integration failure until the
   end. The rate of feedback is the ceiling on quality, so the slice exists to move that failure
   forward.
   **Show the shape before you write it, not in prose.** The types, the signatures, the call stack, the
   file layout: the forms in `~/.mastermind/skills/clarify/SKILL.md`. This is the internal detail
   that never reaches an architecture document and that a model still gets wrong, and it is far cheaper
   to correct a call tree than the code under it. One screen, then build.

3. **Decide the stack**: apply the active field's `stack-defaults.md` when a field pack exists. Choose the simplest thing that
   fully works; deviate only for a stated reason. Consult `mentors.md` if a call is contested.

> **Plan-first gate (opt-in, off by default).** If the project's **`plan-first`** preference is on
> (`.mastermind/prefs.md`: `plan-first: on`): or the user asks to "plan first": **plan first, then edit.**
> Present a concise plan from steps 1–3: the **goal**, the **approach**, the **files you'll touch**, the
> **steps**, and any risk/decision worth a look.
>
> **The bar:** clear enough for *a capable engineer with no context on this project* to follow without
> asking you anything. That means **exact file paths**, not "the auth module"; **bite-sized steps**, not
> "implement the feature"; and a stated way to **tell each step worked**. A plan records decisions, not
> code: a plan longer than the code it describes has written the code instead. If a step needs you to
> already know something the plan doesn't say, it isn't written yet. Then **stop and wait for the user's go-ahead** (this
> overrides the usual "decide and do" for this project, they opted in). If they adjust it, fold that in and
> re-show. **On approval, announce `🧠 MasterMind ▸ implementing the plan` with `└ build · implement → verify → review` beneath it, then proceed to step 4.** Skip the
> gate entirely for a trivial one-liner (match effort to stakes). It's for changes worth reviewing first.

4. **Implement to rigor** (`~/.mastermind/engineering/core/rigor.md`), build against the design. Handle the unhappy paths
   (null/empty/loading/error/zero/one/many/offline/unauthorized/malformed). Types honest, no lazy
   placeholders, no dead code. Single-purpose units. Style like the surrounding code.

5. **Verify: close the loop** (`~/.mastermind/engineering/core/agent-loop.md`; the `qa` skill): prove it works by driving
   the real thing: typecheck + lint + build, run the project's **existing** tests, and for UI exercise the
   actual flow / screenshot. Show the evidence; never assert success. If you can't verify it, it isn't
   done. Fix root causes. **Don't add tests or a test framework unprompted** (tests a task list or the
   constitution requires are not unprompted): once it works, *offer:*
   "Built and verified, want me to add tests / do this test-first?"

6. **Adversarial review**: invoke the **`code-reviewer`** agent on the diff in a fresh context. Fix
   real must-fix findings (correctness/security/a11y); treat gap-hunting nits as optional to avoid
   over-engineering. Re-verify after fixes.

   A re-review looks only at the earlier findings and the diff that fixed them. Anything new it notices
   elsewhere is reported once and does not extend the loop.

   **Close the loop in a bounded number of rounds: three.** Fix, re-review, repeat. If findings are
   still open after the third, stop looping and **decide each one in writing**: fixed · *parked* (why
   it's real but not blocking, in one line) · *blocked* (it's load-bearing and needs the human). Three
   rounds without convergence means the disagreement isn't about this diff. It's about the design, and
   more rounds just relitigate it more expensively.

   Two things this loop must never do: **adjudicate early** to escape another round. That's
   pre-judging with a nicer name: and **drop a finding silently**. Every finding exits as fixed,
   parked-with-a-reason, or escalated, and the user can see which.

7. **Capture & report**: run the **`levelup`** skill (capture) to fold any durable lesson
   or correction into the active field's `lessons.md`. Report honestly in a few lines: what shipped,
   the evidence it works, and anything deferred. Commit / open a PR only if asked. If the project's
   **`cycle-report`** preference is on (`.mastermind/prefs.md`: `markdown`/`html`, or `ask` → offer once),
   also run the **`report`** skill to write a durable file: **default is off**, so most cycles just get
   this in-chat verdict. Skip it entirely for a one-line change.

## What you noticed but left alone

You will pass broken windows on the way: a stale import, a misleading name, a function that wants
splitting. Fixing them buries the change you were asked for in a diff nobody can review. **Collect them
instead**, and hand the list back at the end:

```text
Noticed, not touched:
  · src/utils/format.ts: unused import, unrelated to this change
  · OrderRow re-renders on every parent tick: pre-existing, would need its own slice
→ Want tasks for these?
```

Costs one line, keeps the diff honest, and the user gets the observation without paying for unrequested
work: a reviewer can then see the whole change and believe it.

## Non-negotiables
Correctness, security, accessibility are never traded for speed. Speed is the reward for rigor. If an
approach is wrong or unsafe, say so once with the better option (`~/.mastermind/engineering/core/rigor.md` refuse-list), then proceed.
