---
name: roadmap
description: Use when work spans weeks and the reasoning behind it is piling up — returning to a project after time away, "why did we decide X?", "where did we land on this?", "what's still open?", onboarding someone onto a long-running build, or a choice everyone remembers making and nobody can find. Not one session's state (that's `handoff`), not scoping one feature (that's `interview`).
---

# MasterMind — Map

Long work loses its reasoning long before it loses its code. Six sessions in, the *why* behind a choice
is gone, and the seventh session relitigates it — or silently undoes it. This is the one artifact that
outlives the sessions: a decision map the project owns and appends to for the life of the work.

## The file — five sections

**`.mastermind/MAP.md`**, one per project. Nothing that isn't one of these five belongs in it.

1. **Destination** — what done looks like, in two or three lines. What every decision is measured against.
2. **Decisions so far** — dated, one line each, **each with its why**. Append-only.
3. **Open questions** — what you can state precisely and cannot answer yet.
4. **Not yet specified** — known unknowns, deliberately unplanned.
5. **Out of scope** — and what it would take to change that.

A decision entry, and the reversal of one, look like this:

```text
2026-03-04 · Sessions live in Postgres, not Redis — one datastore to operate, and
             nothing needed sub-millisecond reads. → specs/auth.md
2026-05-19 · REVERSES 2026-03-04 — sessions move to Redis. The read path became the
             p99 at 340ms once org switching landed. The original reason still held;
             the traffic changed. → PR #412
```

**Only section 2 is append-only.** The other four describe the present and get rewritten freely — a
resolved question leaves "Open questions" the moment it becomes a decision.

## Fog of war — don't chart what you can't see

The test for "Open questions" is whether you can state the **question** precisely *today* — not whether
you can answer it. *"Which queue runs the nightly export?"* is an open question. *"How does billing
work?"* isn't a question yet; it's a region of fog.

Write the fog as one line naming the unknown and what will lift it: *"Billing model — unspecified until
the pilot returns pricing feedback."* That line is the whole entry. A map carrying a plausible plan for
month three reads as decided, and the next session builds against something nobody ever chose.

## Decisions are append-only

**Never edit or delete a decision entry.** A reversal is a *new* dated entry naming the one it reverses
and what changed. The excuse to catch in yourself: *"the old line is wrong now, so leaving it is
misleading."* It was true when it was written, and **when it stopped being true is the information** —
the map exists to answer "why is it like this?" nine months later, and an edited history cannot.

## An index, not a store

Each entry is **one line plus a pointer** — to the spec, the PR, the file, the issue. Detail stays where
it already lives and stays current there. A map that reproduces content becomes a second source of
truth, and the copy is the one that goes stale (`~/.mastermind/engineering/core/rigor.md` refuse-list).

## One open question per session

**Resolve one open question per session.** A session that closes five has been guessing at four. A
question leaves "Open" only when something *outside the map* settled it — a measurement, a call from the
user, code that now exists — and the entry that replaces it says which.

## When it gets written

An entry is earned at the same moment the journal line is: the verdict closing a non-trivial task
(`~/.mastermind/engineering/core/rigor.md`). The journal records *what happened*; the map carries only
the decisions still shaping the work. Promote from the journal — never copy it across.

## Map vs. handoff vs. spec

Three horizons, and the boundary is what each one outlives.

- **`interview`** — one ask, decided before it's built. Retired when that thing ships.
- **`handoff`** — one session's live state, so a reset doesn't cost the thread. Thrown away on resume.
- **`roadmap`** — the project's decision history, kept for the project's life. It **points at** specs and
  handoffs; it never absorbs them.

## Gotchas

- **Open it before planning, not after.** Coming back cold, the reflex is to re-derive the state from
  the code — which reads the *what* and misses every *why*, and reopens settled ground.
- **Out-of-scope work never quietly graduates back in.** Scope discipline is `rigor.md`; the part that's
  the map's job is that moving an item out of "Out of scope" is itself a dated decision entry — who
  asked, and why now.
- **Write it for someone who wasn't there.** A line that only makes sense to whoever was in the session
  fails at the two moments the map is for: the return after weeks away, and the new person.
