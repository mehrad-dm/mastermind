---
title: Analyze: catch the gaps while they cost a sentence
blurb: A read-only check that a feature's spec, plan and task list agree with each other and with the project's rules, before any code exists.
since: 0.33.0
---

## The problem this solves

A spec, a plan and a task list are written at different moments, sometimes by different sessions.
They drift. A requirement in the spec never makes it into a task. The plan calls something an "account"
that the spec calls a "workspace". A task depends on another that comes after it. Each gap is one
sentence to fix on paper, and a rewrite once it is code.

## How it actually works

MasterMind reads the four documents, spec, plan, tasks and constitution, and runs six passes:

1. **Duplication**: two requirements saying the same thing differently.
2. **Ambiguity**: words like "fast" or "secure" with no number, and leftover placeholders or open questions.
3. **Underspecification**: requirements with no measurable outcome, stories with no acceptance criteria.
4. **Constitution**: anything that conflicts with one of the project's `MUST` rules.
5. **Coverage**: every requirement has a task, and every task serves a requirement.
6. **Inconsistency**: the same thing named two ways, steps in the wrong order, contradictions.

Each finding has a severity, a location and a suggested fix, and the report ends with coverage numbers
and a plain verdict: ready to build, fix first, or ready with named gaps.

Two rules make it trustworthy. It **never edits anything**: it reports, then offers fixes you approve.
And it runs in a **fresh context** that did not write the documents, because whoever wrote them
already believes they agree.

## When it fires

> *"Is this feature ready to build?"*
> *"Check the spec and plan agree before we start."*
> *"Find the gaps in these docs."*

```
🧠 MasterMind ▸ checking the feature docs agree, before any code
   └ analyze · fresh context · six passes · read-only
```

It is also run before building anything from a task list that touches money, authentication or data.

## When it does *not* fire

- **After the code exists.** Comparing finished code against the documents is `converge`.
- **Analyzing code, a bug or performance.** Those are `code-reviewer`, `debug` and `performance`.

## What you get

A short, ranked list of the places your documents disagree, with the fix for each, before anyone has
spent a day building the wrong thing.
