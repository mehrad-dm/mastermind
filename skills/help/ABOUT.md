---
title: Help — the map, for a system you're not supposed to memorize
blurb: Shows what MasterMind can do and how to drive it, built around the fact that you talk to it in plain language rather than running commands.
---

## The problem this solves

MasterMind has a lot of parts — workflows for building, debugging, testing, documenting, and more, plus
a few specialist roles that run on their own. That's genuinely useful, and it's also the kind of thing
people quietly stop using because they can't remember what's in there.

The usual fix is documentation you have to go and read. Help is the version that comes to you, in the
place you're already working, when you ask a question as ordinary as "what can you do?"

**Help exists so you never have to memorize anything to get full value from the system.**

## What goes wrong without it

- **You use one tenth of it.** Whatever you happened to discover in week one becomes the whole tool.
  Skills that would have saved you an afternoon sit unused because you didn't know they existed.
- **You assume it's a command-line thing.** People see names like `debug` and `qa` and conclude they need
  to learn syntax. Then they don't learn it, and never start.
- **You can't tell the near-neighbours apart.** Several skills sound similar until someone lays out the
  difference. Without that, you pick wrong, get an unexpected result, and trust the system less.
- **Settings stay invisible.** Preferences that are off by default stay off forever if nobody mentions
  they exist.

## How it actually works

Help prints a menu, sized to what you asked — a quick orientation for a casual question, the full listing
for a real one.

**It leads with the one thing that matters most:** you don't run commands, you just talk. MasterMind
works by recognizing intent. You describe what you want in ordinary language and it reaches for the right
workflow itself, then shows a single line confirming which one it picked. The slash-style names exist
only as an optional shortcut for people who want to force a specific choice. Nobody needs them.

**Then it lays out the workflows in a table**, and each row answers the three questions you actually
have: what does this do, when does it kick in by itself, and what would I type if I wanted it on purpose.
That third column is written as real phrases — the way you'd actually ask — not as syntax.

**It separates workflows from specialist roles.** Some jobs run inline in your conversation. Others —
designing a system, reviewing a diff, restructuring working code, deciding whether to adopt a library —
run as a focused expert with its own clean slate. You rarely have to choose; MasterMind picks and tells
you which it used.

**It closes with setup and preferences** — how to get MasterMind configured for a project it hasn't seen,
and the two optional per-project settings that are off unless you switch them on.

## When it fires

> *"what can you do?"*
> *"help"*
> *"how do I actually use this thing?"*
> *"is there something in here for testing?"*

It also fires when you seem stuck on where to begin. In your terminal:

```
🧠 MasterMind ▸ help · skills · agents · how to drive it
```

## When it does *not* fire

- **You want MasterMind configured for your project.** That's `init` — it reads your stack and loads the
  matching knowledge. The two are easy to confuse because both feel like getting started. The split is
  clean: `help` teaches you the system and changes nothing; `init` learns your project and sets things
  up. New to MasterMind entirely? Read help, then run init.
- **You want a specific thing explained in depth.** Help is a map, not a manual. It tells you `debug`
  exists and when it fires; it doesn't walk you through its six phases. Each skill has its own write-up
  for that.
- **You want documentation for your own code.** That's `explain`, which writes usage docs beside an
  internal package. Help documents MasterMind, not your repo.

## What you get

A scannable picture of everything available, written around when each thing fires rather than what to
type — because in normal use, you don't type anything special. You describe the problem; the right
workflow shows up and says so.
