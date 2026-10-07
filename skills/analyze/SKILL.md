---
name: analyze
description: "Use when a feature's spec, plan and task list all exist and need checking against each other before code is written: \"check the spec and plan agree\", \"is this ready to build?\", \"find gaps before we start\", \"analyze the feature docs\", or before building anything that touches money, auth or data from a task list. Not for checking code against intent after building (that's `converge`), not for analyzing code, performance or a bug."
---

# MasterMind: Analyze

A read-only consistency pass over `spec.md`, `plan.md`, `tasks.md` and the constitution, run before any
code exists, when a gap still costs a sentence instead of a rewrite. Layout and IDs:
`~/.mastermind/engineering/core/spec-driven.md`. Feature: **$ARGUMENTS**.

**It never edits a file.** It reports, then offers fixes the user approves.

## Who runs it

The context that wrote the documents already believes they agree. Dispatch a fresh-context subagent with
the four files and this skill's six passes, and nothing about how they were written. Where no isolated
context exists, run it yourself and label the report self-graded.

## The six passes

1. **Duplication.** Two requirements saying the same thing in different words. Keep the clearer one.
2. **Ambiguity.** Adjectives with no number ("fast", "secure", "scalable"), and unfilled template
   text: `TODO`, `???`, a template's own `<placeholder>` lines, unresolved `[NEEDS CLARIFICATION]`. Angle
   brackets in command syntax such as `notes add <text>` are not placeholders.
3. **Underspecification.** A requirement with a verb and no measurable outcome, a story with no
   acceptance criterion, a task naming a file or component the spec and plan never define.
4. **Constitution.** Any requirement, plan decision or task that conflicts with a `MUST`, or a principle
   the plan's gate marked `pass` that the tasks then break.
5. **Coverage.** Every `FR-###` and `US#/AC#` maps to at least one task. Every task maps to a requirement
   or story, or is setup, foundation or polish. Success criteria needing build work have tasks.
6. **Inconsistency.** The same thing named two ways (check the brief's glossary), an entity in the plan
   absent from the spec, a task ordered before the task it depends on, two requirements that contradict.

## Severity

| Level | When |
| --- | --- |
| CRITICAL | breaks a constitution `MUST`, a core file is missing, or a P1 requirement has no task |
| HIGH | a duplicate or conflicting requirement, an untestable acceptance criterion, a security or data ambiguity |
| MEDIUM | terminology drift, a non-functional requirement with no task, an underspecified edge case |
| LOW | wording, a minor redundancy |

## The report

```text
| ID | Pass | Severity | Where | Finding | Fix |
| A1 | coverage | CRITICAL | spec.md FR-004 | no task implements export limits | add a task to US2 |
```

At most 50 rows, highest severity first; summarize the rest by pass. Then the counts: requirements,
tasks, coverage percentage, findings by severity. End with one verdict: **ready to build**, **fix first**
(any CRITICAL), or **ready with known gaps** (named).

## Gotchas

- **Report what is there.** A missing section is reported as missing. Never inferred, never invented.
- **The constitution is not negotiable here.** A conflict with a `MUST` is fixed in the spec, plan or
  tasks, or the constitution is amended on purpose. `analyze` never softens the principle.
- **Twelve LOW findings bury one CRITICAL.** Lead with severity; collapse the low ones to a count.
- **Same input, same findings.** Re-running on unchanged files with different results means the passes
  were applied loosely. Apply each pass to every requirement, in order.

## After the report

Offer the concrete edits for the top findings and apply only the ones the user approves. After an
approved edit to `spec.md` or `plan.md`, re-run `breakdown`'s coverage check so the tasks still match.
A fix that changes behavior the user already had is a product decision: ask before applying it.

Then run `mastermind next` and end with the step it names, so the user sees where the feature stands.
