---
title: QA — proving it works, not asserting it works
blurb: How MasterMind confirms a change actually does what you asked, and why tests are your call but verification never is.
---

## The problem this solves

The single most common failure in AI-assisted work isn't bad code. It's *unverified* code — a change
that was written, never run, and then described as finished.

It's an easy failure to miss, because the report sounds identical either way. "Added the export button,
it now downloads a CSV" reads the same whether someone clicked it or nobody did. You find out which,
later, in front of a user.

**QA is the rule that you don't get to say it works until you've watched it work.**

## What goes wrong without it

- **Confidence without evidence.** "This should work" quietly becomes "this works" between one sentence
  and the next. Nothing was run.
- **The happy path is the only path.** The feature is checked once with ideal input. Empty results, a
  failed request, a logged-out user, a slow connection — never exercised, so never handled.
- **Verifying the code instead of the requirement.** Checking that the code does what the code says,
  rather than what you asked for. The bug and the check share the same misunderstanding.
- **A test suite you never agreed to.** The opposite failure: files appear in your repo, a testing
  framework gets installed, and now you own a suite you didn't ask for and don't maintain.

## How it actually works

There are two modes, and the default one doesn't involve writing tests at all.

**Verify — always.** This is the baseline for every change.

First, define what "works" means, in terms of something you could actually observe. If nobody can say
what correct looks like, nothing can be verified.

Then pick the lightest real check and run it: start the app and click the flow, call the endpoint, run
the command, render the component. Drive the actual thing rather than reasoning about it. Use whatever
the project already provides — no new tooling to check one button.

Then the happy path, followed by the edges that matter for this particular change: empty, error,
loading, none/one/many, unauthorized, malformed, offline. Then the invisible layer — typecheck, lint,
build, the browser console, and for interfaces, keyboard access and focus.

Finally, report what was run and what was observed, with the output. If a check couldn't be run, that's
stated rather than glossed over.

If a bug turns up, the fix goes to the cause — never a workaround that makes the check pass.

**Test-first — on request.** When you want tests, or want to work test-first, the loop is: write one
small failing test describing the next behavior, watch it fail for the right reason, write the minimum
code to pass it, then improve the design while it stays green. Tests describe behavior you could
explain to a person, not internal implementation details, which age badly.

One deliberate rule sits underneath this: **the testing isn't optional, but the files are yours.** After
testing thoroughly, MasterMind asks whether to keep the test files as coverage or remove them. If your
project already has a suite, it adds to it. If it has none, it doesn't impose one on you.

## When it fires

You don't type a command. Say any of these and MasterMind reaches for `qa`:

> *"does this actually work?"*
> *"test it before we ship"*
> *"I've never actually run this end to end"*
> *"write some tests for this"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ qa · define works → drive it → edges → evidence
```

## When it does *not* fire

- **Something is broken and you don't know why** — that's `debug`. This is the pair people mix up most.
  QA asks *"does this do what it's supposed to?"* and answers yes or no with evidence. Debug starts once
  the answer is no and the reason isn't obvious, and its job is finding the cause. QA finds that
  something's wrong; debug finds out why. QA hands off to debug when a failure isn't self-explanatory.
- **Something works but is slow** — that's `perf`. QA checks correctness; slowness is a measurement
  problem with a different method.
- **A one-line copy change** — running the whole battery on a changed label is ceremony. Effort matches
  stakes.

## What you get

A plain verdict — works or doesn't — with the commands, output, or screenshots behind it, the edge cases
actually exercised, and an honest list of what couldn't be covered and why. Never a claim of success
standing in for the check itself.
