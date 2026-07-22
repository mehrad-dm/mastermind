---
title: Report — a receipt for the work, only if you asked for one
blurb: Turns a finished cycle into a short shareable record of what changed, what was decided, and how it was verified — off by default and never produced unprompted.
---

## The problem this solves

Work gets done, the conversation scrolls away, and a week later nobody can reconstruct what happened or
why. The diff survives, but a diff shows what changed and never why. The reasoning — the trade-off that
was weighed, the approach that was rejected, the thing that was actually tested — lives only in a chat
window you've since closed.

**Report makes that durable: one short file someone can read instead of re-reading the code.**

It's the same substance as the verdict you saw in chat, written down where it can be shared, attached to
a ticket, or read by whoever picks the work up next.

## The most important thing about it: it is off

This is opt-in, and **off by default**. MasterMind will not produce a report unless you ask for one, or
unless you have explicitly turned automatic reports on for that project.

You're offered the choice exactly once — a single skippable question during first-time setup — and if you
ignore it, decline it, or say nothing, the answer is off. The setting is stored per project, so turning
it on for one repo doesn't turn it on everywhere. You can change it at any time by saying so in plain
words, and change it back just as easily.

The same restraint applies to the other optional preference offered at setup, plan-first mode, where
MasterMind shows you its plan and waits for your approval before editing anything. Also off unless you
turn it on. Neither of these is ever switched on quietly.

## What goes wrong without it

- **Decisions evaporate.** Six weeks later someone asks "why is it done this way?" and the honest answer
  is that nobody remembers.
- **Reviewers reverse-engineer intent from a diff.** Slow, and frequently wrong.
- **Verification claims go unchecked.** "It works" is worth very little. What was actually run, and what
  was actually observed, is worth a lot.
- **Or the opposite problem: reports nobody reads.** A tool that writes a document after every trivial
  change trains you to ignore all of them. That's precisely why this one stays quiet unless asked.

## How it actually works

A report is deliberately short and carries five things:

**The verdict, up front** — ship, needs work, or redirect, with one line of reasoning. If you read
nothing else, you know where things stand.

**What changed** — the files touched, one line each, grouped so the shape of the change is visible at a
glance.

**The key decisions** — only the non-obvious calls, each with its one-line reason. Not a list of things
any competent reader already knows.

**How it was verified** — what was genuinely run and observed end to end. Never "looks correct."

**Follow-ups and risks** — what's left, the edge cases, the known rough spots.

Markdown by default: cheap, opens anywhere, diffs cleanly in version control. A self-contained HTML
version is available on request, styled and readable in any browser at somewhat higher cost. Either way
it's a plain file saved in your project, not something locked inside one particular tool.

## When it fires

> *"write up what you just did"*
> *"give me a report on this"*
> *"summarize the changes for my team"*
> *"turn reports on for this project"*

You'll see it in your terminal:

```
🧠 MasterMind ▸ writing up what changed and what was checked
   └ report · verdict → changes → decisions → verification
```

## When it does *not* fire

- **For a one-line change.** Effort matches stakes. A typo fix does not get a document.
- **Documenting how to *use* your code** — that's `explain`, which writes usage docs beside an internal
  package so people stop calling it wrong. `explain` describes a thing that exists; `report` describes
  work that happened.
- **Handing off unfinished work** — that's `handoff`, and the difference is tense. A report closes a
  finished cycle for someone looking back. A handoff carries live context forward so an interrupted job
  can be resumed, by a teammate or your next session. Pausing mid-task? You want handoff.
- **Any time you haven't asked and haven't turned it on.** Which is the default.

## What you get

A short, honest file someone can read in a minute — including the parts that didn't go well. Reports that
only record wins stop being useful the first time someone checks one against reality.
