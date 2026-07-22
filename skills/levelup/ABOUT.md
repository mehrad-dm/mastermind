---
title: Level Up — how MasterMind actually gets better over time
blurb: Turns corrections, review findings, and ecosystem changes into durable rules, so the same mistake doesn't need correcting twice.
---

## The problem this solves

A language model's abilities are fixed at the moment it is trained. It cannot learn from you the way a
colleague does. Correct it today, and tomorrow's session starts with the same blind spot, because the
correction lived in a conversation that no longer exists.

The only thing that persists is what gets written down. MasterMind's knowledge base — its principles,
its defaults for your stack, its accumulated lessons — is a set of plain text files that load at the
start of work. Changing those files is the only real way to change future behavior.

**Level Up is the disciplined way of editing them.** It is how a correction becomes permanent instead of
evaporating.

## What goes wrong without it

- **Correcting the same thing repeatedly.** You explain your preference, it is followed for an hour, and
  the next session has never heard of it. Frustrating, and it slowly erodes trust in the whole setup.
- **Advice that has quietly expired.** Frameworks and best practices move. A default that was right two
  years ago is now the thing everyone warns against, and nothing flags it.
- **A knowledge base that grows into noise.** The opposite failure, and the more common one. Every
  lesson gets saved, nothing is ever removed, and eventually the guidance is so long that it is skimmed
  rather than read. A bloated brain is functionally the same as no brain.

## How it actually works

Three modes, depending on what triggered it.

**Capture** is the everyday one. It looks back over recent work for lessons that will apply *again* —
a correction you made, a real problem a review caught, a decision that proved right. Project-specific
trivia is discarded; only the generalizable part is kept, written as one line with its reason, and
checked against what is already recorded so nothing is stored twice. If the lesson is a genuine default
rather than an edge case, it gets promoted into the standing rules, where it changes behavior rather
than sitting in a list.

**Refresh** checks the knowledge base against the live world — whether the recommended tools and sources
are still the best ones, whether anything has been abandoned, and what has changed in how AI tools
themselves should be used. It extracts the durable principle, never the vendor-specific mechanism,
because the same knowledge base has to work in every AI tool, not just one.

**Bootstrap** creates a whole new body of knowledge when you move into unfamiliar territory — a new
language, a new kind of project. It reads your actual project to learn your real stack, rather than
producing generic advice about a field.

Running through all three is one constraint: **every line costs something on every future session.** So
the test for each addition is whether removing it would change behavior. If not, it gets cut. When
something new goes in, something stale is hunted down and retired. The knowledge base is meant to get
sharper, not longer.

## When it fires

You don't type a command. Say something like:

> *"remember that — we always do it this way"*
> *"stop making that mistake"*
> *"is this still the recommended approach in 2026?"*
> *"I'm starting a Rust project, you don't know this stack"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ folding that lesson in so it sticks
   └ levelup · capture · scan corrections → dedupe → promote defaults
```

## When it does *not* fire

- **Needing to understand a technology for the task in front of you** — that's `learn`, and the
  difference matters. `learn` is just-in-time: it reads the real documentation for one library because
  this specific task depends on it, uses that understanding, and lets it go. Nothing durable is written.
  `levelup` is the opposite: it edits the permanent knowledge base because the lesson will matter again
  in six months. Confusing them means either polluting long-term memory with one-off detail, or losing
  something that should have been kept.
- **Preserving the state of unfinished work** — that's `handoff`, which captures *this task's* context
  so the next session can resume it. `levelup` captures *transferable* lessons that outlive the task.
- **A one-off preference for a single project** — that belongs in the project's own instructions, not in
  knowledge that applies everywhere.

## What you get

A small, honest set of rules that reflects what you have actually corrected and what the field actually
recommends now — with a version number and a dated log entry, so improvement is visible rather than
claimed. Because it is plain text under version control, every change can be inspected and undone.
