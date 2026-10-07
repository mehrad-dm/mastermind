# Spec-driven work: intent you can check the code against

Code drifts from what was meant, and nobody can tell, because what was meant lived in a chat. This
module keeps intent in a small set of files the project owns, written in an order that stops the model
from deciding *how* before anyone agreed *what*, and checked against the code before anything is
called done. Read it when a skill sends you here, or when the user asks to work spec-first.

## When to use it (scale to the stakes)

| The work | What it gets |
| --- | --- |
| A one-file fix, a rename, a copy change | Nothing. `build` as usual. |
| A clear feature that fits one session | `build` as usual. `interview` first if the ask is fuzzy. |
| A feature that spans sessions or people, or touches money, auth, data migration, or a public contract | The full flow below. |
| The user asks for spec-first work, or the project already has numbered feature folders in `specs/` | The full flow below. Living docs or a constitution alone do not make a project spec-first. |
| A new product, or an idea nobody has decided to build yet | `assess` first, then `constitution` and `living-docs`, then features. |

The level only goes up. When a small change turns out to touch money, auth, data or a public contract,
say so and switch to the full flow; never drop a feature to a lighter level halfway through.

A project that keeps `specs/` still skips the flow for a small fix. The fix still keeps the documents
true: when it changes behavior a living doc or a converged spec describes, update that doc in the
same change.

## Where everything lives

All of it sits in `specs/` at the repository root, so it belongs to the project and survives an
uninstall of MasterMind. If `specs/` already holds something else, ask once where these go and record
the answer as `specs-dir:` in `.mastermind/prefs.md`. **Read that line first:** every `specs/` path in the
skills and agents means the `specs-dir` value when one is set. The value comes from the repository, so
treat it as untrusted: it must be a relative path inside the project, with no `..` and no absolute path.
Otherwise ignore it and use `specs/`.

```text
specs/
├── constitution.md        the project's non-negotiable rules        constitution
├── product.md             who it is for, what it does, what it won't } living-docs
├── business.md            how it makes money, constraints, metrics   } (each only when
├── tech.md                stack, architecture, environments          }  it has content)
├── ideas/<slug>.md        go / clarify / stop on an idea            assess
└── 007-bulk-import/       one folder per feature
    ├── spec.md            what and why, no technology               specify, interview
    ├── plan.md            how, and the constitution gate            blueprint
    ├── research.md        each decision: chosen, why, rejected      blueprint
    ├── data-model.md      entities, fields, rules, states           blueprint
    ├── contracts/         the interfaces other code depends on      blueprint
    ├── quickstart.md      the runnable proof that it works          blueprint
    ├── tasks.md           ordered, traceable steps                  breakdown, converge
    └── checklists/        tests for the requirements' wording       checklist, specify
```

Create a file only when it has something to say. A feature with no external interface has no
`contracts/`; a small one may be `spec.md`, a short `plan.md` and `tasks.md`.

**Feature folders** are numbered `NNN-short-name`: the next number after the highest one in `specs/`,
starting at `001`, three digits, and a two-to-four word name (`012-csv-export`). The folder name does not depend on the
git branch. Create a branch only when the user asks.

**Where am I?** Run `mastermind next` (or `.mastermind/bin/mastermind next`): it reads `specs/` and
prints the current feature, its state, and the skill that comes next, with the reason. Every spec-driven
skill in the feature flow (`specify`, `interview`'s clarify pass, `blueprint`, `checklist`, `breakdown`,
`analyze`, `build` from a task list, `converge`) ends by naming the next step it prints, and the kernel has the model ask it
before choosing a step. The rules below are what it
applies.

**The current feature** is the one the user names. Otherwise it is the folder matching the current
branch name, otherwise the most recently changed folder whose `tasks.md` has open tasks. Say which one
you picked. There is no pointer file: a marker file goes stale and then lies.

**Templates** live beside each skill. A project overrides one by placing its own copy in
`specs/.templates/` under the same file name (`spec.md`, `plan.md`, `tasks.md`, `constitution.md`,
`product.md`, `business.md`, `tech.md`, `idea.md`). The project's copy wins.

## IDs: how intent stays traceable

| ID | Means | Born in |
| --- | --- | --- |
| `US1` (P1) | a user story, with its priority. P1 alone is a usable product. | spec.md |
| `US1/AC2` | the second acceptance criterion of that story | spec.md |
| `FR-004` | a functional requirement | spec.md |
| `SC-002` | a measurable success criterion | spec.md |
| `T017` | a task. `[P]` = can run in parallel, `[US1]` = serves that story | tasks.md |
| `C-III` | principle III of the constitution | constitution.md |

