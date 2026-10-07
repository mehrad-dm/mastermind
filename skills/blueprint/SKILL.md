---
name: blueprint
description: Use when a written feature spec needs its technical plan: "plan this spec", "how should we build this spec?", "make the technical plan for this feature", a spec in specs/ with no plan.md yet, or a plan that a spec or constitution change has made stale. Not for a feature with no spec (that's `specify`, or `build` for a small one), not for one design question outside any feature (that's the `architect` agent).
---

# MasterMind: Blueprint

The plan turns the spec's **what** into a **how** that can be checked against the constitution before a
line is written. Layout and IDs: `~/.mastermind/engineering/core/spec-driven.md`. Input: **$ARGUMENTS**.

## Before planning

1. **Find the feature folder** and read `spec.md` in full, plus `specs/constitution.md`, `specs/tech.md`,
   and the active field's `stack-defaults.md` when a field pack exists.
2. **Refuse to plan over open questions.** If `[NEEDS CLARIFICATION]` markers remain, run `interview`
   first. When the user insists on skipping, proceed and record the open markers as risks in `plan.md`.
3. **Run the constitution gate.** For each principle, write `pass`, `n/a` or `violates` in the plan's
   gate table. A violation stops the plan until the user accepts it in the complexity table.

## Plan

Write `plan.md` from `specs/.templates/plan.md` if present, else [`template.md`](template.md). Then:

1. **Technical context.** Language, dependencies, storage, testing, platform, performance and scale
   targets. Each value comes from `tech.md`, the code, or a decision you make in step 2.
2. **Research the unknowns.** One entry in `research.md` per real decision: *chosen*, *why*, *rejected and
   why*. Read the primary source for anything version-sensitive (`learn`). Library choices with real
   adoption risk go to the `tech-scout` agent.
3. **Design.** Dispatch the `architect` agent with the spec, the constitution and `tech.md`. Its output
   becomes the plan's design section. Keep the boundaries, data model, contracts and the reason for each.
   Where no isolated agent exists, follow `architect`'s method yourself and say so in the plan.
4. **Write what the design implies**, each only when it has content:
   - `data-model.md`: entities with fields, validation rules taken from the spec, relationships, state changes.
   - `contracts/`: every interface another system or user depends on, in the form the project already uses.
   - `quickstart.md`: the runnable steps that prove the feature works end to end, with expected output.
5. **Name the real paths.** The structure section lists the actual directories and files to create or
   change in this repository. Never a generic layout.
6. **Re-run the gate** against the finished design. Set the spec's status to `planned`.

## Gotchas

- **The plan is not the code.** No function bodies, no full migrations, no test suites. Signatures and
  shapes only; the code is `build`'s job.
- **Every decision traces to a requirement.** A dependency, service or layer nobody asked for goes in
  the complexity table with the simpler option it beat, or it goes.
- **Match the repository.** A plan that introduces a second ORM, router or state library has to justify
  it against the one already there.
- **A requirement the plan cannot meet is a finding, not a footnote.** Report it to the user before
  `breakdown` runs.

## Report

The files written, the decisions with one-line reasons, the gate result before and after design, any
accepted violation, and the next step: `breakdown`, or `checklist` first for a sensitive feature.
