---
title: Explain — making an internal package understandable on the first read
blurb: Writes usage documentation for your own shared code, so the next person (or the next AI) gets it right without reading the source.
---

## The problem this solves

Every team accumulates shared code — a components library, a utilities package, a services layer that
talks to the API. The people who wrote it understand it. Nobody else does, because it usually ships with
no instructions.

So everyone downstream does the same thing: opens the source, skims until something looks familiar,
guesses the intended usage, and gets the non-obvious parts wrong. That includes your AI. A model reading
your package cold has exactly the same problem a new teammate has, and it makes the same wrong guesses —
just faster and more confidently.

**Explain is the discipline that writes the missing instructions.**

## What goes wrong without it

- **The same questions, forever.** Whoever wrote the package becomes a permanent help desk, answering
  "how do I use this" one Slack message at a time.
- **Quiet misuse.** People use the thing in a way that works today and breaks later — passing the wrong
  option, calling things in the wrong order, relying on a default that was never meant to be relied on.
  Nothing errors, so nobody notices.
- **Knowledge that lives in one head — or one model.** If your understanding of the package exists only
  in a chat history, it evaporates when the session ends or when you switch to a different AI tool.
  Documentation in the repository survives all of that.

## How it actually works

MasterMind asks first, because this writes real files into your project. It offers to document the
package, then shows you **one sample** before doing the rest — so you can say "not like that" while it
still costs nothing.

Then, for each public piece of the package:

**1. Find what's actually public.** It reads the package's real entry point rather than assuming, so the
list of things to document matches what people can actually use.

**2. Read the source, never guess.** The implementation, the types, the options, the tests, and one real
example of the thing being used elsewhere in your codebase. Anything it can't confirm gets marked
unverified or left out. A confidently wrong document is worse than no document.

**3. Write a short doc next to the thing it describes.** What it's for, the full list of options with
their types and defaults, the minimal correct example, how it combines with its siblings, and the
scenarios people genuinely need.

**4. Spend the most care on the gotchas.** This is the part that matters. An options table can be
inferred from the code by anyone. The rules the code *doesn't* enforce — the ordering constraint, the
option that silently hides another, the default nobody expects — cannot. That section is the whole point.

Docs live beside the code they describe, so they travel with it and are found by anyone already looking
in the right place.

## When it fires

You don't type a command. Say something like:

> *"nobody knows how to use our components package"*
> *"document this library for the team"*
> *"we're handing this module to another team next week"*
> *"the AI keeps using our API wrapper wrong"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ explain · discover units → read source → sample doc → fan out
```

## When it does *not* fire

- **Writing up work that was just finished** — that's `report`. The distinction is direction in time.
  `report` narrates what happened in a session: what changed, why, what was verified. `explain` writes
  reference material for people who weren't there and will arrive months later. One is a record, the
  other is a manual.
- **Explaining code you're about to change** — reading and understanding a codebase is ordinary work,
  not this skill. `explain` produces durable files for future readers.
- **Documenting a public, external library** — that already has docs. This is for your internal code,
  the code nobody outside your team will ever write documentation for.

## What you get

A short, accurate document beside each public piece of your package, written from the code rather than
from memory. The measurable outcome: the next person to use it — human or model — gets it right on the
first attempt instead of the third.
