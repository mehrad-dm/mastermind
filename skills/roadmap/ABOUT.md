---
title: Map: the memory a long project keeps of itself
blurb: Keeps a running record of what a months-long project has decided and why, what's still genuinely open, and what was deliberately left off the table.
---

## The problem this solves

Some work doesn't finish in a session, or a week. It runs for two months across forty conversations,
and by the end almost nobody can say why the important parts are the way they are.

The code survives. It's on disk. What evaporates is the reasoning wrapped around it. Why the database
was chosen over the obvious one. Which approach was tried in week two, cost three days, and failed.
Which question is still genuinely unanswered versus which one somebody quietly answered in passing.
That reasoning lived in conversations that have since been cleared, and it was the expensive part.

The damage shows up as a specific, repeatable event: someone: a teammate, a future session, you,
looks at an unusual choice, concludes it looks wrong, and "fixes" it. The fix reintroduces the exact
problem the original choice was avoiding, and the project pays for the same lesson twice.

**Map is the file that stops that.** One document the project owns, appended to as the work goes, built
to answer "why is it like this?" months after the person who knew has stopped remembering.

## What goes wrong without it

- **Decisions get relitigated.** The same trade-off gets argued in week one and again in week six,
  usually landing somewhere different the second time, so the codebase ends up holding both answers.
- **A reversal erases its own history.** Something is changed, the old note is tidied away to keep the
  document consistent, and the record now claims the current state was always the plan. The most
  valuable fact: that the ground moved, and when: is the one thing that got deleted.
- **The plan is fiction past week two.** Asked to lay out a long project, an AI will produce a
  confident, complete-looking roadmap, including the parts it cannot possibly know yet. Invented
  structure reads exactly like decided structure, and the next session builds against it.
- **Out-of-scope work creeps back in.** Something is explicitly parked. Weeks later, someone working
  nearby does it anyway, because nothing recorded that parking it was a choice rather than an oversight.
- **Onboarding costs a week.** The new person can read every file and still not know which parts are
  load-bearing and which are leftovers.

## How it actually works

MasterMind keeps one markdown file in the project with five sections, and each has a strict job.

**Destination** is what done looks like, in two or three lines. It's short on purpose: it's the thing
every later decision gets measured against, so it has to stay readable in ten seconds.

**Decisions so far** is the heart of it: dated one-liners, each with its reason attached, each pointing
at the spec or pull request or file where the detail actually lives. This section is **append-only**.
When a decision is reversed, the old line stays exactly where it is and a new one is added that names
what it reverses and what changed. That rule is the difference between a document that explains the
project and one that merely describes it. An edited history can tell you the current state; only an
intact one can tell you why the state moved, and *why it moved* is what stops the next person undoing it.

**Open questions** holds only things that can be stated precisely right now, even though they can't be
answered yet. "Which queue runs the nightly export?" qualifies. "How does billing work?" doesn't: that
isn't a question yet, it's a region of fog.

**Not yet specified** is where the fog goes, and it's the section that keeps the map honest. It records
known unknowns as a single line naming the unknown and what will eventually lift it. No speculative
plan, no invented milestones. The governing idea is borrowed from a map-maker's discipline: you do not
chart terrain you have not seen. A blank region is information. A plausible guess drawn in the same ink
as surveyed ground is a lie the project will later act on.

**Out of scope** records what was deliberately left out: and things don't quietly graduate back in.
Bringing one back is itself a decision, dated, with who asked and why now.

Two further rules keep it useful. The map is an **index, not a store**: it points at specs, PRs, and
files rather than reproducing them, because a copy is always the version that goes stale. And **one open
question gets resolved per session**: a session that closes five has been guessing at four, and guesses
recorded as decisions are worse than no record at all.

## When it fires

You don't type a command. Say something like:

> *"remind me where we landed on the auth thing"*
> *"I've been off this project for a month: what's the state of it?"*
> *"why did we decide to do it this way?"*
> *"Sara's joining this next week, she needs to get up to speed"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ picking the long thread back up: what we decided, what's still open
   └ roadmap · destination → decisions → open questions → fog
```

## When it does *not* fire

- **Pausing in the middle of one task**: that's `handoff`. The difference is lifespan. A handoff is
  written for one specific reader picking up one specific unfinished thing tomorrow, and it's thrown
  away the moment they do. A map is written for whoever shows up in four months, and it's kept for as
  long as the project exists.
- **Working out what one feature should be**: that's `interview`. A spec decides a single ask in detail
  before anyone builds it, and retires when that thing ships. The map records only the one-line outcome
  and points at the spec for the rest.
- **Anything that finishes in a session or two.** Nothing accumulates, so there's nothing to accumulate
  into. The ceremony would cost more than it returns.

## What you get

A single file that answers "why is it like this?" long after everyone has stopped remembering: with the
reversals still visible, the genuinely open questions separated from the merely unexplored, and the
parked work still visibly parked. It's the difference between a project that compounds what it learns
and one that keeps rediscovering it.
