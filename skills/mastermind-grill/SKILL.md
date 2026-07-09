---
name: mastermind-grill
description: Before building on an unfamiliar tool, API, or library, interrogate your own understanding against its real docs/source — list your assumptions, verify each, surface the unknowns. Use for a new dependency, a tricky API, or whenever "I think it works like…" is load-bearing. Prevents confident-but-wrong builds.
---

# MasterMind — Grill

The costly bugs come from assumptions you never checked. Grill your understanding *before* you commit code
to it (`~/.mastermind/engineering/core/rigor.md` → don't bluff; `~/.mastermind/engineering/core/agent-loop.md` → learn the stack first).

## Method

1. **State your assumptions out loud** — list what you believe about the API's behavior, signatures,
   return values, limits, versions, edge cases. Be specific ("`getFile` streams any size" — true?).
2. **Verify each against the primary source** — the official docs, the type definitions, or the actual
   source. Not a blog, not memory. Confirm ✓, correct ✗, or mark unknown ❓.
3. **Check the version** — behavior drifts; verify against the *installed* version, not the latest blog.
4. **Surface the unknowns** — what you still can't confirm becomes an explicit risk or a tiny spike to
   resolve (see `mastermind-prototype`), not a silent guess.

## Rule
No load-bearing assumption ships unverified. If it can't be confirmed from the source, treat it as unknown
and de-risk it — never assume it works.

## Output
A short assumptions ledger (claim → verified/corrected/unknown → source), and the corrected mental model
you'll build on.
