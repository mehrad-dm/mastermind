---
title: Double-check — attacking your own answer before you hand it over
blurb: When MasterMind is about to tell you something works, it first tries to prove itself wrong — with a reviewer that never gets told what the answer is supposed to be.
---

## The problem this solves

The riskiest moment in AI-assisted work is not the coding. It's the sentence right after: *"that's
fixed"*, *"this is the right approach"*, *"it handles that case now."*

By then the model has already decided. It wrote the thing, so it believes the thing — that's more or
less what writing it means. Anything it does next to "check" is happening inside the same head that
produced the answer, which is why self-review so reliably comes back clean. It isn't lying to you. It's
grading its intention instead of its work.

**Doubt is the move that gets a second opinion the model can't quietly influence.**

## What goes wrong without it

- **Confidence arrives before evidence.** The claim gets made because it feels settled, not because
  anything tested it. You find out it wasn't settled later, usually at the worst time.
- **The review is briefed into agreeing.** The natural instinct is to hand a reviewer some helpful
  context — *"I've fixed the token refresh, can you check it?"* That single sentence tells the reviewer
  what the right answer is, and reviewers who know the right answer go looking for reasons it's right.
- **Findings dissolve on contact.** A real objection comes back and gets talked out of existence:
  it was intentional, it's out of scope, it's a trade-off. Each excuse is plausible. All of them
  together mean nothing was ever going to be found.
- **Nobody sees the disagreement.** A concern that got quietly waved away never reaches you, so you
  can't overrule it. You inherit a decision you didn't know was made.

## How it actually works

It starts by forcing the belief into the open. MasterMind writes down, in **one sentence**, exactly what
it's about to tell you — *"the retry loop now handles the expired token."* Vague confidence can't be
attacked; a single sentence can.

Then it separates two things that usually travel together: the **artifact** (the code, the design, the
answer) and the **contract** it has to satisfy (what was actually asked for, the rule it must not
break). If the contract can't be written down, the work stops there — with no bar to test against, any
review just measures the work against its own intentions.

Only the artifact and the contract go to the reviewer, which runs fresh, with no memory of the work.
**The conclusion is deliberately withheld.** The reviewer is told to assume the author is overconfident,
and that summarizing or approving is not an acceptable answer: find what's wrong, or say plainly that
you looked hard and found nothing.

What comes back gets sorted, one finding at a time, in a fixed order: the reviewer misunderstood the
requirement — in which case the requirement gets rewritten and the whole cycle runs again, at cost; or
it's real and gets fixed; or it's real and worth accepting, which gets written down with its price; or
it's noise, which gets named as dropped rather than silently vanishing. Verdicts are written flat, in
one line each. Enthusiastic agreement isn't allowed in that line — praising the reviewer is a symptom of
settling an objection socially rather than judging it.

The loop is capped at three rounds, and then everything open is either fixed, parked with a stated
reason, or handed to you.

Underneath sits the check that makes the rest honest, and it's countable rather than a feeling: **across
two or more rounds where the reviewer raised real objections, how many were accepted as things to fix?**
If the answer is zero, MasterMind isn't doubting itself — it's performing doubt. At that point it stops,
hands you the objections unresolved along with its own reasoning, and lets you decide. A reviewer that
keeps finding real problems while the author keeps finding reasons they don't count doesn't prove the
work is clean. It proves the judge is broken, and the judge is the model.

## When it fires

You don't type a command. Say any of these — or put MasterMind in a position where the next sentence out
of it is a promise — and it reaches for `double-check`:

> *"are you sure this actually works?"*
> *"you told me this was fixed last time"*
> *"this goes to production tonight, we can't roll it back"*
> *"the review came back clean, which honestly makes me more nervous"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ trying to break this before I hand it to you
   └ double-check · claim → artifact + contract → adversarial pass → reconcile
```

## When it does *not* fire

- **Routine small changes.** A copy tweak or a one-line fix doesn't get an adversarial round; that's
  ceremony, and ceremony spent everywhere is ceremony that stops meaning anything.
- **Reviewing a finished diff.** That's the `code-reviewer` agent, which reads the change that exists and
  hands back ranked findings for a human to rule on. Doubt works earlier and wider: it interrogates a
  claim while the work is still moving, and that claim is often not code at all — a diagnosis, a design
  call, an answer to a question. Code review asks *"is this change any good?"*; doubt asks *"is what I'm
  about to say true?"*

## What you get

The objection you would have raised, raised earlier and by someone other than the author — and a written
decision on every one of them, so nothing is settled out of your sight. When MasterMind can't break its
own claim, you get a claim that survived a hostile attempt rather than one that was never tested. When
it can't fairly judge the objections either, it says so and hands them to you, which is the honest
outcome and a far cheaper one than finding out in production.
