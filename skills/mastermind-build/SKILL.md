---
name: mastermind-build
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

4. **Implement to rigor** (`~/.mastermind/engineering/core/rigor.md`) — build against the design. Handle the unhappy paths
   (null/empty/loading/error/zero/one/many/offline/unauthorized/malformed). Types honest, no lazy
   placeholders, no dead code. Single-purpose units. Style like the surrounding code.

5. **Verify — close the loop** (`~/.mastermind/engineering/core/agent-loop.md`) — give the work a check that returns pass/fail
   and run it: typecheck + lint + tests + build, and for UI, exercise the actual flow / screenshot.
   Show the evidence; never assert success. If you can't verify it, it isn't done. Fix root causes.

6. **Adversarial review** — invoke the **`code-reviewer`** agent on the diff in a fresh context. Fix
   real must-fix findings (correctness/security/a11y); treat gap-hunting nits as optional to avoid
   over-engineering. Re-verify after fixes.

7. **Capture & report** — run the **`mastermind-levelup`** skill (capture) to fold any durable lesson
   or correction into the active field's `lessons.md`. Report honestly in a few lines: what shipped,
   the evidence it works, and anything deferred. Commit / open a PR only if asked.

## Non-negotiables
Correctness, security, accessibility are never traded for speed. Speed is the reward for rigor. If an
approach is wrong or unsafe, say so once with the better option (`~/.mastermind/engineering/core/rigor.md` refuse-list), then proceed.
