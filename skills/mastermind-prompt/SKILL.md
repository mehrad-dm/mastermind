---
name: mastermind-prompt
description: Turn a vague or rushed request into a sharp, token-efficient, AI-ready prompt — so the model builds what the user actually wants on the first try. Use when the user asks to "optimize / improve / fix my prompt", when a request is fuzzy and they want help expressing it to an AI, or before firing a big/expensive task off a thin prompt. This is prompt-for-an-AI optimization, not code optimization (that's /simplify).
---

# MasterMind — Prompt

The single biggest lever on AI output quality is the prompt. Most weak results aren't a model failure —
they're an **under-specified request**. This skill rewrites a user's rough ask into a prompt an AI will
execute well: clear intent, only the context that matters, structured, and token-efficient. Grounded in
Anthropic's prompt-engineering guidance (`~/.mastermind/engineering/core/agent-loop.md`, `product-sense.md`).

## First: get the real intent
If the goal is ambiguous, **ask one or two sharp questions before rewriting** — never invent
requirements the user didn't imply. You sharpen their intent; you don't hijack it.

## The rewrite checklist (apply what fits — don't bloat)
1. **Lead with the task.** State the goal in the first line, plainly. Treat the AI like a sharp new
   hire: say exactly what "done" looks like.
2. **Give load-bearing context only** — the *why*, the audience, the stack/constraints, what already
   exists. Cut backstory that doesn't change the output.
3. **Be explicit and concrete.** Replace vague adjectives ("nice", "modern", "clean") with specifics
   (what, for whom, which constraints, which examples to match).
4. **Structure it.** Separate the parts — `context` / `task` / `requirements` / `output format` —
   with headings or XML-ish tags (`<context>…</context>`) so the model can parse roles of text.
5. **Show, don't just tell.** Add one short example of the desired output (or a reference to match)
   when words alone are ambiguous — few-shot beats adjectives.
6. **Set the role** when it sharpens tone/expertise ("You are a senior accessibility engineer…").
7. **Pin the output contract** — format, length, what to include/exclude, and any must-nots.
8. **Ask for reasoning** on hard/analytical tasks ("think step by step before answering").

## Token efficiency (efficient ≠ lossy)
Cut politeness padding, redundancy, and repeated context; compress prose to bullets; keep every
detail that changes the output and no more. Fewer tokens *and* a sharper signal — not a shorter prompt
that drops requirements.

## Output
Return, in this order:
1. **The optimized prompt** — ready to paste, in a copyable block.
2. **What changed & why** — 2–4 bullets (e.g. "added output format; cut 3 lines of backstory; made
   'fast' concrete = <2.5s LCP").
3. **Open questions** — anything still genuinely ambiguous the user should decide.

Never silently change scope. If the request implies a product/business decision, surface it rather than
guessing (`product-sense.md`).
