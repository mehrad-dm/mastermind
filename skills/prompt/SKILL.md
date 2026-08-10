---
name: prompt
description: Use ONLY when the user explicitly asks to improve a prompt aimed at an AI: "improve my prompt", "fix this prompt", "how should I ask for this", "make this prompt better". A prompt pasted to be answered or executed is a task, not a rewrite request: do that task instead. About prompts for an AI, not about optimizing code.
---

# MasterMind: Prompt

The single biggest lever on AI output quality is the prompt. Most weak results aren't a model failure,
they're an **under-specified request**. This skill rewrites a rough ask into a prompt an AI executes well:
clear intent, only the context that matters, structured, token-efficient.

> **The user's own words are not yours to rewrite.** Fire only on an explicit ask, propose rather
> than apply, and name every requirement you added or cut, `~/.mastermind/engineering/core/rigor.md` § Stay in scope.

## Do not fire unless asked

Auto-invocation is the danger here: rewriting a prompt the user meant you to *answer* replaces their
work with your paraphrase and loses whatever they actually wanted. The bar is an **explicit request to
improve the prompt**.

| The user does this | You do this |
| --- | --- |
| "improve / fix / sharpen this prompt" | This skill |
| Pastes a prompt and says "run this" / "what do you think?" / nothing | **Answer or execute it.** Not this skill |
| Pastes a prompt written for *another* tool, asking what it does | Explain it. Not this skill |
| Asks for a prompt to be *written* from scratch | Write it: then the checklist below applies |

If it's genuinely ambiguous, ask one question before rewriting. Guessing wrong wastes a turn; rewriting
unasked destroys their text.

## The prompt stays theirs

The output is a **proposal**, never an action:

1. **Never execute the rewritten prompt**: not in the same turn, not "to show it works". Hand it back.
2. **Never drop a requirement.** Every constraint in the original survives, or you say out loud that you
   cut it and why. Silent removal is the failure mode that makes this skill dangerous.
3. **Never add a requirement they didn't imply.** Additions get named in "what changed": a specific the
   user never chose (a framework, a length, a tone) is a guess wearing their voice.
4. **Never rewrite a prompt containing credentials, private data, or client names** into a form that
   moves them somewhere new. Flag them and quarantine instead (`quarantine`).

## First: get the real intent

If the goal is ambiguous, **ask one or two sharp questions before rewriting**: the rewrite carries only
requirements the user actually implied. You sharpen their intent; it stays theirs.

## The rewrite checklist (apply what fits: keep it lean)

1. **Lead with the task.** State the goal in the first line, plainly. Treat the AI like a sharp new
   hire: say exactly what "done" looks like.
2. **Give load-bearing context only**: the *why*, the audience, the stack/constraints, what already
   exists. Cut backstory that doesn't change the output. Context is never the cruft; padding is.
3. **Be explicit and concrete.** Replace vague adjectives ("nice", "modern", "clean") with specifics
   (what, for whom, which constraints, which examples to match).
4. **Structure it.** Separate the parts, `context` / `task` / `requirements` / `output format`,
   with headings or XML-ish tags (`<context>…</context>`) so the model can parse roles of text.
5. **Show an example, not just a description**: but show *two or three varied* ones, labeled
   illustrative. A single gold example gets copied: the model matches its length, tone and structure.
6. **Set the role** when it sharpens tone/expertise ("You are a senior accessibility engineer…").
   One line. A role statement is not a substitute for saying what the output must contain.
7. **Pin the output contract**: format, length, what to include/exclude, and any must-nots.
8. **Say what to do, not what to avoid.** "Answer in three sentences" beats "don't be verbose";
   a list of prohibitions can anchor the model toward the very failure it names.

## Keyword effects: what words actually do to a modern model

Prompts written for 2023-era models are now actively harmful, because current models follow
instructions far more literally. What to strip, and what to reach for instead:

| Pattern | Effect today | Instead |
| --- | --- | --- |
| `CRITICAL:` / `MUST` / `NEVER` / ALL-CAPS, several per prompt | Emphasis inflation: when everything is critical, nothing is. Causes over-triggering and rigid behavior in gray areas | Plain imperative + the reason. Reserve emphasis for the one genuinely load-bearing constraint |
| "think step by step", `<scratchpad>` instructions | Redundant on reasoning models, which already think; can add latency for nothing | Control depth with the tool's thinking/effort setting, not prose |
| "double-check your work", "verify before answering" | Current models self-verify; instructing it causes *over*-verification and padding. This inverts the old best practice | Delete. State the acceptance test instead |
| "be thorough", "don't be lazy", "don't stop early" | Written against models that quit early; now just noise | Delete |
| "try to", "if possible", "ideally" on a real requirement | Read literally as permission to skip it | State it as a requirement |
| "don't hallucinate", "only use the provided context" | Still useful when grounding genuinely matters | Keep: but pair it with what to do when the answer isn't there ("say you don't know") |
| Politeness padding, repeated context, restated rules | Consumes budget and makes the model reconcile wordings | Say it once, in the right place |

**Placement matters as much as wording.** Long documents go **first**, the question **last**: a model
attends best to the start and end, and a question buried above 50k tokens of context gets lost. If the
same preamble is reused across calls, keeping it stable and at the front is also what makes prompt
caching hit (`core/agent-loop.md`).

## Token efficiency (efficient ≠ lossy)

Cut politeness padding, redundancy, and repeated context; compress prose to bullets; keep every
detail that changes the output and no more. Fewer tokens *and* a sharper signal, never a shorter prompt
that drops requirements. **Length is not the metric**: a too-short prompt produces generic output because
the model fills the gaps with safe defaults.

## Output

Return, in this order:

1. **The optimized prompt**: ready to paste, in a copyable block. Nothing else in that block.
2. **What changed & why**: 2–4 bullets, and every one of them **names an addition or a removal**
   (e.g. "added output format; cut 3 lines of backstory; made 'fast' concrete = <2.5s LCP").
3. **Open questions**: anything still genuinely ambiguous the user should decide.

Flag any change of scope out loud. If the request implies a product/business decision, surface it rather
than guessing (`product-sense.md`).
