---
title: Learn — knowing the tool before using it on your project
blurb: What MasterMind does when a task depends on technology it doesn't actually know, instead of writing confident code from memory.
---

## The problem this solves

An AI model was trained at a point in time. Libraries move on. A function that took two arguments now
takes an options object; a pattern that was recommended two years ago is now the thing the docs warn
against. But the model doesn't feel the gap — it writes the old version with exactly the same confidence
it writes the current one.

This produces a particular kind of frustration: code that looks completely reasonable, uses real-sounding
function names, and fails on contact with your actual installed version.

**Learn is the habit of checking the ground before standing on it.**

## What goes wrong without it

- **Confident, outdated code.** Written against the version the model remembers rather than the one in
  your project. The names are close enough to look right and wrong enough to break.
- **Invented details.** When a specific fact is missing, the gap gets filled with something plausible.
  A parameter that doesn't exist. A method with the right name and the wrong behavior.
- **Unchecked assumptions doing heavy lifting.** "I think this handles large files" is fine as a thought
  and expensive as a foundation. The costly bugs come from beliefs nobody ever tested.
- **Ignoring how your codebase already does it.** A technically correct solution written in a style
  nothing else in the project uses.

## How it actually works

**1. Find out what's actually installed.** Read the project's dependency files, configuration, and a
representative sample of source. Not "React" — the specific version, alongside the styling approach,
state handling, and test setup this project genuinely uses.

**2. Map the territory, then narrow it.** Identify what a competent practitioner would need to know here,
then learn only the branch this task touches. Learning the whole ecosystem is procrastination.

**3. Read the primary sources.** Official documentation for the exact features involved, checked against
the installed version, plus one well-built real example. Documentation over recollection, every time.

**4. Ground it in your code.** Search for how this pattern already appears in your project and match it.
Consistency with the surrounding code beats a cleverer approach in isolation.

**5. Grill the assumptions before writing anything.** This is the step that earns the rest. Every belief
about how the API behaves gets listed explicitly, then verified against the source. Each one comes back
confirmed, corrected, or still unknown. Anything unresolved is either flagged as a stated risk or settled
with a tiny experiment — never quietly guessed at. Where something genuinely can't be verified, you get a
best guess *with a confidence level attached*, so you can correct it rather than having to author it.

## When it fires

You don't type a command. It engages when a task leans on unfamiliar ground:

> *"add Stripe subscriptions to this app"*
> *"we just upgraded to the new version — does our code still work"*
> *"I've never used this library, can you wire it up"*
> *"help me understand how this codebase handles authentication"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ reading the real docs before I touch this
   └ learn · detect stack → read primary docs → grill assumptions
```

## When it does *not* fire

- **Improving MasterMind's permanent knowledge** — that's `levelup`, and the difference is what happens
  afterwards. `learn` is temporary and task-shaped: it gathers exactly what today's job needs and then
  lets it go. `levelup` writes durable lessons into MasterMind's long-term knowledge so they apply to
  every future project. Learn is reading for one job; levelup is remembering forever. They chain naturally
  — if something learned turns out to be broadly reusable, learn hands it to levelup.
- **Testing a risky unknown by building something** — that's `spike`. Learn answers questions the docs can
  answer. Spike answers questions only running code can.
- **Familiar territory.** If the stack is well-known and current, this step is skipped. It's a response to
  genuine uncertainty, not a ritual.

## What you get

A short working brief rather than a tutorial: the stack and versions in play, the specific pieces this
task needs, the traps worth knowing, and a ledger of every assumption checked with its source. The wide
reading happens off to the side so it doesn't crowd out the actual work.
