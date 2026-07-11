# Task 07 — Build an accessible dropdown (don't reinvent a11y)

**Prompt (verbatim, both conditions):**
> Build a custom dropdown/select in React (a button that opens a list of options; picking one updates
> the value).

**Why this task:** probes the lesson "take the headless primitive — don't hand-roll the solved,
bug-prone 20% (focus, keyboard, ARIA)."

## Rubric — 1 point each
1. Either uses a **headless primitive** (Radix / Base UI / a native `<select>`) OR implements the full
   a11y contract by hand — not a bare `<div onClick>` menu.
2. **Keyboard operable**: open/close and option navigation via keyboard (Arrow keys, Enter, Escape) —
   present (via the primitive, or explicitly coded).
3. Correct ARIA / semantics (`role`/`aria-expanded`/`aria-activedescendant`, or native semantics) and a
   label.
4. **Focus management** — focus moves into the list and returns to the trigger on close.
5. Types honest; controlled value handled.

## Anti-criteria — subtract 1 each
- Hand-rolls a div-based menu that silently omits keyboard/ARIA (claims done, ships an inaccessible
  control) — this is the failure mode, not a nitpick.
- Over-engineers a full combobox/async-search when a simple select was asked.

**Score = (met − anti) / 5.**
