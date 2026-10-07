---
title: Converge: is it really done?
blurb: Checking the finished code against everything the feature promised, and turning every gap into a task instead of a surprise.
since: 0.33.0
---

## The problem this solves

Every box on the task list is ticked. The feature is "done". Then someone tries the edge case the spec
described, and nothing handles it. The task said it was built; the code says otherwise.

A ticked box records that someone believed a thing was finished. It is not proof. And the session that
built the feature is the worst judge of it, because writing the code is believing the code is right.

## How it actually works

When a feature has been built from its task list, MasterMind hands the feature folder, the project's
rules and the repository to a reviewer in a **fresh context** that knows nothing about how the build
went. That reviewer treats the documents as the only statement of intent and checks the code against
every item in them: each requirement, each acceptance criterion, each plan decision, each constitution
rule, and each task, **ticked or not**.

Every gap is classified:

- **missing**: nothing in the code does it.
- **partial**: something does it, but a case, state or rule is absent.
- **contradicts**: the code does something the documents or a rule forbid.
- **unrequested**: the code does something nobody asked for.

Each one gets a severity, the requirement it traces to, and the evidence: a file and line, or a command
and its output. A finding without evidence is not reported.

Then comes the important restriction: converge **only appends**. It adds the gaps as new tasks at the end
of the task list and touches nothing else, no spec, no plan, no code. If nothing is missing, the file is
left exactly as it was. `build` works through the new tasks, converge runs again, and after three rounds
without agreement it stops and asks you whether the code or the documents are wrong.

When it reports **converged**, the feature is closed properly: its spec is marked converged with the date,
anything that outlives it moves into the project's living documents and decision map, and the folder
becomes frozen history.

## When it fires

> *"Is this feature really done?"*
> *"Check the code against the spec."*
> *"What's still missing from the export feature?"*

```
🧠 MasterMind ▸ checking the code against everything we promised
   └ converge · fresh context · every task re-checked · append-only
```

It also runs before MasterMind calls a spec-driven feature done.

## When it does *not* fire

- **Before code exists.** Checking the documents against each other is `analyze`.
- **One specific claim**, such as "the rounding bug is fixed". That is `double-check`.
- **Running the feature end to end.** That is `qa`. Converge reads code against intent; `qa` drives the
  real thing.

## What you get

A plain answer to "is it done?", backed by evidence for every gap, and the remaining work already
written as tasks.
