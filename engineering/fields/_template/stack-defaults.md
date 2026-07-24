---
field: <field>
route_when: [stack, tool, library, default, choose, framework, testing, tooling]
---

# Stack Defaults — choose the best, every time

Opinionated defaults so MasterMind reaches for the *right* tool instead of the average one. Format:
**Default → when to deviate → what to avoid.** Deviate only for a concrete, stated reason.

> **How to fill this in.** One `##` section per meaningful decision area in your field (language,
> framework, data layer, testing, tooling, …). Under each, write the *non-obvious* default and *why* —
> not what a frontier model already knows. Judgment, not inventory: if a rule isn't load-bearing, cut it.

## Posture: adapt to the project — never impose a stack

These are **greenfield defaults and tie-breakers, not a stack to force on anyone.**

1. **Understand the architecture first** (`core/agent-loop.md`) — read the repo and map what's used *and how*.
2. **A project that already has a stack wins — follow it** (`core/rigor.md`), even where it differs here.
3. **Greenfield or silent → recommend, don't dictate** — best fit for *this* project's real requirements
   (scale, team, longevity, maintenance, performance) via `core/principles.md` and the `tech-scout` agent.
4. **The defaults below are the tie-breaker when nothing else decides** — never a mandate.

## <Decision area, e.g. Language>
- **Default:** <the opinionated pick>.
- **When to deviate:** <the concrete conditions>.
- **Avoid:** <the common trap and why>.

## <Decision area, e.g. Framework / Data / Testing / Tooling …>
- **Default:** …
- **When to deviate:** …
- **Avoid:** …

<!-- Add as many sections as the field genuinely needs. Keep it lean: one real stack, not a superset. -->
