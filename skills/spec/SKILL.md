---
name: spec
description: Use when the ask is ambiguous, the scope is unclear, terms are being used inconsistently, the work spans multiple files, or it will be handed to another session. Symptoms: "make it better", "add the thing", or disagreement about what's in scope. Skip for a clear one-line change.
---

# MasterMind — Spec

A precise spec is cheaper than a wrong build. Time spent making the spec exact pays off more than time
watching the implementation (`~/.mastermind/engineering/core/product-sense.md`, `~/.mastermind/engineering/core/agent-loop.md`). This produces the *what*,
not the code.

## Write the spec

1. **Problem & outcome** — the real user/business outcome, in one or two lines (not the literal request
   if they differ). *What outcome, for whom, why now?*
2. **Scope** — what's **in**, and explicitly what's **out** (deferred as follow-ups). A coherent slice.
3. **Name the key terms (glossary).** List the domain nouns actually in use; define each in one sentence
   **+ what NOT to call it** (synonyms to avoid); resolve any word that means two things (or two words
   that mean one). One concept, one name — then use these exact names in the spec, types, and code. Names
   are the data model in disguise; muddled naming is a bug waiting to happen.
4. **Interfaces & data** — the files/modules touched, the key types, the API/data contracts.
5. **Acceptance criteria** — observable behavior that means "done," from the user's view (not "compiles").
6. **Edge cases & failure modes** — null/empty/loading/error/many/offline/unauthorized/malformed.
7. **Verification** — the end-to-end check that proves it works.

## Rules
Decide everything technical yourself; surface only genuine product trade-offs to the user (one line each).
Keep it self-contained — a fresh session should be able to build from it alone.

## Spec vs. the `architect` agent
Spec is the **what**; `architect` (`~/.mastermind/agents/architect.md`) is the **how**. Spec produces the
problem, scope, glossary, acceptance criteria, and edge cases; architect produces module/interface
boundaries, the data model, key types, and the technical decisions behind them.

- Ask is *fuzzy* → run `spec` first. Ask is *clear but the design isn't* → go straight to `architect`.
- **Handoff:** feed the finished spec to `architect` as its input — it restates the problem from the spec's
  scope and acceptance criteria instead of re-deriving them. Non-trivial work usually wants both, in that
  order; a small, well-understood change needs neither.
- Spec's "Interfaces & data" step stays at the level the spec needs (files touched, contracts the
  acceptance criteria depend on). Don't design the modules here — that's architect's output, not spec's.

## Output
A short `SPEC.md` (or inline): problem, scope, interfaces, acceptance, edge cases, verification. Decisive,
not a menu — the blueprint an implementer follows without second-guessing.
