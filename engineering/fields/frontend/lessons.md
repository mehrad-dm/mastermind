---
field: frontend
route_when: [lesson, gotcha, pattern, review-finding, house-style]
---

# Lessons — Frontend (the leveling record)

Durable lessons learned from real usage and `code-reviewer` findings. Each is a one-line rule with
the "why" in brackets. New lessons are appended by the `levelup` skill. When a lesson is
general enough to be a default, also promote it into `stack-defaults.md`.

**Pruning — a pack that only grows is a bug.** `levelup` reviews this file whenever it runs a refresh,
and always before appending once the list passes **40 lessons**. Delete a lesson when any of these is
true: (1) it has been promoted into `stack-defaults.md` — the default is now the rule, and the lesson is
a duplicate; (2) it is about a library, version, or tool this field no longer uses; (3) the framework
fixed it upstream, so the workaround is now wrong advice; (4) a newer lesson supersedes it — merge the
two, keep one. Deleting is the default when a lesson is merely *true but never load-bearing*; keep only
what would change a decision.

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
- **Read the per-component doc before using a kit component — and if there's none, adding it is
  high-leverage.** Well-run kits colocate a usage doc (a `README.md` beside each component) with its
  props, variants, and the **non-obvious rules** — recommended icon size per button size, which state
  hides what, the default element `type`, where styling is configured. Read it first: cheaper and more
  accurate than reading source, and it's the SSOT for *intended* usage. If a kit has none, generating
  per-component usage docs makes every future AI (and human) use it correctly by default — see the
  `explain` skill. [The highest-signal part is the gotchas, not the prop list.]
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
- **Constants: colocate unless genuinely shared.** Single-consumer timing values, asset maps, and stable
  literals belong in the file that owns them — not a feature `constants.ts` that exists for one export.
  Reserve a shared `constants.ts` for search params/domain keys used by 2+ modules. [A refactor deleted
  three constants files that each had exactly one consumer.]
- **Vanilla Extract composition: `style([sprinkles({...}), { ... }])`.** Token props go through
  `sprinkles()`; the plain style block carries only what tokens can't express (pseudo-selectors, arbitrary
  px, transforms, `flexGrow`). A pure-token class can be `sprinkles({...})` alone. Kit layout props first.
- **Prefer the kit's semantic layout props over raw token props.** Where a kit primitive exposes an
  intent-named prop (`spacing` for gap, `fullWidth` for width), use it instead of the equivalent
  `sprinkles` prop — same token, clearer intent. Check the recipe: not every primitive has one. [Verify
  against the kit source before assuming a prop exists.]
- **No `let` reassignment for derived values — use a util with an early `return`.** Prefer
  `const x = getFoo(a, b)` where `getFoo` branches with `if` + `return`. And when the value is used
  **once** (e.g. a className), call the util inline in JSX rather than binding an intermediate `const`.
  Applies to className resolution, view state, any derived branch.
- **No nested ternary for className/logic — extract a util or use if/else.** Matches ESLint
  `no-nested-ternary`; a nested ternary in JSX is where branching logic goes to die.
- **No single-use layout constants in `.css.ts`.** If a named constant is used once to compute a value,
  inline the number at the use site. Reserve named constants for 2+ consumers or genuine domain meaning.
- **Animated list keys: key by position, not by value.** For rolling/animated digits, `key={len - 1 - i}`
  keeps the animating component mounted as the value changes; `key={`${value}-${i}`}` remounts it and
  breaks the animation direction. Key by *slot*, not by content, whenever the content animates.
- **A "select the default" effect must run only while the selection is still `null`.** An effect that
  assigns `options[0]` on every refetch stomps the user's choice the moment the query refreshes. Gate it
  on `selected === null` so it initialises once instead of re-asserting the default forever.

## Distilled patterns by area (from production frontend work)

**Routing (React Router)**

