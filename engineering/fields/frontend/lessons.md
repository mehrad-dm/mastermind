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
- **In an established codebase, match the target app's sibling patterns *before* applying a generic
  purity/DRY rule — and confirm against the sibling, not just the skill.** A "violation" flagged by a
  purity checklist (API-type import, status→style mapping, DTO-typed props in `components/`) is often
  the house style; if the reference sibling app does the same thing, leave it. Fix only the genuine
  outlier. [A wallet refactor: 3 of 4 "violations" matched the sibling app's code; only a component
  using `useNavigate` + navigation was the real one.]
- **Router hooks and navigation never live in a `components/` file.** A component that calls
  `useNavigate`/computes a destination is doing a page's job — lift the navigation to the page and pass
  a ready view-model + `onActivate`. [Same refactor: a card component navigated itself; the page now
  builds `bannerSrc`/labels/`onActivate` and the card is pure.]
- **Amount/limit UI: derive, don't sync; guard one-time init with a ref, not a state-copy effect.**
  Compute rail/source-intersection bounds as derived values each render (a pure `resolve*Limits` util);
  seed the input once per package with a `ref`-gated effect, and keep a separate clamp effect so a
  provider switch re-pins the value into range. Copying config into state on every render freezes the
  control (unstable object identity + `increment: 0`). [A deposit amount picker froze this way.]
- **Minimum change beats DRY — don't extract a shared hook when the house style deliberately
  duplicates.** Two list pages each inline the same filter-store + infinite-query scaffolding *on
  purpose*; a `useWalletInfiniteList` abstraction across 2 intentionally-separate callers would diverge
  from the codebase and over-abstract. Verify the sibling before "DRYing." [The sibling app duplicates
  it too → left as-is.]
- **Pass the memoized array straight to the child; don't `[...spread]` it in JSX.** `options={[...opts]}`
  allocates a fresh array every render (new identity to the child) purely to satisfy a `readonly`→mutable
  type; type the prop mutable and forward the already-`useMemo`'d array instead. [Seen in an amount picker.]
- **Don't write speculative defensive code — list the "what about X?" scenarios and let the owner
  decide.** Normalize helpers with long alias tables, "ranges don't overlap" fallbacks, and enum cases
  for rails a market never uses are usually handling inputs that can't occur. Default to the minimal
  path that matches real API output; surface the edge cases as a review list, add only the ones the
  owner confirms. Mirror the lead dev's existing code, not a generic robustness instinct. [Owner
  explicitly wanted speculative normalize/fallback code flagged, not shipped.]
- **Kit-first, and learn the kit before using it.** In a repo with an in-house component kit, always
  reach for a kit component over hand-rolled markup — but read its source + storybook + an existing
  usage by the lead first, so you pass the right props and use it the intended way.
- **Keep config next to its code — no central "constants" dumping ground for routes.** Route
  definitions live in their own route files (like types live with the code that owns them); a shared
  `routes.ts`/`constants.ts` of paths is indirection the owner doesn't want.
- **One component per file; split multi-component files; never grow a giant component.** Readability +
  composition over a single sprawling render. [A house rule, reinforced by composition-patterns.]
- **No inline `style` — reach for sprinkles first, then a `.css.ts` `style`/`recipe`; kit components over
  raw HTML.** Ladder: sprinkles props (`justify="end"`, `sprinkles={{ flexWrap: "wrap", cursor: "pointer" }}`)
  → a colocated `.css.ts` class/recipe for anything long or with pseudo/variants (selected border, ellipsis
  truncation, absolute-positioned overlays) → inline `style` ONLY for genuinely data-driven values a static
  stylesheet can't express (e.g. `backgroundImage: url(pkg.bannerUrl)`). Swap raw `<div>` for the kit `Box`.
  [A no-inline-style pass: converted cursor/flexWrap/justify/ellipsis/sentinel/radio-border.]
- **Before converting an inline style, confirm the kit supports it — read the primitive.** Check the
  sprinkles property map actually lists the key (`cursor`, `flexWrap`, `position` do; arbitrary `1px` height
  does not → use a `.css.ts` `style`), and confirm the primitive you're switching to forwards what you need:
  if the kit's `Box` is `forwardRef`, an IntersectionObserver scroll-sentinel `<div ref={..}>` → `<Box ref={..}>`
  keeps working. [Verified `Box.tsx` + `properties.css.ts` before editing.]
- **When a new owner rule conflicts with sibling-parity, don't silently pick — surface the tradeoff.**
  Nearly every wallet inline style was verbatim from the sibling app. Applying "no inline styles" meant
  the app would diverge from its twin. Presented the parity table and let the owner choose; they took
  app-only divergence and kept the sibling isolated for the branch. [The "match the sibling" rule and a
  new "no inline styles" rule genuinely collide — the owner arbitrates, not a default.]
- **Validate Vanilla-Extract changes with a real build, not just `tsc`.** `.css.ts` `recipe`/`style` compile
  at build time; `tsc --noEmit` type-checks the call but won't run the VE compiler. Run `vite build` after
  adding/editing `.css.ts` to catch recipe/style misuse that type-checks but fails to compile. [`tsc` +
  eslint green, then `vite build` confirmed the new recipes actually compile.]
