---
name: improve-ui
field: frontend
route_when: [design, ui, ux, design-system, consistency, tokens, audit-ui, visual, layout, spacing]
description: Audit a UI against its OWN design language — read the repo's design context (DESIGN.md, design tokens, CSS/theme, the shared component kit) and find where the interface breaks its own rules (off-token color/spacing, one-off components, inconsistent states, a11y gaps vs the project's standard), then write a prioritized fix plan. Proposes, never auto-applies. Use for a design/visual-consistency pass on frontend UI. Frontend field skill (draws on the pack's design intelligence).
---

# Improve UI — audit an interface against its own design language

The most common UI problem isn't ugliness — it's **inconsistency with the system the project already
has.** This skill checks a UI against **its own rules** (not a generic ideal), finds where it drifts, and
writes a fix plan. It's the design-consistency counterpart to `code-reviewer` (which checks *code*
correctness); the two are parallel audits, different lenses.

> **The project's own design language is the standard — never your taste.** Draw on the pack's design
> intelligence (`ui-ux-pro-max`) for *what good looks like*, but the repo's system wins: match its
> language, don't impose a generic aesthetic.

## Method

1. **Read the design context (the rules).** `DESIGN.md`/design docs, the **design tokens** (color,
   spacing, radius, type scale, shadow), the theme/global CSS, and the **shared component library/kit**.
   If there's no written system, **infer the de-facto one** from the tokens + the most-used components.
2. **Scope it.** Audit what the user points at (a screen, a flow, a component) by default; scan the whole
   UI only when asked. Don't burn tokens auditing everything when they named one thing.
3. **Find where the UI breaks its own rules:**
   - **Off-system values** — magic hex/px instead of tokens; one-off spacing/radius/shadow.
   - **Reinvented components** — hand-rolled markup where a kit component exists; near-duplicate components.
   - **Inconsistent states** — hover/focus/disabled/loading/empty handled differently across the app.
   - **Inconsistent density/rhythm** — spacing, alignment, and type hierarchy that fight the scale.
   - **A11y gaps vs the project's own standard** — missing focus rings, contrast, labels the system expects.
4. **Consistency vs. deliberate exception** (same discipline as convention/correctness): a divergence is
   either **drift** (fix toward the system) or an **intentional exception** (leave it). When unsure, ask —
   don't "fix" a deliberate choice.
5. **Write the fix plan — propose, never auto-apply.** A prioritized list: *violation → where (`file:line`)
   → the on-system fix*, grouped by impact (systemic first, one-offs last). Hand real design defects that
   are also code (missing focus management) to `code-reviewer`.

## Output
A prioritized **fix plan** (not applied edits): what breaks the system, where, and the on-system fix —
plus a one-line "state of the system" (is there a real design language here, or does one need writing?).

## Gotchas
- **Match the system, don't impose one.** If the repo's radius is sharp and dense, don't "improve" it to
  soft and airy — that's taste, not consistency.
- **A one-off may be intentional.** Flag it as a question, not a defect, until confirmed.
- **No `DESIGN.md`? The tokens + top components *are* the de-facto system** — audit against that, and note
  that writing it down would help (a job for `explain`/a design doc).
- **Design intelligence is the reference, the project is the law.** Use `ui-ux-pro-max` for *what good
  looks like*; use the repo for *what "consistent" means here*.
