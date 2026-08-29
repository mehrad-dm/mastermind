---
name: handoff
description: Use when work needs to survive losing context, before a /clear on a long task, when pausing something unfinished, when handing over to a teammate or the next session, when the context window is filling up on multi-day work, or when a long multi-step task starts re-covering ground it already finished. Not the project's decision history across weeks: that's `roadmap`.
---

# MasterMind: Handoff

Context is the fundamental constraint (`~/.mastermind/engineering/core/agent-loop.md`); a long task shouldn't lose its thread to a
reset. Capture just enough to resume cold: high signal, low tokens.

## Capture

1. **Goal**: the outcome being built, in one line.
2. **State**: Done / In-progress / Next, as a short checklist. Be honest about what's *not* verified.
3. **Key decisions & why**: the non-obvious choices and their rationale (so they aren't relitigated).
4. **Map**: where the relevant code/files/config live; the entry points.
5. **Gotchas**: traps, failing things, env quirks, anything that bit you.
6. **How to resume & verify**: the exact command(s)/check to pick up and confirm green.

## Rules
Summarize and link, point to detail rather than pasting it. Write it where the next session
will look (`.mastermind/HANDOFF.md`, a scratch file, or the issue). Prune it when the work completes.

## Output
A tight `.mastermind/HANDOFF.md`: goal, state checklist, decisions, file map, gotchas, resume+verify steps.

## The ledger: for work that outlives one context window

A handoff is written once, at the pause. A **ledger** runs the whole way through: an append-only record
of what has actually been completed, so a long task can lose its thread without losing its place. Start
one when the work will be summarized more than once.

- **First line names the work**: the plan, spec, or issue it belongs to. A ledger nobody can match to
  a plan is a page of orphaned sentences.
- **Append one line as each step completes**: what was done, and the check that proved it. **Earlier
  entries are never rewritten or tidied:** it is a record of what happened, not a plan of what will.
- **Conversation memory does not survive compaction: trust the ledger and the git log over your own
  recollection**, most of all when you feel certain. Re-doing finished steps is the costliest failure in
  long-horizon work, and it always arrives wearing *"I remember doing that."* Read the record, then act.

Same instinct as the episodic journal appended at each verdict (`~/.mastermind/engineering/core/rigor.md`),
one level down: the journal spans tasks, the ledger spans steps inside one.
