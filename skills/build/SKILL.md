---
name: build
description: Use when implementing any non-trivial feature, change, or fix — "build me X", "add this feature", "implement this", "make this work", "can you create". Covers new functionality, meaningful changes to existing code, and anything where quality matters — including small features, which still need verifying before "done". Only a literal one-line edit skips this.
---

# MasterMind: Build

The single "do it the genius way, end to end" workflow. It runs the loop from `~/.mastermind/engineering/core/agent-loop.md`,
pulling in the specialist agents and the field pack at each phase. Task: **$ARGUMENTS**.

Scale effort to the task (`~/.mastermind/engineering/core/principles.md`): a trivial change skips straight to implement+verify;
a foundation gets the full loop. Match the ceremony to what the task warrants.

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

3. **Decide the stack**: apply the active field's `stack-defaults.md`. Choose the simplest thing that
   fully works; deviate only for a stated reason. Consult `mentors.md` if a call is contested.

> **Plan-first gate (opt-in, off by default).** If the project's **`plan-first`** preference is on
> (`.mastermind/prefs.md`: `plan-first: on`): or the user asks to "plan first": **plan first, then edit.**
> Present a concise plan from steps 1–3: the **goal**, the **approach**, the **files you'll touch**, the
> **steps**, and any risk/decision worth a look.
>
> **The bar:** clear enough for *an enthusiastic junior engineer with poor taste, no judgement, no project
> context, and an aversion to testing* to follow without asking you anything. That means **exact file
> paths**, not "the auth module"; **bite-sized steps**, not "implement the feature"; and a stated way to
> **tell each step worked**. If a step needs you to already know something the plan doesn't say, it isn't
> written yet. Then **stop and wait for the user's go-ahead** (this
> overrides the usual "decide and do" for this project, they opted in). If they adjust it, fold that in and
> re-show. **On approval, announce `🧠 MasterMind ▸ implementing the plan` with `└ build · implement → verify → review` beneath it, then proceed to step 4.** Skip the
> gate entirely for a trivial one-liner (match effort to stakes). It's for changes worth reviewing first.

4. **Implement to rigor** (`~/.mastermind/engineering/core/rigor.md`), build against the design. Handle the unhappy paths
   (null/empty/loading/error/zero/one/many/offline/unauthorized/malformed). Types honest, no lazy
   placeholders, no dead code. Single-purpose units. Style like the surrounding code.

5. **Verify: close the loop** (`~/.mastermind/engineering/core/agent-loop.md`; the `qa` skill): prove it works by driving
   the real thing: typecheck + lint + build, run the project's **existing** tests, and for UI exercise the
   actual flow / screenshot. Show the evidence; never assert success. If you can't verify it, it isn't
   done. Fix root causes. **Don't add tests or a test framework unprompted**: once it works, *offer:*
   "Built and verified, want me to add tests / do this test-first?"

6. **Adversarial review**: invoke the **`code-reviewer`** agent on the diff in a fresh context. Fix
   real must-fix findings (correctness/security/a11y); treat gap-hunting nits as optional to avoid
   over-engineering. Re-verify after fixes.

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
  · src/utils/format.ts — unused import, unrelated to this change
  · OrderRow re-renders on every parent tick — pre-existing, would need its own slice
→ Want tasks for these?
```

Costs one line, keeps the diff honest, and the user gets the observation without paying for unrequested
work: a reviewer can then see the whole change and believe it.

## Non-negotiables
Correctness, security, accessibility are never traded for speed. Speed is the reward for rigor. If an
approach is wrong or unsafe, say so once with the better option (`~/.mastermind/engineering/core/rigor.md` refuse-list), then proceed.
