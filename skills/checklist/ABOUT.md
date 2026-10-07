---
title: Checklist: unit tests for your requirements
blurb: Questions that test whether a spec says enough about one concern, such as security or accessibility, before anyone builds from it.
---

## The problem this solves

Specs fail quietly. Nobody notices that the requirements never said what happens when an upload is
interrupted, who is allowed to delete someone else's data, or how long a session lasts. Those gaps are
discovered by a user, in production, because the code did exactly what the spec said, which was nothing.

## How it actually works

MasterMind writes a checklist for one concern at a time, such as security, accessibility, UX or the API,
into the feature's `checklists/` folder. The difference from an ordinary checklist is what each item
tests: **the wording of the requirements, never the behavior of the code.**

> Not: *"Verify the logo shows on the home page."*
> But: *"Does the spec say what is shown when the logo fails to load?"*

Every item is a question, tagged with what it checks (completeness, clarity, consistency,
measurability, coverage, assumptions or conflicts) and anchored to a requirement ID, or marked as a gap
when the spec says nothing at all. At least four in five items must point at something specific, so the
list is evidence and not opinion.

MasterMind never ticks its own boxes. A tick means a reviewer judged the requirement good enough, so it
is yours to give. Running it again adds new items rather than replacing the old ones.

## When it fires

> *"Make a security checklist for the payments spec."*
> *"Are the accessibility requirements complete?"*
> *"What did this spec forget about the API?"*

```
🧠 MasterMind ▸ testing what the spec says about security
   └ checklist · one concern · questions anchored to requirement IDs
```

## When it does *not* fire

- **Testing the code.** Proving a finished change works is `qa`.
- **Checking documents against each other.** That is `analyze`.

## What you get

A focused list of questions that exposes what your spec forgot, ranked by what would cause the most
rework, while fixing it is still a matter of adding a sentence.
