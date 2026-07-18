---
name: build
description: The flagship MasterMind build loop — take a feature/change from intent to shipped, the genius way, end to end. Orchestrates design → plan → implement-to-rigor → verify → adversarial review → capture-lessons. Use for any non-trivial implementation task where quality matters. For a one-line diff, skip this and just do it.
---

# MasterMind — Build

The single "do it the genius way, end to end" workflow. It runs the loop from `~/.mastermind/engineering/core/agent-loop.md`,
pulling in the specialist agents and the field pack at each phase. Task: **$ARGUMENTS**.

Scale effort to the task (`~/.mastermind/engineering/core/principles.md`): a trivial change skips straight to implement+verify;
a foundation gets the full loop. Don't perform ceremony the task doesn't warrant.

## The loop

1. **Understand** — restate the real problem and its scope/lifespan; do the asked task and nothing more
   (`~/.mastermind/engineering/core/rigor.md` → Stay in scope). Read the relevant existing code and conventions first (delegate
   wide reading to a subagent to protect context); learn the stack if unfamiliar (`~/.mastermind/engineering/core/agent-loop.md`
   → Learn the stack first). Match the codebase.

2. **Design** (non-trivial only) — invoke the **`architect`** agent to produce the blueprint:
   module/component boundaries + interfaces, state model, data flow, key types, edge-case list. For a
   multi-file or unfamiliar change, write the design/spec down before coding. Skip for a clear one-file fix.

3. **Decide the stack** — apply the active field's `stack-defaults.md`. Choose the simplest thing that
   fully works; deviate only for a stated reason. Consult `mentors.md` if a call is contested.

> **Plan-first gate (opt-in, off by default).** If the project's **`plan-first`** preference is on
> (`.mastermind/prefs.md`: `plan-first: on`) — or the user asks to "plan first" — **do not start editing yet.**
> Present a concise plan from steps 1–3: the **goal**, the **approach**, the **files you'll touch**, the
> **steps**, and any risk/decision worth a look. Then **stop and wait for the user's go-ahead** (this
> overrides the usual "decide and do" for this project — they opted in). If they adjust it, fold that in and
> re-show. **On approval, announce `🧠 MasterMind ▸ implementing the plan` and proceed to step 4.** Skip the
> gate entirely for a trivial one-liner (match effort to stakes) — it's for changes worth reviewing first.

4. **Implement to rigor** (`~/.mastermind/engineering/core/rigor.md`) — build against the design. Handle the unhappy paths
   (null/empty/loading/error/zero/one/many/offline/unauthorized/malformed). Types honest, no lazy
   placeholders, no dead code. Single-purpose units. Style like the surrounding code.

5. **Verify — close the loop** (`~/.mastermind/engineering/core/agent-loop.md`; the `qa` skill) — prove it works by driving
   the real thing: typecheck + lint + build, run the project's **existing** tests, and for UI exercise the
   actual flow / screenshot. Show the evidence; never assert success. If you can't verify it, it isn't
   done. Fix root causes. **Don't add tests or a test framework unprompted** — once it works, *offer:*
   "Built and verified — want me to add tests / do this test-first?"

6. **Adversarial review** — invoke the **`code-reviewer`** agent on the diff in a fresh context. Fix
   real must-fix findings (correctness/security/a11y); treat gap-hunting nits as optional to avoid
   over-engineering. Re-verify after fixes.

7. **Capture & report** — run the **`levelup`** skill (capture) to fold any durable lesson
   or correction into the active field's `lessons.md`. Report honestly in a few lines: what shipped,
   the evidence it works, and anything deferred. Commit / open a PR only if asked. If the project's
   **`cycle-report`** preference is on (`.mastermind/prefs.md`: `markdown`/`html`, or `ask` → offer once),
   also run the **`report`** skill to write a durable file — **default is off**, so most cycles just get
   this in-chat verdict. Skip it entirely for a one-line change.

## Non-negotiables
Correctness, security, accessibility are never traded for speed. Speed is the reward for rigor. If an
approach is wrong or unsafe, say so once with the better option (`~/.mastermind/engineering/core/rigor.md` refuse-list), then proceed.
