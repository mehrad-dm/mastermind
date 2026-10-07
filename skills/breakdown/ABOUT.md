---
title: Breakdown: a task list where every story ships on its own
blurb: Turning a spec and plan into small, traceable tasks, grouped so each user story is a working slice.
since: 0.33.0
---

## The problem this solves

Ask an AI to build a feature and it usually works in layers: every database table, then every service,
then every screen. It is a natural order and a dangerous one, because nothing runs until the last layer
lands, so every integration problem is discovered at once, at the end.

## How it actually works

MasterMind writes `tasks.md` in the feature folder, from the spec and the plan:

- **Grouped by user story, in priority order.** Each story is a vertical slice through every layer it
  needs, ending in a checkpoint that runs that story's independent test. After the first story you have
  something that works, not a finished layer waiting on the rest.
- **One line per task, in a fixed shape**: an ID, whether it can run in parallel, which story it serves,
  the exact file, and the requirement IDs it satisfies. That shape is what later lets MasterMind check that
  every requirement has a task, and later still, that every task really has code.
- **Constraints copied in.** A field with a length limit or allowed values carries that rule into its
  task, so it is not left to memory at build time.
- **Tests only when they are required**, by your project's rules, the spec, or you. Otherwise every
  change is still verified end to end, and tests are offered afterwards.

Before writing the file, MasterMind checks that every requirement and acceptance criterion maps to at
least one task, and reports any that do not. An existing task list with ticked boxes is amended, never
regenerated, so progress is not lost.

## When it fires

> *"Break this into tasks."*
> *"What are the steps to build the invitations feature?"*
> *"The plan changed, update the task list."*

```
🧠 MasterMind ▸ cutting the plan into tasks, one story at a time
   └ breakdown · setup → foundation → story slices → polish
```

## When it does *not* fire

- **A feature with no plan yet.** The plan comes first, from `blueprint`.
- **A quick to-do list for one session.** That is just conversation; it needs no file.

## What you get

An ordered, traceable task list that `build` works through, where each story is usable the moment its
checkpoint passes.
