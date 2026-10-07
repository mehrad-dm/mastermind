---
title: Blueprint: the technical plan, checked against the rules first
blurb: How a written spec becomes a plan with every decision explained, checked against the project's constitution before any code exists.
---

## The problem this solves

Most technical decisions in an AI-written codebase are never made on purpose. A library appears because
it was the first one that came to mind; a second state manager appears because nobody checked for the
first. Months later nobody can say why the project is shaped the way it is.

## How it actually works

Once a feature has a spec, MasterMind writes its plan in the same folder:

- **The constitution gate.** Before any design, each of the project's principles is marked pass,
  not applicable, or violated. A violation stops the plan until you accept it, in writing, along with the
  simpler option it beat. The gate runs again on the finished design.
- **Research with reasons.** Every real decision is recorded as what was chosen, why, and what was
  rejected and why. Anything version-sensitive is checked against the primary source rather than memory.
- **Design by the architect.** The design itself comes from MasterMind's `architect` agent, working in
  its own context from the spec, the constitution and the tech document.
- **What the design implies**, written only when it has content: the data model with its validation
  rules, the contracts other code depends on, and a quickstart, the runnable steps that prove the
  feature works end to end.
- **Real paths.** The plan names the actual files and directories in your repository that will change.

The plan stops at shapes and signatures. Writing the code is `build`'s job.

It refuses to plan over open questions. If the spec still has unresolved questions, they are settled
first, or recorded as named risks if you choose to go ahead anyway.

## When it fires

> *"Plan this spec."*
> *"How should we build the invitations feature?"*
> *"The spec changed, update the plan."*

```
🧠 MasterMind ▸ planning how to build it, rules checked first
   └ blueprint · gate → research → architect → contracts → gate
```

## When it does *not* fire

- **A feature with no spec.** That is `specify`, or simply `build` for a small change.
- **A single design question outside any feature.** Ask the `architect` agent directly.

## What you get

A plan where every technical choice has a reason and traces back to a requirement, checked against
your project's rules twice, with a runnable definition of "it works" written before the code.
