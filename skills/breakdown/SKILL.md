---
name: breakdown
description: "Use when a feature with a spec and a plan needs its ordered task list: \"break this into tasks\", \"make the task list\", \"what are the steps to build this?\", \"generate tasks.md\", a feature folder with plan.md and no tasks.md, or a task list made stale by a spec or plan change. Not for a feature with no plan (that's `blueprint`), not for one session's to-do list."
---

# MasterMind: Breakdown

`tasks.md` is the build order: small enough that each task is checkable, ordered so each user story
ships alone. Layout and IDs: `~/.mastermind/engineering/core/spec-driven.md`. Input: **$ARGUMENTS**.

## Read first

`spec.md` for the stories and their priorities, `plan.md` for paths and structure, then `data-model.md`,
`contracts/`, `research.md` and `quickstart.md` where they exist. Use `specs/.templates/tasks.md` if
present, else [`template.md`](template.md).

## The task line

```text
- [ ] T014 [P] [US1] Add the export button to src/reports/ReportHeader.tsx (US1/AC1, FR-002)
```

- `- [ ]` then a `T###` ID in execution order. IDs are never reused or renumbered.
- `[P]` only when it touches different files from every unfinished task before it.
- `[US#]` on every task inside a story phase, and on no other.
- The exact file path, and the spec IDs it serves in parentheses.

## The phases

1. **Setup**: what the project needs before anything else, such as dependencies, config and env vars.
2. **Foundation**: what every story needs and no story can deliver alone. Keep it small; most work
   belongs to a story.
3. **One phase per user story, in priority order.** Each is a vertical slice: its models, logic,
   interfaces and wiring, ending in a **checkpoint** that runs the story's independent test.
4. **Polish**: cross-cutting work that touches several stories.

Delete a phase with no tasks. Never write a heading over "None".

Refactoring the code needs before a story can land goes first, as its own tasks in Foundation. A change
too wide for one slice, such as renaming a column every story reads, is sequenced expand, migrate,
contract (`deprecate`), never forced into a story.

Within a story: tests first when they are required, then data, then logic, then the surface, then the
wiring that connects them.

## Rules

- **Tests are tasks only when required.** Required means the constitution demands them, the spec asks
  for them, or the user said so. Otherwise `qa` verifies, and tests are offered after the build.
- **Quote the constraint.** A field with a length limit, an enum or a validation rule from
  `data-model.md` has that rule copied into its task, so it is not left to memory at build time.
- **Every requirement gets a task.** Before writing the file, check each `FR-###` and each acceptance
  criterion maps to at least one task. List any that do not in your report.
- **A task that needs "and" is two tasks.** One task, one change, one way to tell it worked.

## Gotchas

- **Horizontal phases are the failure this prevents.** "All models, then all services, then all UI"
  hides every integration bug until the end. Group by story, never by layer.
- **Do not plan here.** A task that introduces a library, file or pattern the plan does not mention
  means the plan is incomplete. Fix `plan.md`, then the tasks.
- **Regenerating loses progress.** When a `tasks.md` with ticked boxes exists, add and amend tasks; never
  rewrite the file from scratch.

## Report

The task count per phase, the parallel opportunities, the requirements with no task, and the next
step: `analyze` before building a feature that touches money, auth or data, else `build`. Set the
spec's status to `tasked`.

Then run `mastermind next` and end with the step it names, so the user sees where the feature stands.
