---
name: specify
description: Use when a feature is going to be built spec-first and needs its specification written or revised: "write the spec for X", "spec this feature", "start a new feature: ...", "turn this idea into requirements", an assessed idea that got a go, or any feature that spans sessions or people, or touches money, auth, data migration or a public contract. Not for a small clear change (that's `build`), and not for questioning a fuzzy ask before anything is written (that's `interview`).
---

# MasterMind: Specify

The spec says **what** and **why**, for a reader who does not code. The how comes later, in
`blueprint`. Read `~/.mastermind/engineering/core/spec-driven.md` for the layout, IDs and lifecycle.
Feature: **$ARGUMENTS**.

## Write it

1. **Open the folder.** Pick the next number in `specs/` and a two-to-four word name: `specs/012-csv-export/`.
   Revising an existing spec? Work in that folder instead.
2. **Start from the template.** `specs/.templates/spec.md` if present, else [`template.md`](template.md).
3. **Read what bounds it.** `specs/constitution.md`, `specs/product.md`, the brief's glossary, and any
   earlier spec this one amends.
4. **Write user stories in priority order.** P1 alone is a usable product. Each story carries an
   *independent test*: how someone would see it working with no lower-priority story built. A story
   may rely on a higher-priority one; its test then assumes only those.
5. **Write acceptance criteria with their trigger inside**, numbered per story (`US1/AC1`), in the four
   shapes `interview` uses: *When*, *While*, *If ... then*, *Where*.
6. **Write functional requirements** (`FR-001`), each testable alone, and **success criteria**
   (`SC-001`), each measurable from the user's side with no technology named.
7. **Fill the rest.** Key entities (no fields or types yet), edge cases, out of scope, and assumptions.
8. **Name things once.** Add each new domain word to the glossary in `.mastermind/brief.md`, creating the
   section if it is missing, and use those exact words in the spec.

## Gaps: guess well, mark the few that matter

Fill a gap with the reasonable default for this kind of product and record it under **Assumptions**.
Mark a gap `[NEEDS CLARIFICATION: <question>]` only when all three hold: it changes scope, security or the
user's experience; two readings lead to different products; and no default is reasonable.

**Three markers at most.** Rank by scope, then security and privacy, then experience, then technical
detail. Past three, the rest become assumptions. Then run `interview` on the spec to resolve them.

## Check it before handing it on

Write `checklists/requirements.md` in the feature folder and test the spec against it:

- [ ] No technology, framework, library or API named anywhere
- [ ] Every requirement is testable and has one reading
- [ ] Every success criterion is measurable and names no technology
- [ ] Every story has an independent test and at least one acceptance criterion
- [ ] Edge cases, out of scope and assumptions are filled
- [ ] Every domain word matches the glossary in `.mastermind/brief.md`
- [ ] No more than three clarification markers remain

Fix what fails and re-check, at most three rounds. Anything still failing is listed in the checklist's
notes and in your report. Set the status line to `draft`, or `clarified` once no marker remains.

## Gotchas

- **Technology is a leak.** "Use Postgres", "a React modal", "cache in Redis" decide the how before the
  plan exists. Replace each with the need it serves. The product's own surface is not technology: the
  commands a CLI user types, or the screens a user sees, belong in the spec.
- **"Fast", "intuitive", "secure" are not requirements.** Each needs a number or a named behavior.
- **A story that cannot ship alone is a layer.** "Set up the database" is a task, never a story.
- **Do not invent the business.** Who pays, legal limits, and pricing come from `product.md`,
  `business.md` or the user. Never from inference.
- **One feature per folder.** A title that joins two outcomes that ship separately is two features.
  Split it now. One capability with two parts, such as tagging notes and filtering by tag, is one.

## Report

The folder, the stories with priorities, the checklist result, any marker still open, and the next step:
`interview` if markers remain, `blueprint` if none do.
