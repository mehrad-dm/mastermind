---
title: Route — deciding what to read before starting to work
blurb: How MasterMind picks the handful of files a task actually needs, and why knowing when to skip that step matters just as much.
---

## The problem this solves

An AI working in your codebase has a limited amount of attention. Everything it reads competes for the
same space — your code, its own knowledge, the conversation so far. Fill that space with things the task
didn't need, and the parts that mattered get crowded out.

So the first decision on any substantial task isn't *how do I do this*. It's *what do I need to know
first*. Get that wrong in one direction and the model starts work half-blind, guessing at conventions it
never read. Get it wrong in the other and it arrives at the actual problem with its attention already
spent on files that turned out to be irrelevant.

**Route is the step that makes that choice deliberately instead of by accident.**

## What goes wrong without it

- **Starting in the wrong place.** Work begins in the first file that looked relevant, and the real
  change turns out to live somewhere else entirely — after an hour of reading.
- **Reading everything, just in case.** The opposite failure, and the more common one. Context fills
  with material that never gets used, and quality drops on the part that counts.
- **Missing the project's own rules.** The one convention file that would have shaped the whole change
  goes unread, so the work has to be redone in the project's actual style.
- **Over-planning a small job.** A two-file change gets a full analysis of the architecture. This is
  waste that *feels* like diligence, which makes it hard to notice.

## How it actually works

Route is short by design — it runs before the work, and its output is a list, not a plan.

**Name the destination.** One line stating what this task actually produces. Scope comes before routing;
you can't choose what to load until you know what you're aiming at.

**Refuse to over-plan.** This step is genuinely part of the method, not a disclaimer. If the task is a
one-line change, or a typo, or already covered by what's on screen, route says *no map needed* and
exits. A skill that knows when not to run is more useful than one that always runs.

**Detect the field.** Work out what kind of project this is from its configuration and file types.
Usually fast and usually decisive, and it determines which body of domain knowledge applies.

**Build the load manifest.** Match the task against the available knowledge and pick: which domain
reference files to open, which skill fits the work, which of the core discipline documents this task
genuinely needs, and which areas of your codebase to read first. Everything on the list has a cost, and
anything that can't justify it gets cut.

**Load progressively.** For a large or foggy task, only the entrance set gets loaded up front. The next
files are named after the first decisions resolve, rather than guessed at the start.

Two rules keep it honest. The manifest **points at files, it never summarizes them** — the moment it
starts paraphrasing what a document says, it can drift out of date and quietly lie. And **nothing is
loaded "just in case."** Every entry earns its place.

## When it fires

You don't type a command. Say any of these and MasterMind reaches for `route`:

> *"I need to change how permissions work — not sure where that lives"*
> *"can you look at this repo and add rate limiting"*
> *"something in the payment flow needs updating, it touches a few places"*
> *"where would I even start with this?"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ route · destination → field → load manifest
```

## When it does *not* fire

- **A one-line change or an already-scoped task.** If it's clear what to do and where, routing adds a
  step and removes nothing. It skips itself.
- **When the problem is that nobody agrees what to build** — that's `spec`. Worth separating carefully:
  route answers *what should I read*, spec answers *what are we building*. Route assumes the goal is
  understood and finds the path to it. If the goal itself is fuzzy — "make it better", arguments about
  scope — routing will produce a confident list of files for the wrong task. Spec first, then route.
- **Actually doing the work** — that's `build`, which can call route as its opening move. Route chooses
  what knowledge to bring; it never writes code or plans the implementation.
- **It isn't a task tracker.** Route serves one session's context. Tickets, backlogs, and multi-day
  project state are somewhere else entirely.

## What you get

A short list of exactly what's being opened and why, before any work starts — so the model spends its
attention on your problem rather than on a tour of the codebase, and so you can see it heading somewhere
sensible before it gets there.