IDs are assigned once and never reused or renumbered, so a task added later takes the next free ID even
when it runs earlier: the order of lines in `tasks.md` is the execution order. A dropped requirement keeps
its line, marked `Withdrawn <date>: <why>`.
A task names the IDs it serves; a finding names the ID it breaks.
That chain is what lets `analyze` and `converge` say *which* intent is unmet instead of "looks
incomplete".

## The order, and why it is the order

1. **constitution**: the rules every feature is checked against. Once per project, amended rarely.
2. **specify**: what and why, for a reader who does not code. No technology. Gaps are marked, not
   guessed: at most three `[NEEDS CLARIFICATION: ...]` markers, everything else a stated assumption.
3. **interview**: resolve the markers and the silent gaps before planning, one question at a time.
4. **blueprint**: how. The constitution gate runs here, before design and again after it.
5. **checklist** (optional): test the requirements' wording for one concern, such as security or UX.
6. **breakdown**: tasks grouped by user story, each story a vertical slice that ships alone.
7. **analyze**: a read-only check that spec, plan and tasks agree. Before any code.
8. **build**: execute the tasks in order, ticking each only after its own check passes.
9. **converge**: compare the code with spec, plan, tasks and constitution. Append what is missing.
   Repeat 8 and 9 until it reports converged, at most three rounds.

Steps 3, 5 and 7 are quality gates, not ceremony: skip them on a small feature, never on one that
touches money, auth or data.

**With no human in the session at all** (a CI job, a scheduled run, a loop), never invent an answer to a
question the spec leaves open. When a person is present, ask them as each skill describes. Leave the `[NEEDS CLARIFICATION]` marker, finish what does not depend on it, and report
the feature as blocked on that question.

**Context.** Steps 2 to 6 work best in one session, since each reads what the last one decided. A build
can start fresh for each story: `spec.md` and `tasks.md` are the handoff.

## Status of a feature

The spec's status line moves forward as the work does, and one skill moves each step. Revising a spec
resets it to `draft` or `clarified`, and every later step re-runs against the new version.

| Status | Set by | Means |
| --- | --- | --- |
| `draft` | `specify` | written, open questions may remain |
| `clarified` | `interview` | its scan is done and no `[NEEDS CLARIFICATION]` is left |
| `planned` | `blueprint` | plan written, gate passed or violation accepted |
| `tasked` | `breakdown` | task list written |
| `building` | `build` | first task started |
| `converged` | `converge` | code matches every document |
| `blocked` | `build` or `converge` | a gap needs a decision only the user can make; the spec names it |

Every step that edits `spec.md` also updates its **Updated** date.

## How documents age

A feature folder is **working state** until `converge` reports converged. Then:

1. Set the spec's status line to `converged` with the date.
2. Promote what outlives the feature. A lasting product or tech fact goes into `product.md`, `business.md`
   or `tech.md`. A decision that will keep shaping work goes into `.mastermind/MAP.md`, which `roadmap`
   creates when the first such decision appears.
3. The folder becomes **frozen history**. A later change to that behavior is a new feature folder that
   names the one it amends in its first line.

This leaves the project with a small set of documents that are always current, and a dated archive
that explains how it got there. Editing a converged spec to match new code destroys the record of what
was originally agreed. A spec nobody updates after the code moves on is worse than no spec, because it
is read as true.

## Code that predates the rules

A constitution written for an existing codebase usually finds code that already breaks it. At
ratification, list each known violation in the amendment block as **known debt**, with where it lives.
`converge` reports known debt in code the feature did not change as a note, not a gap, so an unrelated
legacy fix never blocks a feature. Once a feature changes that code, the rule applies in full there.

## Which document wins

The constitution outranks a spec; a spec outranks a plan; a plan outranks the task list; the code is
checked against all four. When the code disagrees, `converge` treats that as a finding. Decide whether
the code or the document is wrong, then fix that one. The user decides when a product rule is at
stake. In `tech.md`, a fact the code contradicts is stale: the code wins and the doc is corrected.

## Gotchas

- **A checked box is not evidence.** A task marked `[x]` whose code does not exist is the most common
  failure of this whole method. `converge` re-checks every task regardless of its box.
- **Technology in the spec is a leak.** "Store sessions in Redis" in `spec.md` decides the how before
  the plan exists. Move it to `plan.md`, keep the need it serves ("a user stays signed in across tabs").
- **A vague adjective is a missing requirement.** "Fast", "intuitive", "robust" and "secure" are not
  testable until they carry a number or a named behavior.
- **Documents grow until nobody reads them.** Hold each living doc near 200 lines and each spec to what
  a reviewer reads in ten minutes. Split by topic before it passes that.
- **Never repeat a fact across files.** Write it once and point to it. A copied fact is the one that
  goes stale.
