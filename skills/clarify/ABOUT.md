---
title: Clarify: when the answer was right and you still did not follow it
blurb: Re-pitches the last answer in plain words or as a picture, because a shorter version of an unclear explanation is still unclear.
---

## The problem this solves

The answer was correct. You read it twice and still could not act on it.

That is not a knowledge problem, it is a delivery problem, and it has become more common as models
got more capable: longer answers, denser vocabulary, more qualifiers per sentence. The information is
all there. The path through it is not.

Most people respond by asking for "something shorter". That rarely helps, because length was not the
fault. A compressed version of a badly shaped explanation is a badly shaped explanation with fewer
words in it.

## When it fires

The moment you signal the last answer did not land. *"I don't understand."* *"Simpler please."*
*"You lost me."* *"What does that mean?"* *"Too long."* *"Show me."* A question that repeats something
already answered counts too, because repeating a question is what not understanding sounds like.

You do not have to type a command. Saying it in your own words is the trigger.

It does not fire on a new question. Asking what CORS means is a question and gets an answer. Asking
what *that* meant, about the paragraph just written, is this.

## What it does

First it works out which of four things failed, because the repair is different for each: missing
context, a word you do not hold, a shape that prose cannot carry, or simply too much at once.

Then it picks one form and commits to it. Either plain words, leading with the point, short sentences,
one instruction at a time. Or a picture, when the thing has a shape: a tree, a call stack, a table, a
before and after, a type signature. Plain text over rendered diagrams, because it reads faster and
works in every tool.

Then it stops, and asks one question to find the next gap, rather than delivering a second wall of
text.

## Why it also makes MasterMind better

When the fault was the writing rather than a genuinely hard subject, that gets recorded, and the
`levelup` skill reads those records. So the skill repairs one answer today and reduces the number of
answers that need repairing later.

## What it is not

It is not documentation. Writing a usage guide for an internal package is the `explain` skill.

It is not a summary. It will not drop the condition that makes a statement true in order to make the
sentence shorter.
