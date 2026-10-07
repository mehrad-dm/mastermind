---
title: Living docs: product, business and tech, always current
blurb: Three short documents that describe the project as it is today, kept true as features ship.
---

## The problem this solves

Ask an AI to build a feature and it can read every line of code. It still cannot tell you who the
product is for, how it makes money, or why the payment service sits behind a queue. That knowledge
lives in people's heads, in a deck from last year, in a wiki nobody updates. So the AI builds something
technically right and commercially wrong.

Documentation projects usually fail the same way: written once, never touched, and six months later
every page is a little bit false. A false document is worse than none, because people believe it.

## How it actually works

MasterMind keeps three documents in `specs/`:

- **product.md**: who it is for, the problem, what it does, what it will never do, the key journeys.
- **business.md**: the model and pricing, the market, legal and budget constraints, the metrics that matter.
- **tech.md**: the stack and why, the architecture, where data lives, integrations and how they fail,
  environments, and the conventions a newcomer would get wrong.

It reads before it asks. Everything technical comes from the code and configuration. You are asked only
what code cannot reveal, one question at a time, each with a recommended answer. Anything MasterMind
inferred but nobody confirmed is marked `(unconfirmed)`, so a guess never reads as a fact.

Keeping them true is the real work. When a feature is finished and its code has been checked against
its spec, what that feature taught gets promoted into these documents. When the code contradicts
`tech.md`, the code wins and the document is corrected in the same change. When something contradicts
the product or business document, MasterMind asks you which one is wrong. Each file carries the date and
commit it was last verified against.

## When it fires

> *"Write down what this product actually is."*
> *"I just joined, how is this thing built?"*
> *"Our docs are out of date."*
> *"Where's the source of truth for pricing?"*

```
🧠 MasterMind ▸ writing down how this project works, today
   └ living-docs · read repo → ask the gaps → mark the unconfirmed
```

## When it does *not* fire

- **Usage docs for one internal package.** That's `explain`.
- **Why a decision was made.** The decision history lives in the project's map, kept by `roadmap`.
  Living docs describe the present and are rewritten in place.

## What you get

Up to three short documents a new teammate, or a new AI session, can read in minutes and trust. Each
fact appears once, and each document shows when it was last checked against the code.
