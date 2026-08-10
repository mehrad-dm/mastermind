---
name: double-check
description: Use when you are about to tell the user something works, hand over a decision you feel confident about, or make a change that can't be undone: and when a review came back suspiciously clean. Symptoms: "are you sure?", "you said that was fixed last time", nothing to report, the answer feels too tidy. Not for a routine small change; not for reviewing a finished diff: that's `code-reviewer`; not for driving a finished change end-to-end to get evidence: that's `qa`. Doubt tests a claim (a diagnosis, a design call, an answer), which is often not runnable code.
---

# MasterMind: Double-check

You are about to hand over something you believe. Belief is not evidence
(`~/.mastermind/engineering/core/rigor.md` → Report against evidence), and the check that catches a wrong
claim has to happen while the work is still moving, not after the user has acted on it. Claim:
**$ARGUMENTS**.

The kernel's rule: **whatever did the work doesn't get to grade it**: is the entire mechanism here.
This applies it to a *claim*, not only to a diff.

## The five moves

1. **Claim.** Write the belief you are about to act on or hand over, in **one sentence**: *"the retry
   loop now handles the expired-token case."* A paragraph means several claims, doubt them one at a
   time. The claim stays with you; it is the thing under test, not context to share.

2. **Extract.** Split it into the **artifact** (the code, the design, the answer, the diagnosis) and the
   **contract** it must satisfy (the requirement, the spec line, the invariant, the question actually
   asked). **If you can't write the contract down, stop and get one.** Without it there is no bar, and
   any reviewer defaults to grading your intent.

3. **Doubt.** Dispatch a reviewer in a fresh context with **the artifact and the contract, nothing else**.
   Brief it adversarially:

   > Find what is wrong with this. Assume the author is overconfident. Do not validate and do not
   > summarize: report what fails the contract, or state plainly that you could not find anything
   > after thorough examination.

   **Hand the artifact over via a file or stdin, never interpolated into a shell-quoted argument**,
   code and prompts carry backticks, `$(...)`, and quotes that truncate the message or execute in your
   shell. A clipped artifact reviews clean for the worst reason: the flaw didn't survive the paste.

   **Never pass it your claim.** The excuse is always *"it'll review faster with the context"*: but the
   context you're about to add is your conclusion, and a reviewer handed a conclusion hunts for reasons
   it holds. You would be buying agreement and calling it review.

4. **Reconcile.** Take each finding through these in order and stop at the first that fits:
   1. **It misread the contract**: the contract was ambiguous, not the artifact wrong. Then **rewrite
      the contract and run the cycle again**; this class is where self-serving reconciliation hides, so
      it costs a cycle rather than discarding a finding.
   2. **Valid and actionable**: fix it.
   3. **Valid, and a trade-off worth accepting**: park it with the reason *and* the cost, in writing.
   4. **Noise**: drop it, and name which ones you dropped.

   **Write each verdict in one line: `<finding> → <class> · <reason>`.** Nothing else belongs in that
   line: no gratitude, no "you're absolutely right", no praise for the reviewer. Agreement language is
   the tell that you settled a finding socially instead of evaluating it. A reviewer is a function, not
   a colleague whose goodwill you need.

5. **Stop.** Bounded at **three cycles**, then every open finding exits as fixed · parked-with-a-reason ·
   **blocked** (handed to the human): the same close-out, in the same words, `build` step 6 runs
   (`~/.mastermind/skills/build/SKILL.md`), including its two prohibitions.

## The red flag: doubt theater

Count it, don't feel it. **Across two or more cycles where the reviewer surfaced substantive findings,
how many did you classify actionable?** Zero means you are validating, not doubting.

Stop the loop there. Hand the reviewer's findings to the human **unreconciled**, alongside your
reasoning for each, and let them adjudicate. A reviewer that keeps finding real things while you keep
finding reasons they don't apply is not evidence of a clean artifact. It is evidence of a broken judge,
and the judge is you.

## Doubt vs. `code-reviewer`

`code-reviewer` (`~/.mastermind/agents/code-reviewer.md`) reviews a **diff that already exists**, at
diff scope, and returns ranked must-fix/should-fix/nits for a human to decide on, it proposes and never
applies. Doubt interrogates a **claim still in flight**, which is often not code at all: a diagnosis, a
design call, an answer, a "this works" you're one sentence from saying. It ends with *your* written
verdict on every finding, before the user sees anything.

When the artifact is a finished diff, that is `code-reviewer`: and `build` step 6 already runs it.
Don't wrap one in the other.
