---
title: Spec — agreeing what to build before anyone builds it
blurb: How MasterMind turns a vague ask into a precise, decided blueprint, so the build isn't a guess dressed up as progress.
---

## The problem this solves

"Make the dashboard better." "Add the notifications thing." "Clean up the user stuff."

These are perfectly normal sentences, and they're also unbuildable. Not because they're lazy, but
because the person saying them has a picture in their head that the words don't carry. An AI will
happily build *something* from them — quickly, confidently, and not the thing you meant.

The expensive part isn't the misunderstanding. It's that you only discover the misunderstanding after
the code exists, when unwinding it costs a hundred times more than a conversation would have.

**Spec is the step that makes the disagreement happen on paper, while it's still cheap.**

## What goes wrong without it

- **Two people, two features.** You and the AI each believe the ask is obvious, and each believe
  something different. Nothing surfaces this until the demo.
- **One word, two meanings.** "User" means the account in one file and the person in another. "Order"
  means the purchase here and the sort sequence there. Muddled names aren't a cosmetic problem — they
  become a muddled data model, and then a class of bugs.
- **Scope with no edges.** Without a written line between in and out, everything adjacent gets pulled
  in. A small change becomes a sprawl nobody chose.
- **Nothing survives the session.** The reasoning lived in a chat window. The next session, or the next
  person, starts from zero and re-derives it differently.

## How it actually works

Spec produces a short written document — the *what*, deliberately not the code. It covers seven things.

**The problem and the outcome.** What real result this produces, for whom, and why now — stated in one
or two lines. Sometimes this differs from the literal request, and saying so out loud is the whole
point.

**Scope.** What's in, and explicitly what's out. The out-list is the more useful half; it turns "we'll
see" into a decision and parks the rest as follow-ups.

**A glossary.** The domain words actually in play, each defined in a sentence, each with the synonyms to
*avoid*. Any word meaning two things gets split; any two words meaning one thing get merged. Those exact
names are then used in the spec, the types, and the code. This section looks pedantic and is quietly the
highest-value part of the document.

**Interfaces and data.** Which files and modules get touched, the key types, the contracts between
pieces.

**Acceptance criteria.** Observable behavior that means done, described from your point of view — not
"it compiles."

**Edge cases and failure modes.** The empty, missing, slow, unauthorized, and malformed cases, listed
before they're discovered in production.

**Verification.** The end-to-end check that will prove the finished thing works.

One rule shapes all of it: every *technical* decision is made for you and written down as decided. Only
genuine product or business trade-offs — the ones only you can own — come back as questions, one line
each. A spec that hands you a menu has failed at its job.

## When it fires

You don't type a command. Say any of these and MasterMind reaches for `spec`:

> *"the onboarding flow needs an overhaul"*
> *"I want something like Stripe's dashboard but for our data"*
> *"can you make search better"*
> *"write this up so another session can pick it up"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ pinning down what we're actually building
   └ spec · outcome → scope → glossary → acceptance → edges
```

## When it does *not* fire

- **A clear, contained change.** If the ask is already unambiguous and lives in one place, writing a
  document about it is pure overhead. MasterMind just does the work.
- **When the ask is already clear enough to build** — that's `build`. This is the confusion worth
  understanding: `spec` decides *what* and produces a document with no code; `build` produces working,
  verified code. They're often sequential, not alternatives — a fuzzy ask gets specced, then built from
  the spec. If you already know what you want, skipping straight to build is correct, not sloppy.
- **Choosing what to read before starting** — that's `route`. Route is about context, not requirements:
  it decides which files and knowledge to load for a task. Spec decides what the task *is*. Route can
  point at spec as the thing to do next; it never replaces it.

## What you get

A short, self-contained document a fresh session could build from without asking you anything — decisive
rather than a set of options, with the disagreements resolved before any code exists.
