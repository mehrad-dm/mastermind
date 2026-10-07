---
name: converge
description: Use after building a feature from a task list, to find out whether the code actually does what its spec, plan and constitution say: "is this feature really done?", "check the code against the spec", "what's still missing?", "did we build everything we planned?", every box in tasks.md ticked, or before calling a spec-driven feature done. Not before code exists (that's `analyze`), not for a single claim (that's `double-check`), not for running the thing end to end (that's `qa`).
---

# MasterMind: Converge

The task list says what was meant. The code says what happened. This closes the gap: it reads the
feature's documents as the **only** source of intent, checks the code against every item, and appends
what is missing as new tasks for `build`. Layout and IDs: `~/.mastermind/engineering/core/spec-driven.md`.
Feature: **$ARGUMENTS**.

## The one write the assessment may make

The assessment appends a `## Phase N: Convergence` section to `tasks.md`. Nothing else. It never edits
`spec.md`, `plan.md`, an existing task, a previous convergence phase, or any code. When nothing is
missing, `tasks.md` stays byte for byte unchanged and no empty heading is added. Closing a converged
feature, below, is a separate step taken after the verdict.

## Who runs it

The session that built the feature already believes it is finished. Dispatch a fresh-context subagent
with the feature folder, the constitution and repository access, and nothing about how the build went.
Where no isolated context exists, run it yourself and label the result self-graded.

## Method

1. **Require the documents.** `spec.md`, `plan.md` and `tasks.md` must exist. If one is missing, stop
   and name the skill that produces it. Missing code is not a stop: see the last gotcha.
2. **List the intent.** One line per `FR-###`, `US#/AC#`, success criterion needing build work, plan
   decision that names a file or behavior, constitution `MUST`, and existing task.
3. **Bound the search** to the paths `plan.md` and `tasks.md` name, plus a search for each requirement's
   key terms. Do not wander past what the documents define.
4. **Check every item against the code**, every task included, ticked or not. **A ticked box is a
   claim, not evidence.** Evidence is a file and line, a command's output, or a passing check from `quickstart.md`.
5. **Run it, not only read it.** Run every step in `quickstart.md`, then the unhappy paths the spec's
   edge cases name. Contradictions between two documents surface here, where reading misses them.
6. **Classify each gap:**

| Gap | Means |
| --- | --- |
| `missing` | nothing in the code does it |
| `partial` | something does it, not fully: a case, a state or a rule is absent |
| `contradicts` | the code does something the intent or a constitution `MUST` forbids |
| `unrequested` | the code does something no document asked for (a task to justify or remove it, never a deletion) |

7. **Grade each gap.** CRITICAL: breaks a constitution `MUST`, or blocks a P1 story. HIGH: a core
   requirement `missing` or `partial`. MEDIUM: a secondary one, or `unrequested` with no clear reason.
   LOW: polish.
8. **Show the findings before writing**: `| ID | Gap | Severity | Traces to | Evidence | Remaining work |`,
   then counts of what was checked.
9. **Append the tasks**, CRITICAL first, continuing the highest task ID:

```text
## Phase 6: Convergence

- [ ] T043 Reject exports over the workspace limit in src/export/limits.ts per FR-004 (missing)
- [ ] T044 Keep amounts immutable after settlement in src/ledger/settle.ts per C-III (contradicts)
```

## Closing a converged feature

Say **Converged** with the counts of what was checked. Then run the closing steps from `spec-driven.md`:
set the spec's status to `converged` with the date, promote what outlives the feature into the living
docs and `.mastermind/MAP.md`, and treat the folder as frozen history from here.

## The loop

`build` the appended tasks, then converge again. Three rounds without converging means the documents
and the code disagree about something real. Stop and ask the user which one is wrong.

## Gotchas

- **The pull to declare it done is strongest when every box is ticked.** That is exactly the case this
  exists for. Check the code behind each box.
- **A finding without evidence is a guess.** Every row names the file and line, or the command and its
  output.
- **Never fix the code here.** Even a one-line gap becomes a task. Mixing assessment and repair is how a
  check ends up grading its own fix.
- **Little or no code yet is not an error.** Every item is `missing`; append them all.
