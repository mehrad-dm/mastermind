---
title: Specify: what to build and why, written before how
blurb: A feature specification in plain language, with traceable requirements, so every later step can be checked against it.
---

## The problem this solves

Hand an AI a feature request and it starts deciding things immediately: the database, the component
library, the folder layout. By the time anyone reads the result, the question of *what the feature
should do* has been answered by accident, inside the code.

The fix is ordering. Agree on what and why first, in words a non-engineer can review, and only then
decide how.

## How it actually works

MasterMind opens a numbered folder for the feature, such as `specs/012-csv-export/`, and writes `spec.md`:

- **User stories in priority order.** The first one alone is a usable product. Each has an
  *independent test*: how someone would see it working with nothing else built. This is what makes each
  story a slice you can ship, rather than a layer you have to wait on.
- **Acceptance criteria with the trigger inside**, such as *"if the token expires, then re-authentication
  happens silently once."* A vague promise like "handles errors gracefully" has no trigger, so nobody can
  tell whether it happened.
- **Requirements and success criteria with IDs** (`FR-003`, `SC-001`, `US1/AC2`). Every later task and
  every later finding points back to one of these, so "this is incomplete" becomes "requirement FR-003
  is missing."
- **Edge cases, what is out of scope, and the assumptions it made.**

No technology appears in the spec. "Cache it in Redis" is replaced by the need it serves.

Gaps are handled on purpose. MasterMind fills most of them with a sensible default and lists it under
Assumptions, so you can see and overturn it. Only a gap that would change the product is marked as a
question, and there are never more than three. Those go to `interview`, which asks them one at a time
with a recommended answer.

Before handing the spec on, MasterMind checks it against a short quality list: no technology named,
every requirement testable, every success criterion measurable, every story independently testable,
words matching the project's glossary.

## When it fires

> *"Write the spec for team invitations."*
> *"Start a new feature: recurring invoices."*
> *"Turn this idea into requirements before we build it."*

```
🧠 MasterMind ▸ writing down what we're building, before how
   └ specify · stories → requirements → success criteria → quality check
```

It also fires for any feature large enough to span sessions or people, or that touches money,
authentication, data migration or a public contract.

## When it does *not* fire

- **A small, clear change.** That goes straight to `build`.
- **A fuzzy ask nobody has pinned down yet.** Questioning comes first, in `interview`; the spec is
  written once there is something to write.

## What you get

A spec a product owner can review in ten minutes and an engineer can build from, with every requirement
traceable through the plan, the tasks and the final check of the code.
