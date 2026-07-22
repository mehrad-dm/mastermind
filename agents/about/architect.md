---
title: Architect — deciding the shape before the first line
blurb: What MasterMind does before it builds anything non-trivial, and why the expensive mistakes are all made in the first ten minutes.
---

## The problem this solves

Most software problems aren't typing problems. They're shape problems — what the pieces are, where the
data lives, who owns what, which thing is allowed to know about which other thing. Get that right and the
code almost writes itself. Get it wrong and you spend the next month working around your own decision.

An AI asked to "build me X" will happily start at line one. It produces something that runs. Then the
second feature arrives, and the shape it picked in the first ten minutes turns out to be the wrong one —
except now there are two thousand lines resting on it.

**Architect is the step that decides the shape first, on purpose, before anything rests on it.**

## What goes wrong without it

- **The first idea wins by default.** Nobody sketched a second approach, so nothing was compared. The
  design isn't the best one; it's the only one that got drawn.
- **The data model is an afterthought.** Storing what should be calculated, calculating what should be
  stored, the same fact living in three places and drifting apart. This is the debt that never stops
  charging interest.
- **Boundaries leak.** Every part reaches into every other part. Nothing can be changed without changing
  five other things, and nobody can hold the whole picture in their head anymore.
- **The awkward cases surface last.** Empty states, failures, two users at once — discovered during
  testing, when accommodating them means unpicking the structure rather than designing for them.

## How it actually works

Architect is an **agent**, not a skill, and the difference matters. A skill is a set of instructions the
main conversation follows. An agent runs in its own **isolated context window** — it is handed the job
and nothing else. It doesn't see the chat that led here, the earlier attempts, or any preference already
voiced. It reads the actual codebase and reasons from that alone. The isolation is the point: a design
produced from the code as it is, not from the momentum of a conversation.

The work runs in five moves. It restates the real problem and how long the result has to live — a
throwaway prototype and a foundation deserve very different effort. It studies the existing code first,
because consistency with what's already there beats cleverness. Then it deliberately **designs it twice**,
sketching two credible approaches, naming the trade-off in each, and choosing the simplest one that fully
works. It specifies the parts: module boundaries and their interfaces, what state exists and who owns it,
how data flows and where it gets checked, and the types that make broken states impossible to express.
Last, it lists the edge cases the builder must handle, and surfaces the one or two genuine *product*
trade-offs only you can settle — every technical call it makes itself.

## When it fires

You don't summon it. Say something like this and MasterMind reaches for it:

> *"I want to add a whole notifications system to this app"*
> *"should this data live on the server or in the browser?"*
> *"I'm about to build the payments flow — how should it be structured?"*
> *"this feature touches about eight files and I don't know where to start"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ designing this before any code gets written
   └ architect · restate → design twice → specify boundaries, data, edges
```

## When it does *not* fire

- **When the question is "what are we even building?"** — that's the `spec` skill. Spec pins down the
  *requirement*: what counts as done, what's in scope, what the words mean. Architect assumes the
  requirement is settled and decides the *technical shape* that satisfies it. Fuzzy ask, use spec; clear
  ask with an unclear structure, use architect.
- **A small, contained change.** Adding a field, fixing a label. Ceremony for a five-minute job is waste.
- **When the real unknown is "will this approach even work?"** — that's a `spike`: build a rough throwaway
  and find out. Architect designs from things you know; a spike goes and learns them.

## What you get

A blueprint, not code: the chosen approach, the boundaries and their interfaces, the data model, the key
types, the edge-case list, and a one-line reason behind every significant decision. It's short and it's
decisive — a design you could hand to a strong engineer who would build it without second-guessing. If a
genuine product trade-off exists, it comes to you as a question rather than a silent assumption.
