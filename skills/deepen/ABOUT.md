---
title: Deepen: finding where the design is actually costing you
blurb: Surveys an area for the structures that make change expensive, ranks them by the cost they will cause, and hands you the choice rather than a rewrite.
---

## The problem this solves

Every codebase reaches a point where adding a small thing takes a long time, and nobody can say
exactly why. The tests pass. Nothing is broken. It is just slow to change.

Asking an AI to "clean this up" at that point is dangerous, because it will. You get a large diff that
touches everything, is technically defensible, and nobody can review.

The missing step is choosing. Somebody has to look at the whole area, work out which two or three
structures are actually causing the pain, and pick one.

## When it fires

When you say the design is hurting but not what to do about it. *"This is getting messy."* *"Where
should we clean up?"* *"Why is it so hard to add anything here?"* *"It takes five files to change one
field."*

## What it does

It narrows first, usually to what has changed most recently, because design debt hurts where the code
moves. Then it looks for structures with a named price: a wrapper that hides nothing, one idea spread
across five files, a boundary that callers can see through, a path no test can reach, a rule enforced
in several places that will eventually disagree with itself.

For anything that looks like a pointless layer it applies the deletion test: if this disappeared and
its callers did the work inline, would the code actually get worse?

Then it shows you at most six candidates, each with the files, a drawing of the shape before and after,
and the cost stated as a thing that will happen rather than a feeling. You pick one.

## What happens next

The one you pick goes to the refactorer, which does the work under a contract: behaviour preserved,
tests green, or the change does not land.

## What it is not

It does not edit anything. Finding and fixing in the same pass is how a survey becomes a diff nobody
can review.

It does not review your latest change: that is `code-reviewer`. It reads code that already shipped.

And it will not tell you something is ugly. If the cost cannot be named as a future event, it is not
reported at all.
