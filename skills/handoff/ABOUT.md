---
title: Handoff — surviving the moment the memory resets
blurb: Captures just enough of an unfinished task that the next session, or the next person, can pick it up cold without redoing the thinking.
---

## The problem this solves

An AI session has a finite memory. Work long enough on something substantial and it fills up — and when
it is cleared, or the session ends, everything that was not written down is gone. Not degraded. Gone.

What is lost is rarely the code, which is on disk. It is the reasoning around the code: why that
approach was chosen over the obvious one, which two things were already tried and failed, what is
finished versus what merely looks finished, the exact command that proves it still works. That is the
expensive part, and it is the part that lives only in the conversation.

**Handoff writes it down before it disappears.**

## What goes wrong without it

- **Re-deriving decisions that were already made.** The next session sees an unusual choice in the code,
  concludes it looks wrong, and "fixes" it — reintroducing the exact problem the choice was avoiding.
- **Repeating a dead end.** An approach was tried, took two hours, and did not work. Nothing records
  that. The next session tries it again.
- **Mistaking half-done for done.** Something was written but never actually run. Without an honest
  note, it reads as complete, and the gap is discovered much later and much more expensively.
- **The teammate problem.** The same failure applies when you hand work to a person. A shrug and "it's
  mostly there" costs them a day.

## How it actually works

MasterMind writes a short document covering six things, in this order:

**Goal** — the outcome being built, in a single line, so a cold reader knows what they are looking at
before anything else.

**State** — what is done, what is in progress, what comes next, as a short checklist. Deliberately
honest about what has *not* been verified, because that is precisely the item most likely to be
misread as finished.

**Key decisions and why** — the non-obvious choices with their reasons. This is the section that stops
the next session from undoing good work it does not understand.

**Map** — where the relevant files and configuration live, and where to start reading. Orientation, so
the resumer does not spend their first half hour searching.

**Gotchas** — the traps. The environment quirk, the test that fails for an unrelated reason, the thing
that bit you and will bite them.

**How to resume and verify** — the specific commands to pick the work up and confirm it is still in the
state described. Without this, the first act of the next session is guesswork.

The governing rule is to summarize rather than dump. A handoff crammed with pasted code is just the
original problem in a new file — it consumes the very memory it exists to protect. It points at detail
instead of reproducing it. And when the work is finished, the handoff is deleted, because a stale one
describing a state that no longer exists is actively misleading.

## When it fires

You don't type a command. Say something like:

> *"I need to clear the context but I'm halfway through this"*
> *"let's pause here and pick it up tomorrow"*
> *"write this up so someone else can take over"*
> *"you're running low on context — save the important parts"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ handoff · goal → state → decisions → map → gotchas → resume
```

## When it does *not* fire

- **Writing up completed work** — that's `report`, and the difference is whether the work is finished.
  A report is a record for people who want to know what changed and why: it looks backward, it is
  written for an audience, and it is kept. A handoff is an instruction set for whoever continues: it
  looks forward, it is written for one specific reader, it is deliberately honest about what is broken
  and unverified, and it is thrown away on completion. Producing a polished report when someone needs to
  resume tomorrow gives them narrative where they needed a map.
- **Documenting a package for future users** — that's `explain`, which describes code that is finished
  and stable. Handoff describes work that is mid-flight and probably messy.
- **Storing a durable lesson** — that's `levelup`. Handoff is about this task only, and expires with it.
- **A short task that fits comfortably in one session** — nothing is at risk, so the ceremony is skipped.

## What you get

One tight document that lets a cold reader — a future session, a teammate, or you in three weeks — pick
up where you stopped without re-learning it. The honesty about unverified work is the part that pays
for itself most often, because it is the assumption that would otherwise go unchecked.