- **Route-entry files are thin delegates — no logic in `route.tsx`.** The route file is a one-line
  hand-off to the feature module/container; URL params, fetching, and flow logic live in the module. Keeps
  routing a lookup table and stops `route.tsx` becoming a second home for logic.
- **Model multi-step flows as nested routes, not a local `step` variable.** A shared layout + step
  indicator + `<Outlet>`. Back/forward, deep-linking, and refresh work for free; each step stays small and
  testable. A single component juggling `step` breaks the browser's navigation model.
- **Bookmarkable state → URL search params; transient UI state → a small external store; write
  query-state with `replace: true`.** Shareable/reloadable state (active tab, selected id) belongs in the
  URL (SSOT); an open/applied filter sheet is UI-only — keep it in `useSyncExternalStore`. `replace:true`
  avoids spamming history on every filter change.

**TypeScript**

- **End a union `switch` with an exhaustive `never` guard** — `default: { const _: never = value; return _ }`.
  Adding a new union member becomes a compile error at every switch that forgot it, instead of a silent
  runtime fallthrough.
- **Colocate a union's type + `is*` guard + `resolve*(raw)` fallback next to its `as const` literal.** One
  home for "what are the valid values, and what happens for an invalid one" — parse external strings (URL
  params, API enums) into the union there, instead of scattered inline `?? "default"` casts.

**Forms (React Hook Form + Zod)**

- **Three-layer validation: schema → pure `get*Error(ctx)` returning an error-*code* → `get*ErrorMessage(code)`
  exhaustive switch.** Business rules stay pure and unit-testable, copy stays in one localizable place, and
  the exhaustive switch guarantees every code has a message. Don't mix rule logic and display strings in the schema.
- **When validation limits are server-driven, build the schema with a memoized factory** —
  `useMemo(() => createSchema(limits), [limits])` — not hardcoded bounds, so validation can't drift from
  the real (server) limits.

**Data (TanStack Query)**

- **Transform DTOs into view models in the query's `select`, not the component body.** The component gets
  ready-to-render data; the mapping is memoized by the cache and doesn't re-run on unrelated renders.
- **Every filter dimension must be in the query key.** [correctness — TanStack Query "Query Keys" docs: a
  key must include every input the query depends on. Reusing one key across filter values serves
  stale/wrong-filter data or flashes the previous filter's results.]
- **Toast in `onError` and stop — never re-throw.** Use a shared API-error-message extractor; put the
  generic "a request failed" toast in the query client / HTTP interceptor with a per-request opt-out for
  screens that handle their own errors. Re-throwing after toasting double-handles and leaks unhandled rejections.

**Architecture**

- **Route every async screen's loading/error/empty states through one shared boundary component**
  (`<Boundary isLoading isError error>…`), not per-screen `if (isLoading)…if (isError)…`. Uniform UX and one
  place to evolve it; hand-rolled branches drift and miss states.
- **Isolate DTO→view-model mapping in a pure `mappers/` layer, out of components.** Mapping is the churny,
  testable part; isolating it keeps components presentational and lets the API shape change in one place.
- **One shared realtime listener per channel key, bridged into the query cache via `setQueryData` — never
  one subscription per component.** [correctness — per-component listeners leak connections and create
  divergent copies of the same data; a single keyed subscription written into server-state cache keeps one
  source of truth.]

**Monorepo / tooling**

- **Import shared/generated packages only through their public entry — never deep `dist/`/`generated/`
  paths.** Preserves the package boundary so internals (and regenerated files) can change freely without
  breaking consumers.
- **In a multi-stack monorepo, follow the stack local to the file; don't import primitives across stacks.**
  Each stack has its own token/layout model; cross-importing produces inconsistent styling and bundle bloat.
  ("Adapt to the project" applied at sub-project granularity.)
- **Before changing a difference between two parallel apps, classify it: style drift or product truth.**
  Designate one app as the style reference and read it first; fix drift *toward* it, but preserve a
  deliberate product difference. Stops "fixing" a real product divergence into false uniformity.
