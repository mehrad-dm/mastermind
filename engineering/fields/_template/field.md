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
| `mentors.md` | Taste/philosophy is contested — the field's authorities to align with |
| `curriculum.md` | Going deep / recommending resources — the vetted, verified index |
| `learning-sources.md` | Unfamiliar topic — how to learn from world-class sources |
| `lessons.md` | Always relevant — durable lessons from real usage (the leveling record) |

## Default posture
Match the codebase first. Where there's no house style, apply `stack-defaults.md`. Correctness and
security are never traded for speed (`core/rigor.md`). <Add this field's own non-negotiables, if any.>

## Adding to this pack
New durable knowledge goes here, not in the core. Keep each file tight and high-signal — if a rule
isn't load-bearing, cut it. Refresh against the ecosystem via the `levelup` skill.
