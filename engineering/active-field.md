# Active Field

MasterMind is **field-parameterized**: a universal core (how to think & work) plus a swappable
**field pack** (what to know & which tools) for the domain a project is in.

## Current field: **none yet**

- **Field pack:** _none_ — no field pack is shipped or active.
- **Level:** 0.

**Nothing is pre-baked, on purpose.** A pack built for someone else's stack is worse than no pack:
it carries dead weight, misses what actually matters, and quietly nudges the model toward defaults
the project never chose. So MasterMind ships the **scaffold** (`engineering/fields/_template/`), not
the content. Each project builds the field for its *own* stack, and owns it.

## Get a field — say `init`

On the first substantive work in a project, MasterMind:

1. **Detects the stack** from the project itself — `package.json`/deps, configs, file types,
   existing conventions. Free, and usually enough; it won't interrogate.
2. **Asks once, only if ambiguous** — *"What are we building, and on what stack?"* If the user isn't
   technical, it picks a sensible stack and says why.
3. **Builds the pack from `_template/`** — tuned to the real stack: its defaults, its actual
   pitfalls, its review rules. A **one-time** setup, then reused for every task, never per task.

## How to build a field

1. Create the pack at `engineering/fields/<name>/`. Two ways:
   - **Copy the template** — `cp -r engineering/fields/_template engineering/fields/<name>`, then fill
     in each file (the template has the shape + inline guidance).
   - **Bootstrap it** — `levelup --bootstrap <name>` researches and generates it from the template.
2. Point the "Current field" line above at the new pack, and set **Level:** to 1.
3. Regenerate the router from the source clone: `node scripts/build-router.mjs`.
4. The universal core (`engineering/core/*`) never changes between fields — it's field-agnostic.

> **This is how "swappable" is real, not a claim.** Any user, on any agent, copies `_template/` to
> stand up their own field (frontend, backend, mobile, data, game-dev, …) with exactly the stack
> notes and defaults they care about. Multiple packs can be active at once for full-stack work.

## Keep it lean — that's where the lift lives

A pack must fit **one real stack, not grow into a generic superset**. Tailoring **prunes as much as
it adds**; a pack that only accumulates is a bug. When the stack drifts, prune what no longer applies
and add what's missing (via `levelup`), or switch fields. The always-on core alone is a modest help;
the domain pack is the difference — but only while it stays lean and relevant.

## Onboarding — get ready cheaply

At the start of substantive work: detect the field from the project (free, usually enough); ask one
short question only when it's genuinely ambiguous; then build or load the matching pack. Never build a
pack silently, and never force a mismatched one. If `engineering/ROUTER.md` has routes, match the task
to a node's `route_when` and load **only** that node's file(s) — the router is a prebuilt index that
only ever speeds things up; when it's missing or a `hash` no longer matches, ignore it and fall back
to the field's `field.md` load-on-demand map.

## How MasterMind levels up (honest mechanics)

An LLM's weights are fixed — "leveling up" means **editing this knowledge base**, which changes
behavior durably across future sessions:

1. **Capture** — every correction and every real `code-reviewer` finding becomes a one-line entry in
   the active field's `lessons.md` (durable defaults go to `stack-defaults.md`). This compounds.
2. **Refresh** — `levelup --refresh` re-runs the curriculum research so the field tracks the ecosystem.
3. **Adapt to the user** — where the assistant has a memory, per-user preferences accumulate there;
   field packs hold *domain* truth, memory holds *user* truth.
4. **Mark the level** — bump the level above and log the change, so improvement is visible in git.

Fields belong to the project. An update to MasterMind never rewrites, refreshes, or retires a pack a
project has built.
