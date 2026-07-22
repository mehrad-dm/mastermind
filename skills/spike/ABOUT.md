---
title: Spike — buying knowledge cheaply, then throwing the receipt away
blurb: What MasterMind does when nobody knows whether an approach will work, and why the code it writes is meant to be deleted.
---

## The problem this solves

Sometimes the honest answer to "how should we build this" is *nobody knows yet*. Will this service handle
files that size? Does this library actually do the thing its homepage claims? Is this integration a
two-hour job or a two-week one?

You can plan around that uncertainty for a long time. Reality answers in twenty minutes.

The catch is what usually happens next. Someone builds a rough thing to find out, it works, and it ships —
no tests, no error handling, hard-coded values still sitting in it. The experiment becomes the product by
accident, and nobody ever decides to let that happen.

**Spike separates the two: learn fast, then build properly.**

## What goes wrong without it

- **Planning in the dark.** Elaborate designs built on an assumption nobody checked. When the assumption
  fails, the design fails with it, and the work that went into it is gone.
- **The prototype that quietly ships.** Throwaway code with production traffic on it. Every shortcut taken
  in the name of speed is now a permanent liability nobody remembers making.
- **Experiments without a question.** Building something rough with no clear idea of what it's meant to
  prove, which produces activity rather than an answer.
- **Endless exploration.** No time limit, so a two-hour question absorbs three days.

## How it actually works

**1. Name the one question.** A spike answers a single risky unknown, stated plainly enough that the
answer is yes or no. "Can this handle a twenty-megabyte upload without timing out?" If there's no
question, there's no need for a prototype — and that check alone kills a lot of pointless work.

**2. Build the smallest thing that answers it.** Hard-coded values, no error handling, no tests, no
polish. This feels wrong if you're used to careful work, and it's the correct instinct here: quality
invested in code that will be deleted is quality wasted. Speed is the entire point.

**3. Extract what reality taught.** Write down the answer and — often more valuable — the surprises. The
thing you didn't think to ask about is usually where the real risk was hiding.

**4. Delete it and build properly.** The real version gets the full treatment: design, tests, review,
rigor. The spike does not ship. It stays in a scratch area, isolated so it can't drift into production
by accident.

It's time-boxed throughout. The deliverable is the *learning*, never the code.

## When it fires

You don't type a command. Say something like this and MasterMind reaches for `spike`:

> *"will this even work"*
> *"can you try something quick before we commit to this"*
> *"I don't know if this API can do what we need"*
> *"is this a one-day thing or a one-month thing"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ trying it for real to see if it holds up
   └ spike · name the question → smallest test → extract → discard
```

## When it does *not* fire

- **Building something real** — that's `build`, and confusing the two is the expensive mistake. `build`
  produces code intended to live: designed, tested, reviewed, maintained. `spike` produces code intended
  to die, and its shortcuts are only safe *because* it dies. The moment a spike ships, every one of those
  shortcuts becomes debt you never chose to take on. If the path is already clear, skip the spike and
  build it properly the first time.
- **The answer is in the documentation** — that's `learn`. Spikes are for questions only running code can
  settle. Writing a prototype to discover something the docs state plainly is slower, not faster.
- **Something is broken and you need to know why** — that's `debug`. A spike explores an unknown future;
  debug investigates a known failure.

## What you get

A direct answer to the question you asked, the surprises that came with it, and a clear recommendation —
either "now build it properly, here's what we know" or "don't build this, here's why." A no is a good
outcome. It cost you an afternoon instead of a quarter.
