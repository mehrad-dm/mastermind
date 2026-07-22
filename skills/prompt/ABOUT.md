---
title: Prompt — turning a rough ask into one an AI can actually execute
blurb: Rewrites a vague request into a precise, well-structured prompt, so you stop paying for answers to the question you didn't mean to ask.
---

## The problem this solves

Most disappointing AI output isn't a model failure. It's an under-specified request.

You type *"make this page nicer"* and get something generic. You type *"write a script to clean up my
data"* and get code that guesses at your file format. The model wasn't wrong — it answered the question
you asked. The question just didn't contain enough to answer well.

**Prompt is the skill that fixes the question before you spend a run on the answer.**

Worth being precise about scope: this is about the *instructions you send to an AI*. It has nothing to
do with making your software faster or your code shorter.

## What goes wrong without it

- **Vague adjectives do the heavy lifting.** "Clean", "modern", "professional", "better" — these feel
  like requirements but carry almost no information. Two people reading them picture different things,
  and so does the model.
- **The output arrives in the wrong shape.** You wanted three bullet points and got four paragraphs,
  because nobody said what the answer should look like.
- **Backstory crowds out the signal.** Long preambles that don't change the answer dilute the parts that
  do. More words is not more clarity.
- **You find out it was wrong after the expensive part.** A thin prompt on a large task means you
  discover the misunderstanding at the end, having paid for the whole detour.

## How it actually works

**It gets your real intent first.** If the goal is genuinely ambiguous, MasterMind asks you one or two
sharp questions rather than inventing requirements you never mentioned. This matters: the job is to
sharpen your intent, not to replace it with a more convenient one.

**Then it rewrites, applying only what fits:**

- **The task leads.** Goal in the first line, plainly, with a clear picture of what "done" means.
- **Only load-bearing context stays.** The why, the audience, the constraints, what already exists.
  Everything that doesn't change the output is cut.
- **Vague becomes concrete.** "Fast" becomes a number. "Nice" becomes a specific reference to match.
- **The parts get separated.** Context, task, requirements, and output format are labelled, so the model
  can tell instructions from background instead of guessing.
- **An example appears when words aren't enough.** One short sample of the desired output usually beats
  three sentences describing it.
- **The output contract gets pinned.** Format, length, what to include, what to leave out.

Shorter is a side effect, not the goal. Padding and repetition go; every detail that changes the answer
stays.

## When it fires

You don't need a command. Any of these reaches for `prompt`:

> *"can you improve this prompt before I run it?"*
> *"how should I ask for this?"*
> *"I keep getting bad answers from this — what am I doing wrong?"*
> *"here's what I want to ask another AI, make it sharper"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ sharpening this before you send it
   └ prompt · intent → rewrite → what changed
```

## When it does *not* fire

- **You want your code optimized.** That's `perf` — measuring and fixing slow software. `prompt` never
  touches your code; it only touches text you send to a model. The names sound adjacent; the jobs share
  nothing.
- **The ask is fuzzy but it's a build task, not a prompt.** If you want *MasterMind itself* to build
  something and the requirements are unclear, that's `spec` — it turns a vague ask into a buildable
  specification. `prompt` is for when the finished text is the deliverable and you'll send it somewhere
  else.
- **You want to teach MasterMind a lasting preference.** That's `levelup`. A rewritten prompt is a
  one-off artifact; it doesn't change future behavior.

## What you get

Three things: the rewritten prompt in a block you can copy straight out, two to four bullets explaining
what changed and why, and an honest list of anything still ambiguous that only you can decide.

Scope is never silently expanded. If sharpening the request surfaces a real product decision, MasterMind
puts it in front of you rather than quietly picking for you.
