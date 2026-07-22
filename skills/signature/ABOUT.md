---
title: Signature — turning your team's tacit style into rules
blurb: What MasterMind does when code needs to match your team's real conventions — the style you keep correcting the AI toward but have never written down.
---

## The problem this solves

Code has a voice. Two developers can solve the same problem correctly and produce work that reads
completely differently — how things are named, how much gets abstracted, where errors are handled, how
much a comment explains. Teams develop this collectively, and almost nobody writes it down. People can't
list their own conventions, but they spot a violation instantly.

Which means you end up correcting your AI toward a style you've never articulated, over and over, and the
correction never sticks. Same note, new session, forever.

**Signature makes your team's voice explicit** — so a correction you give once becomes a rule, not a
repeated fix. (Want code written in a *named public engineer's* style instead? That's `persona`.)

## What goes wrong without it

- **The same correction, endlessly.** You explain your convention, it's followed for one file, and the
  next session starts from scratch.
- **House style treated as a bug.** The AI "fixes" something that wasn't broken — it was just how your
  team does things — and produces a diff full of unwanted changes.
- **One loud voice becoming law.** A single strong opinion from one review gets encoded as a team rule
  nobody else agreed with.
- **Style rules that quietly break things.** A preference dressed up as a correctness requirement, applied
  where it causes real problems.

## How it actually works

It draws on two sources. The strongest signal is repeated corrections: what people tell the AI over and
over, recurring review comments, changes humans made after the AI proposed something else. These are
explicit and already human-validated. Weaker signal comes from patterns in the codebase itself — treated
as candidates, since code being present doesn't mean anyone endorses it.

Frequency is what separates a rule from noise. Something seen twenty times is a convention; something seen
once is an incident.

Candidates then pass three gates. First, each is classified as *convention* or *correctness* — and a
correctness claim needs a citation and a concrete failure it causes, or it gets demoted to preference.
Second, it must recur across more than one source before it graduates, which is what stops a single
opinion becoming policy. Third, everything is stripped of identifying detail: no project, product, person,
or package names. If a rule can't be expressed without an internal name, **it stays in the private Lab and
goes no further.**

Two things worth being precise about. Capture runs in that Lab — a private, git-ignored area — and asks
permission before scanning a real codebase. **Identities never leave it.** And the final rules are
*proposed*, shown to you as a diff. Nothing is applied, committed, or pushed on its own.

The rule that never bends is *patterns, not people*. Rules describe what code does, never rate a
contributor.

## When it fires

You don't type a command. Say something like this:

> *"make this match the rest of our codebase"*
> *"you keep writing it wrong — this is the third time I've corrected this"*
> *"turn the notes we keep repeating into actual rules"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ learning your house style so I stop guessing
   └ signature · capture corrections → classify → sanitize → propose
```

## When it does *not* fire

- **Finding real defects** — that's `code-reviewer`. Signature captures taste; the reviewer finds bugs.
  Keeping them separate is what stops a style preference being reported as a defect.
- **Updating MasterMind's permanent knowledge directly** — that's `levelup`. Signature *feeds* it, handing
  over proposed rules; levelup is where accepted rules land.
- **Writing in a named engineer's style** — that's `persona`. A public figure's documented style is a lens
  on taste; a named private colleague is only ever profiled here, Lab-gated and stripped of names.

## What you get

Corrections that stop repeating, expressed as durable rules you approved rather than notes you re-give —
your team's voice, made explicit and kept honest.
