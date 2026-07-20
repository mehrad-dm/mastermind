---
title: Signature — deciding whose voice the code speaks in
blurb: What MasterMind does when code needs to match your team's real conventions, or read in the documented style of an engineer you admire.
---

## The problem this solves

Code has a voice. Two developers can solve the same problem correctly and produce work that reads
completely differently — how things are named, how much gets abstracted, where errors are handled, how
much a comment explains. Teams develop this collectively, and almost nobody writes it down. People can't
list their own conventions, but they spot a violation instantly.

Which means you end up correcting your AI toward a style you've never articulated, over and over, and the
correction never sticks. Same note, new session, forever.

**Signature makes the voice explicit — either your team's, or a named engineer's documented public one.**

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

There are two modes, and MasterMind picks based on what you asked for.

**Mode A — your team's style.** It draws on two sources. The strongest signal is repeated corrections:
what people tell the AI over and over, recurring review comments, changes humans made after the AI
proposed something else. These are explicit and already human-validated. Weaker signal comes from patterns
in the codebase itself — treated as candidates, since code being present doesn't mean anyone endorses it.

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

**Mode B — a named engineer's public style.** You name someone whose work you admire, and MasterMind
writes through the lens of their **documented public** style — grounded in their open-source work, talks,
and published positions. Every trait has to be traceable to something they actually wrote; if it can't be,
it's dropped rather than plausibly invented. It applies to any code, not just yours.

## When it fires

You don't type a command. Say something like this:

> *"make this match the rest of our codebase"*
> *"you keep writing it wrong — this is the third time I've corrected this"*
> *"write this the way Rich Hickey would"*
> *"turn the notes we keep repeating into actual rules"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ signature · capture corrections → classify → sanitize → propose
```

## When it does *not* fire

- **Finding real defects** — that's `code-reviewer`. Signature captures taste; the reviewer finds bugs.
  Keeping them separate is what stops a style preference being reported as a defect.
- **Updating MasterMind's permanent knowledge directly** — that's `levelup`. Signature *feeds* it, handing
  over proposed rules; levelup is where accepted rules land.
- **Confusing the two modes.** A public figure's documented style is fair game. A named private colleague
  is never profiled in Mode B — that goes through Mode A, Lab-gated and stripped of names.
- **Impersonation, in any form.** Mode B produces work "in the documented style of" someone, stated as
  such. Never a claim that they wrote it, endorsed it, or were involved. No invented quotes, no invented
  opinions, no signing their name to anything. And style never overrides correctness — if the persona and
  a real defect conflict, the defect wins and MasterMind says why.

## What you get

Corrections that stop repeating, expressed as durable rules you approved rather than notes you re-give.
Or, in the other mode, code written through a named engineer's real published habits — with the traits
leaned on stated plainly, so you can judge the lens rather than take it on trust.
