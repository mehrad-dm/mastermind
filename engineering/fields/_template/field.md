# Field Pack — <FIELD NAME>

> **Template.** Copy this whole `_template/` directory to `fields/<your-field>/`, fill in the angle-
> brackets, and point `active-field.md` at it. The universal `core/` never changes between fields — a
> pack only supplies *what to know and which tools to reach for* in this domain. Delete this quote block
> when done. (Frontend is the reference implementation — read `fields/frontend/` for the bar.)

The domain knowledge MasterMind loads when its active field is **<FIELD NAME>**. The universal core
(`engineering/core/*`) supplies *how to think and work*; this pack supplies *what to know and which
tools to reach for*.

## Scope
<One or two lines: what this field covers — languages, frameworks, the sub-areas an engineer here needs.>

## Pack contents (load on demand)

| File | Load when |
| --- | --- |
| `stack-defaults.md` | Choosing a tool/lib/pattern — the opinionated "choose the best" defaults |
| `audit-rules.md` | Reviewing a diff — the framework-specific defect checks `code-reviewer` loads |
| `mentors.md` | Taste/philosophy is contested — the field's authorities to align with |
| `curriculum.md` | Going deep / recommending resources — the vetted, verified index |
| `learning-sources.md` | Unfamiliar topic — how to learn from world-class sources |
| `lessons.md` | Always relevant — durable lessons from real usage (the leveling record) |

Every file above except this one carries `route_when` frontmatter — that is what puts it in the router
(`scripts/build-router.mjs`). **Keep the frontmatter and retag it for your field**; a file without
`route_when` is invisible to routing, and `check-integrity.mjs` will fail the build if one is missing.

## Default posture
Match the codebase first. Where there's no house style, apply `stack-defaults.md`. Correctness and
security are never traded for speed (`core/rigor.md`). <Add this field's own non-negotiables, if any.>

## Keep it lean & stack-specific (true of every pack)
New durable knowledge goes here, not in the core. Two rules keep a pack sharp — a lean, *relevant* pack
is what produces the quality lift; a bloated or mismatched one erodes it:

- **Fit ONE real stack, not a superset.** Tailor to the stack actually in use — **prune what doesn't
  apply** (another framework's rules) and **add what's missing**. A pack that tries to cover every
  variant helps no one and dilutes the signal. If the user's stack differs from what this pack assumes,
  reshape the pack (via `levelup`), don't force the mismatch.
- **Prune as much as you add.** Keep each file tight and load-bearing — if a rule isn't load-bearing,
  cut it. **A pack that only grows is a bug.** Refresh *and* prune against the ecosystem via `levelup`.
