---
title: Code reviewer — the second pair of eyes that never saw your reasoning
blurb: What MasterMind does before a change is called done, and why the reviewer is deliberately kept ignorant of the conversation that produced the code.
---

## The problem this solves

Whoever wrote the code is the worst person to review it. Not because they're careless — because they
already believe it works. They know what they meant, so they read what they meant. The gap between
intention and text is exactly where bugs live, and it's invisible from the inside.

This is a hard problem for AI in particular. Ask the same assistant that just wrote something whether it's
good, and it will tell you yes, in detail, persuasively. It isn't lying. It's reading its own reasoning
back to itself.

**Code reviewer solves this by not being in the room when the code was written.**

## What goes wrong without it

- **Self-approval.** Nothing is genuinely checked; the reasoning is just repeated with more confidence.
- **The unhappy path goes untested.** The code handles the case the author pictured. Empty lists, failed
  requests, two clicks at once, a hostile input — nobody looked, because nobody pictured them.
- **Style gets flagged as a defect.** An undisciplined reviewer produces forty comments, most of them "I'd
  have written it differently." A padded review teaches everyone to skim it, so the real finding buried at
  number thirty-one gets skimmed too.
- **Plausible bugs that aren't real.** A reviewer that reports anything it can imagine going wrong burns
  your time chasing ghosts.

## How it actually works

Code reviewer is an **agent**, not a skill. A skill is guidance the main conversation follows; an agent
runs in its own **isolated context window**. It receives the change and nothing else — not the discussion
that produced it, not the explanation of why that approach was chosen, not any earlier "this looks good."
It sees the code the way a stranger on your team would: as text that either works or doesn't. That
isolation is the entire mechanism. A reviewer that inherited the author's reasoning would inherit the
author's blind spots and rubber-stamp its own work.

Two disciplines shape what comes back.

**Every finding must be reproduced before it is reported.** A suspicion isn't a finding. Before a bug
reaches you, the reviewer has to demonstrate the failure — trace the specific inputs through to the wrong
result, or run the check that fails. Anything it can't show failing gets dropped, or downgraded to a
one-line question. This is what keeps the output short and worth reading.

**Convention is separated from correctness.** For anything it wants to flag, the test is: can it cite a
source saying this is wrong, and name a concrete failure it causes? If yes, it's a real defect. If no,
it's a style choice — and the rule is to match the surrounding code, never to report it as a problem.

It works through correctness first, then security, then honest types, architecture, clean code, stack fit,
and consistency — hunting for the bug the author hoped wouldn't happen.

**It proposes fixes and never applies them.** It has no ability to edit your files, deliberately. It shows
you the problem and the change it would make; the decision to make that change stays with you.

## When it fires

> *"I just finished this feature — is it any good?"*
> *"check this before I commit it"*
> *"can you look over what you just wrote?"*
> *"audit the login code, I'm nervous about it"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ code-reviewer · read diff → reproduce each finding → rank, propose, never apply
```

## When it does *not* fire

- **When you want proof the feature works** — that's `qa`. The difference is direction. QA *runs* the
  thing: drives it end to end, checks the behavior against what was asked for. Code reviewer *reads* the
  thing: judges the text against correctness, security and design. Code can review clean and still be
  wrong about what you wanted; it can pass QA and still be a security hole. Serious changes want both.
- **A one-line change.** A renamed variable doesn't need a formal review.
- **When something is already broken and you don't know why** — that's `debug`. Review finds unknown
  problems in working code; debug chases a known symptom to its cause.

## What you get

A ranked list, most severe first, split into must-fix (correctness and security), should-fix (design
issues with a real cost), and nits. Each one names the file and line, states the defect in a sentence,
shows the failure it causes, and proposes the fix. If the code is genuinely clean, it says so plainly
rather than inventing something to justify the exercise.
