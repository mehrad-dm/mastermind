---
title: Lab — a private room for data that must never be published
blurb: Sets up a local, never-committed workspace for confidential material, plus automatic guards that block it from reaching a shared repository.
---

## The problem this solves

Useful work often requires handling material you are not allowed to publish: a client's internal code,
real customer names, a proprietary system's inner workings, private business context. You need it
present while you work. You need it absent from anything that leaves your machine.

The usual approach is care — remember not to commit that file, remember to strip that name. Care works
until the day it doesn't, and the failure is permanent. Once confidential material is pushed to a shared
repository, it is in the history, on other people's machines, and possibly on a public site. You cannot
take it back by deleting it.

**Lab replaces care with structure.** It builds a room that data cannot accidentally walk out of.

## What goes wrong without it

- **A commit that includes the wrong file.** The most common leak in the world is not a hack. It is
  somebody staging everything at once and not reading the list.
- **A real name inside a "generic" note.** You write up a lesson learned, and the client's name is in
  the example. The note gets shared. The name goes with it.
- **A leak that gets discovered later.** Nothing breaks at the moment it happens, so nobody catches it.
  It surfaces during an audit, or when the client reads their own name in a public repository.

For a freelancer or consultant, that is not a technical incident. It is a contract problem, a trust
problem, and potentially a legal one.

## How it actually works

Two pieces: a quarantined space, and guards that watch the exits.

**The space.** A `lab` folder inside the project holds the raw material — captured code, working notes,
anything with real names in it. That folder is added to the project's ignore list, meaning your version
control system treats it as invisible and will never include it in a save.

**The list.** Inside the Lab you keep a private list of your sensitive terms: the company name, product
names, colleagues' names, internal domains. That list itself is never published either.

**The guards.** Two automatic checks are installed. The first runs every time you save work, and refuses
to proceed if it sees a Lab file or any term from your list. The second runs when you send work to a
shared server, and scans everything being sent — including older saves, and including cases where the
first check was skipped. Two layers, because one can be bypassed.

**The proof.** MasterMind deliberately tries to commit something forbidden and confirms it is blocked. A
guard nobody has tested is not a guard; it is a belief.

Underneath all of it sits one rule: **patterns leave the Lab, identities never do.** You are welcome to
extract a general lesson from confidential work — "systems of this shape tend to fail this way" — as
long as every name has been removed. The insight travels. The identity stays behind.

## When it fires

You don't type a command. Say something like:

> *"this is client code, don't commit any of it"*
> *"I need to analyze this repo but it's confidential"*
> *"make sure none of this ends up on GitHub"*
> *"set up the lab for this project"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ lab · quarantine → ignore → install guards → prove they block
```

## When it does *not* fire

- **Storing passwords and API keys** — those belong in a secrets manager or environment configuration,
  not in a folder. Lab is for confidential *material and context*, not credentials.
- **Turning Lab material into reusable knowledge** — that's `levelup`, and it is a separate, deliberate
  step. Lab only builds the container and locks the door; deciding what has been genericized enough to
  leave is its own decision, made explicitly.
- **A general security review of your code** — that's a review task. Lab protects against *you*
  publishing something by accident, not against an attacker.

## What you get

A working space where confidential material can sit safely, and two automatic checks that stop it
leaving — verified by watching them block a real attempt. There is a deliberate override for the case
where you genuinely mean to publish something, because a guard with no escape hatch gets disabled.

It is not a complete guarantee. It catches the terms you listed and obvious secrets, not everything a
careful human reviewer would. Read your changes before publishing to anywhere public. But it converts
the most likely failure — routine, unthinking, one-command-away — into something you have to do on
purpose.
