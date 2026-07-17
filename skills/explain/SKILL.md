---
name: explain
description: Generate or refresh AI-friendly usage docs for an INTERNAL package — a colocated doc beside each public unit (component, function, hook, service, class) with its API, usage, and the non-obvious gotchas — so any AI or human uses it correctly by default. Works for any package (with or without AI), so if you switch models the new one still understands your code. Asks and confirms before writing. Use when an internal package has little/no usage docs.
---

# Document Package — make an internal package self-explaining to any model

Most internal packages ship with **no usage docs**, so every consumer — a teammate, *or an AI* — reads the
source, guesses the intended usage, and gets the gotchas wrong. This skill fixes that: **one colocated
usage doc per public unit**, capturing the API *and* the non-obvious rules, so the next reader is correct
on the first try. It applies to **any** package — a UI component kit, a utils library, a services/API
layer, a hooks package, an internal SDK.

> **Why it matters for portability:** these docs are the layer that makes your package understandable to
> *any* model. If you migrate from one AI to another (Claude → GPT → Gemini), the new model still
> understands your package immediately — the knowledge lives in the repo, not in one model's head.

## Ask first — always
This writes files into the user's repo. **Confirm before doing anything:** *"I can generate AI-friendly
usage docs for `<package>` so any model (and teammate) understands it correctly — one doc per public unit,
with the gotchas. Want me to? (I'll show one sample first.)"* Show a **sample doc** for one unit and get a
thumbs-up before fanning out across the package.

## Method

1. **Discover the public units.** Read the package's public entry (`index.ts`/exports) for the real list —
   components, exported functions, hooks, services, classes. Note any existing docs' style and **match it**.
2. **Read the source of truth — don't guess.** For each unit: the implementation, its types, its
   variants/options, its tests/stories, and **one real usage** in the codebase. Verify every claim against
   the code (never document a guess; mark "unverified" or omit).
3. **Write a colocated doc** (a `README.md`/doc beside the unit) with a consistent template:
   - **Title + one-line purpose + what it's built on.**
   - **Signature / API** — a table: params/props/args · type · default · description; what it returns.
   - **Quick start** — the minimal correct usage (real import path).
   - **Variants / options / states** (where applicable) — with a code example each.
   - **Composition** — how it combines with siblings.
   - **Examples** — the handful of real scenarios people actually need.
   - **Gotchas** — the highest-signal section: rules the API *doesn't* enforce but people get wrong
     (default values, which state hides what, reserved-but-unimplemented options, ordering constraints).
   - **Errors / accessibility / TypeScript** — as relevant to the unit's kind.
4. **Prioritize the gotchas.** The API table can be inferred from types; the gotchas cannot. That's the value.
5. **Keep it in sync.** The code is the SSOT; the doc is derived. Regenerate a unit's doc when its API
   changes — a stale doc misleads confidently, worse than none.

## Guardrails
- **Derive from source, never invent.** Unconfirmable behavior → "unverified" or omit.
- **One doc per unit, colocated** — found next to the thing it describes, travels with it.
- **Match the package's existing doc style** if any exists; consistency beats your template.
- **Confirm scope + a sample before mass-generating** — the template must fit before you fan out.
