---
title: Init — twenty seconds of setup, then out of your way
blurb: Sets MasterMind up for one project by reading your stack instead of interrogating you, and asks at most a single question.
---

## The problem this solves

Every tool that wants to be useful has a setup problem. To help well it needs to know things about your
project — but the moment it starts asking, it becomes the obstacle it was meant to remove.

The usual result is a wizard: eight questions, half of them technical, most with answers already sitting
in your project files. People abandon setup, or click through it randomly, and the tool ends up
configured wrong anyway.

**Init is deliberately the opposite: detect everything readable, ask at most one thing, then start
working.**

It runs **once per project**. Once MasterMind knows your stack, it never does this again.

## What goes wrong without it

- **Generic advice.** Without knowing your framework, versions, and conventions, an AI defaults to the
  most common answer on the internet — which is often two versions out of date and shaped for a
  different project than yours.
- **The wrong conventions imposed.** It writes code in its preferred style rather than the style already
  in your repo, and every review turns into re-explaining your own house rules.
- **Being asked things it could have read.** "What test runner do you use?" is a question with an answer
  sitting in a config file. Asking it wastes your time and signals the tool isn't paying attention.
- **A polished front end on an unguarded back end.** Half-configured setups tend to load knowledge for
  the visible layer only, leaving auth, data, and permissions on guesswork.

## How it actually works

There are two paths, and MasterMind picks based on whether your folder has code in it.

**If the project already exists,** it asks you nothing. It reads your package files, lockfiles, configs,
folder shape, database, and test setup, then loads the matching body of domain knowledge. If the closest
match is imperfect — say the stored knowledge assumes React and you're on Svelte — it prunes what doesn't
apply and fills the gaps rather than forcing a bad fit. If there's no knowledge for your field at all, it
offers a one-time deeper setup and tells you plainly what it costs: a few minutes now, reused forever
after.

**If the folder is empty,** there's nothing to read, so it asks one open question: *what do you want to
build?* You answer in your own words. Technical or not — both are fine. If you name a framework, it uses
it. If you only describe the product, it chooses the stack itself, states the choice with a one-line
reason, and proceeds. You are never handed a menu of technical options to pick from.

**It never blocks your first result.** If you're eager to start, MasterMind begins the actual work and
runs any slower setup in the background. Setup is not allowed to become the thing you're doing.

Both paths end with a short summary — detected stack, what loaded, next step — and then it goes straight
into your real task without waiting.

## When it fires

> *"set MasterMind up for this project"*
> *"init"*
> *"I want to build a booking site — start from scratch"*
> *"get me ready"*

Or simply on your first real task in a project it hasn't seen. You'll see it in your terminal:

```
🧠 MasterMind ▸ init · detect stack → load field pack → ready
```

## When it does *not* fire

- **You want to know what MasterMind can do.** That's `help` — a menu of every skill and when each one
  fires. The difference is direction: `help` explains MasterMind *to you*; `init` explains *your project*
  to MasterMind. If you're not sure where to start, ask for help first.
- **The project is already set up.** It checks, and skips itself rather than redoing work.
- **You want your repo scaffolded.** Init configures knowledge, not your codebase. It won't create files
  or edit your project on its own — that's `build`, and it happens as part of an actual task.

## What you get

A MasterMind that knows your framework and versions, matches your existing conventions instead of
overwriting them, and loaded the right knowledge for both halves of a full-stack app.

At the very end it makes one small, entirely skippable offer: two optional preferences — a written report
at the end of each work cycle, and a plan-first mode that shows you the plan before editing anything.
Both are **off unless you turn them on**, and ignoring the question leaves them off.
