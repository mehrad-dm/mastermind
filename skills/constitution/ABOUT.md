---
title: Constitution: the rules every feature is checked against
blurb: A short, versioned list of what this project refuses to break, written so a reviewer can check every change against it.
---

## The problem this solves

Every project has rules nobody wrote down. "We never store raw card numbers." "The SDK never adds a
dependency." "Every screen works without a mouse." They live in one person's head, and an AI that
cannot see them will break them politely, confidently and often.

Writing them in a README does not fix it either. A README rule has no version, no owner and no moment
when anyone checks a change against it, so it decays into a suggestion.

## How it actually works

MasterMind writes `specs/constitution.md`: three to seven principles, each made of a few `MUST` or
`MUST NOT` statements and one line saying what breaking it would cost. It reads the repository first,
so rules your CI and linters already enforce are recorded rather than asked about, and it only asks
you about the things code cannot reveal, such as your privacy stance or what the product will never do.

The file has a version number. Adding a principle is a minor version; removing or redefining one is a
major version, because old work may now break it. Every amendment is recorded at the top with the
date, who decided it and why, and MasterMind lists every spec and document the change now conflicts
with, so nothing silently disagrees with the new rule.

Then the rules get used. Planning a feature runs a constitution check before the design and again
after it. The consistency check before coding flags any requirement that conflicts with a principle.
The final comparison of code against intent treats a broken `MUST` as the most severe finding there is.

## When it fires

> *"These are our non-negotiables, write them down."*
> *"From now on, every feature must work offline."*
> *"We just decided the dashboard is dark only. Update the rules."*

```
🧠 MasterMind ▸ writing down the rules this project won't break
   └ constitution · read repo → draft → confirm → version
```

It also starts when you begin spec-first work on a project that has no constitution yet.

## When it does *not* fire

- **One feature's requirements.** "Users can export to CSV" is a spec, handled by `specify`.
- **MasterMind's own engineering habits.** Verifying before done and refusing lazy placeholders apply
  everywhere already; the constitution holds only what is true of this project.

## What you get

A short file a reviewer can check a change against, a version history that shows when each rule
changed and why, and a list of the documents each amendment affected.
