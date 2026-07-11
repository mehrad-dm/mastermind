# Lessons — Frontend (the leveling record)

Durable lessons learned from real usage and `code-reviewer` findings. Each is a one-line rule with
the "why" in brackets. New lessons are appended by the `mastermind-levelup` skill. When a lesson is
general enough to be a default, also promote it into `stack-defaults.md`.

- **Sliding indicators (segmented control, tabs underline) must measure real layout, not assume equal
  segment widths.** Drive the thumb from the active item's `offsetLeft`/`offsetWidth` + a
  `ResizeObserver`; `calc(100%/N)` + `translateX(index*100%)` only works when every segment is
  identical width — which is not the default for content-sized segments. [Caught by a `code-reviewer`
  pass on a design-system kit — invisible to the author's eye, obvious in a fresh review.]
- **Prefer a Radix/headless primitive over hand-rolling any component with real interaction**
  (dialog, switch, toggle-group, popover, select). You inherit focus management, keyboard nav, and
  ARIA — the most bug-prone 20% — for free, and still own the styling. [a11y is never on the chopping
  block; don't reinvent the solved part.]
- **Style a design token as an RGB channel triplet** (`--accent: 255 107 53`) and expose it to
  Tailwind as `rgb(var(--accent) / <alpha-value>)`, so one source drives utilities, opacity modifiers
  (`bg-accent/10`), and raw `var()` alike. Avoids the same brand color drifting across config, CSS,
  and JS. [SSOT.]
- **shadcn/ui *is* Radix + Tailwind + `cn`/`cva` — not an alternative to Radix.** Its interactive
  components wrap Radix primitives; "moving to shadcn" ≠ removing Radix. Removing Radix means leaving
  shadcn and hand-rolling a11y. [Clears the most common shadcn misconception.]
- **Ship a global `prefers-reduced-motion` reset** (`animation/transition-duration: .01ms !important`)
  and short-circuit JS animations (rAF count-ups) to the final value. Every animated primitive must
  honor it. [a11y non-negotiable; the class of user this actually harms.]
- **Testing Radix in jsdom needs polyfills:** stub `ResizeObserver`, `matchMedia`, and pointer-capture
  (`hasPointerCapture`/`setPointerCapture`) + `scrollIntoView` in the Vitest setup, and query Radix
  ToggleGroup items by `role="radio"`, not `"button"`. [Otherwise interactive-component tests throw.]
- **A component that lags *while typing/interacting* is almost always an unnecessary re-render of an
  expensive *sibling* — fix the STRUCTURE first, before `memo`/`useDeferredValue`/virtualization.** Move
  the state + input into a small child so the state change only re-renders that child, or pass the
  expensive subtree as `children` (a stable element React skips). `memo`/`useDeferredValue` make the
  wasted render *cheaper*; the structural fix makes it *not happen*. Reach for deferring/virtualization
  only after the structure is right (or for genuinely huge DOM). [Caught by eval task 03: the default
  answer — even with MasterMind — was memo/deferred, not the root-cause structural fix. Fix the cause.]
