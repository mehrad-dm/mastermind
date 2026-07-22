---
title: Persona — writing in a named engineer's documented style
blurb: What MasterMind does when you want code written in the public style of an engineer you admire — grounded in their real work, stated as homage, never impersonation.
---

## The problem this solves

Sometimes you don't want your own house style — you want code that reads the way a particular engineer
writes: the primitives Rich Hickey reaches for, the way Kent C. Dodds factors a test, the directness
someone is known for. That taste is real and it's *public* — it lives in their open-source repos, their
talks, and their writing. But an AI asked to "write it like *X*" usually reaches for a stereotype instead
of their actual documented habits.

**Persona writes through a named engineer's real, public style** — grounded in work they actually
published, never a plausible-sounding imitation. (Want your own *team's* conventions instead? That's
`signature`.)

## What goes wrong without it

- **Stereotype, not signature.** "They use lots of patterns" — a caricature, not how they actually decide.
- **Invented opinions.** The AI puts words in a real person's mouth — "they'd do X" — with nothing behind it.
- **Impersonation creep.** Style drifts into a claim that the person wrote or endorsed the code.
- **Taste overriding correctness.** A stylistic tic used to justify skipping a real check.

## How it actually works

You name someone whose work you admire, and MasterMind builds a lens from their **documented public**
style — open-source code, talks, published positions — then writes through it. It names the three-to-six
load-bearing traits it's using and tells you which ones it leaned on, so you can judge the lens rather than
take it on trust.

The discipline is a **citation gate**: every trait it claims carries a resolvable link to a primary source
— their repo, their post, their talk. A trait it can't cite is dropped, not softened. If web tools are
available it actually fetches each link to confirm it; if not, it cites precisely enough for you to check
by hand and marks the set unverified. If it can't find real sources for the person at all, it says so and
falls back rather than inventing a style from their reputation.

Two hard limits. It's **homage, not forgery** — "written in the documented style of *X*," never a claim
that *X* wrote or endorsed it, no invented quotes, no name on the commit. And style is a lens on *taste*
only — it never overrides correctness, security, or accessibility. If the persona and a real defect
conflict, the defect wins and MasterMind says why.

## When it fires

You don't type a command. Say something like this:

> *"write this the way Rich Hickey would"*
> *"make it read like Kent C. Dodds"*
> *"in the documented style of that OSS author"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ writing this in a named engineer's documented style
   └ persona · name the public traits → write through them → cite each
```

## When it does *not* fire

- **Your own team's conventions** — that's `signature`, which learns from your codebase and corrections.
- **A named private colleague's style** — never here. That only ever goes through `signature`, Lab-gated
  and stripped of names. Persona is for public figures with a documented body of work.
- **Anything a citation can't back.** No documented sources, no persona — it falls back and tells you.

## What you get

Code written through a named engineer's real, published habits — with the traits leaned on stated plainly
and each one traceable to something they actually wrote, so it's a lens you can check, not a costume.
