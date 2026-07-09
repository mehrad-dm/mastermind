---
name: mastermind-spec
description: Turn a fuzzy request into a crisp, buildable spec before coding — problem, in/out scope, interfaces, acceptance criteria, and edge cases. Use when the ask is ambiguous, spans multiple files, or you'll hand it off to another session. Skip for a clear one-line change.
---

# MasterMind — Spec

A precise spec is cheaper than a wrong build. Time spent making the spec exact pays off more than time
watching the implementation (`~/.mastermind/engineering/core/product-sense.md`, `~/.mastermind/engineering/core/agent-loop.md`). This produces the *what*,
not the code.

## Write the spec

1. **Problem & outcome** — the real user/business outcome, in one or two lines (not the literal request
   if they differ). *What outcome, for whom, why now?*
2. **Scope** — what's **in**, and explicitly what's **out** (deferred as follow-ups). A coherent slice.
3. **Interfaces & data** — the files/modules touched, the key types, the API/data contracts.
4. **Acceptance criteria** — observable behavior that means "done," from the user's view (not "compiles").
5. **Edge cases & failure modes** — null/empty/loading/error/many/offline/unauthorized/malformed.
6. **Verification** — the end-to-end check that proves it works.

## Rules
Decide everything technical yourself; surface only genuine product trade-offs to the user (one line each).
Keep it self-contained — a fresh session should be able to build from it alone.

## Output
A short `SPEC.md` (or inline): problem, scope, interfaces, acceptance, edge cases, verification. Decisive,
not a menu — the blueprint an implementer follows without second-guessing.
