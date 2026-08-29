---
name: deepen
description: Use when the user wants to know where the design is hurting, before choosing what to fix: "this is getting messy", "where should we clean up?", "what is the worst part of this codebase?", "why is this so hard to change?", "it takes five files to add one field". Surveys an area, ranks the candidates, and the user picks one. Not for a diff you just wrote: that is code-reviewer. Not for executing a chosen restructure: that is the refactorer agent.
---

# MasterMind: Deepen

Find where the design costs the most, present the candidates, let the user choose. **You survey and
rank. You do not restructure**: the chosen one goes to the `refactorer` agent, which is where the edits
happen and where behaviour is proven unchanged.

Load `~/.mastermind/engineering/core/principles.md` and `mindset.md` for the vocabulary. Read the
field's `audit-rules.md` and `.mastermind/brief.md` **if they exist**: with no field pack you still
have the universal principles, and with no brief you use the codebase's own names.

## Scope it before you read anything

A whole-repo survey produces a list nobody acts on. Narrow first:

1. Take the area the user named. If they named none, use `git log` to find what changed most in the
   last few months. Design debt hurts where the code moves.
2. Cap it. Six candidates maximum, and fewer is better.
3. Send the reading to a subagent where you have one, so the survey does not eat this context. Where
   you do not, read in the same order and keep notes short: the cap is what protects the context.

## What you are looking for

Not ugliness. Cost. Each of these has a named future price:

- **A shallow module**: the interface costs about as much to understand as the implementation it hides.
  It adds a name and buys nothing.
- **A concept spread thin**: understanding one idea means opening five files. The split was mechanical,
  not conceptual.
- **A leaked boundary**: callers know the shape of what is behind the seam, so the seam cannot move.
- **A path that cannot be tested** without standing up the world, because there is nowhere to substitute.
- **An invariant enforced in several places**, which will drift, because one day someone edits four of five.

**Apply the deletion test** to anything suspected shallow: if this module disappeared and its callers
did the work inline, would the code get worse? If the honest answer is no, that is the finding.

## Present them as a choice, not a report

One block per candidate, ranked, in plain text. Use the forms in
`~/.mastermind/engineering/core/clarity.md`: a tree, a call flow, a before and after. Plain text over a
rendered diagram, because it reads faster and works in every tool.

Each candidate carries five things and nothing else:

1. **Where**: the files, with line numbers.
2. **The cost, as a future event**: "adding a fourth provider means editing all five call sites." Never
   a feeling, never "this is ugly".
3. **The shape after**, drawn.
4. **What it buys**: fewer places to hold in your head, or a seam a test can enter.
5. **Confidence**: strong, or worth-discussing. Say which, and say why for the weak ones.

Then one line naming your recommendation and the reason. Then stop, and let them pick.

## After they pick

Hand it to the `refactorer` agent with the contract from `core/agent-loop.md`: the goal, the non-goals,
the stopping condition, and the evidence it must return. Behaviour is preserved and proven green, or the
change does not land.

If the reasoning would stop the same candidate being re-proposed later, add a line to
`.mastermind/brief.md`. Only then: a decision nobody would re-litigate is not worth the space.

## Gotchas

- **Taste is not a cost.** If you cannot name the future event, the candidate is not a finding. Drop it.
- **Do not survey a diff.** A change you just made goes to `code-reviewer`. This reads code that already
  shipped.
- **Do not propose a rewrite.** A candidate a person can review is worth more than a correct plan they
  cannot.
- **Shallow is not small.** A three-line function with an obvious name is fine. The test is whether the
  interface is as complex as what it hides.
- **Never edit here.** Finding and fixing in one pass is how a survey turns into an unreviewable diff.
