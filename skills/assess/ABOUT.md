---
title: Assess: should this be built at all?
blurb: Evidence before investment. An idea ends in go, clarify or stop, with the reasons written down.
since: 0.33.0
---

## The problem this solves

An AI will build anything you describe, which makes the most expensive question in product work
disappear: should this exist at all? Ideas go straight from a sentence to a codebase, and the cost of a
bad one is only discovered after it ships and nobody uses it.

## How it actually works

MasterMind takes the idea through five stages, refining a single file, `specs/ideas/<name>.md`:

1. **Intake**: the idea in one sentence, who asked, who it serves, and the problem it removes.
2. **Research**: what people do today instead, competitors, and any earlier attempt. Every finding is
   cited and labelled observed, reported or assumed, so a guess never passes as a fact.
3. **Define**: what would show it worked, as one to three measurable signals with targets and dates,
   plus the constraints it must live within.
4. **Shape**: the smallest version that would test the outcome, and the two or three assumptions it
   rests on, each with the cheapest test that could prove it wrong.
5. **Decide**: **go**, **clarify** or **stop**, with reasons and the evidence that would change the verdict.

Before deciding, the shaped idea goes to a reviewer in a fresh context that has not seen MasterMind's
reasoning, with instructions to attack the assumptions. The recommendation is MasterMind's; the decision
is yours, and the file records who made it.

It needs no code, so it works for a business idea as well as a feature request. A **go** hands the shaped
version straight to `specify`.

## When it fires

> *"Is this worth building?"*
> *"Should we add a marketplace to the app?"*
> *"Help me decide whether to invest in offline mode."*

```
🧠 MasterMind ▸ checking whether this idea earns a build
   └ assess · intake → research → define → shape → decide
```

## When it does *not* fire

- **Something already decided.** Pinning down what to build is `interview`; writing it up is `specify`.
- **Choosing a library or tool.** Adopt-versus-build on a dependency is the `tech-scout` agent's job.

## What you get

One file with a clear verdict, the evidence behind it, the riskiest assumption and how to test it
cheaply. A well-reasoned **stop** is a result too: it is the cheapest outcome an idea can have.
