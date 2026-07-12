# Stack Defaults — choose the best, every time

Opinionated defaults so MasterMind reaches for the *right* tool instead of the average one. Format:
**Default → when to deviate → what to avoid.** Deviate only for a concrete, stated reason.

## Posture: adapt to the project — never impose a stack

These are **greenfield defaults and tie-breakers, not a stack to force on anyone.** Adding MasterMind to
a project must never mean rewriting it onto the tools below. Before choosing anything:

1. **Understand the architecture first.** Read the repo — `package.json`/lockfile, configs, folder
   shape, existing patterns — and map what's actually used *and how* (`core/agent-loop.md`). Understand
   the project before you touch it.
2. **A project that already has a stack wins — follow it.** Match its tools, versions, and conventions
   even where they differ from the defaults here; consistency beats preference and the project's choice
   is context you don't override (`core/rigor.md`). Propose a change only for a real, stated problem —
   and let the user decide.
3. **Greenfield or silent → recommend, don't dictate.** Choose the best fit for *this* project's real
   requirements — scale, team & skills, longevity, maintenance cost, performance — via the decision
   framework (`core/principles.md`) and the `tech-scout` agent for build-vs-buy. State the one-line why;
   escalate genuine product/business trade-offs (budget, hosting, hiring) to the user.
4. **The defaults below are what to reach for when nothing else decides** — a starting point for new
   work, never a mandate over a working project.

### Worked project stack — the client `the-app` (Turborepo monorepo)

A concrete, in-use stack this pack has worked in. When a task lands in this repo (or its sibling
`the-sibling-app`), reach for **these**, not the greenfield defaults above:

- **Components:** the internal **`@kit/ui`** component kit (`@kit/ui/components`) + **`@kit/mini-game-kit`**.
  Never hand-roll a primitive that the kit already ships; never build a custom component until the kit
  lacks it. Layout with the kit's `Stack`/`Paper`/`Box`, not ad-hoc flex divs.
- **Styling:** **Vanilla Extract** — `sprinkles(...)` for token-scale props and `*.css.ts` `style([...])`
  for the rest; 4px spacing base. Colors/type come from the kit's `vars.palette` + Typography recipe;
  add a missing token to the recipe rather than a magic hex.
- **Data/API:** **Orval-generated** typed clients + TanStack Query hooks re-exported from **`@kit/services/*`**
  (e.g. `@kit/services/payment`, `@kit/services/types`). Never hand-write a fetch; the OpenAPI contract is SSOT.
- **Routing:** **React Router v7** data routes with `lazy()` route modules under `src/pages/**/route.tsx`
  wired in `src/router/config/config.tsx`. Pages own `useNavigate`/`useSearchParams`.
- **Forms:** **React Hook Form + Zod** (`@hookform/resolvers`), one schema for the form and the boundary.
- **Client state:** **Zustand** stores (e.g. per-list `filterStore`) for genuinely shared UI state.
- **Layering (house rule):** **page → hook → component.** Pages fetch/navigate/mutate; hooks hold domain
  logic; `components/` folders are **presentational only** — no API/router/store/domain imports, view-model
  props + `onX` callbacks in. Match the sibling app (`the-sibling-app`) for the lead's conventions before inventing.
- **Toolchain:** pnpm workspaces + Turborepo; `pnpm type-check` (`tsc --noEmit`) and `eslint --max-warnings 0`
  are the gate.
- **House rules (owner preferences):** kit components over hand-rolled markup (read source + storybook +
  a lead usage first); routes defined inline in their route files, never a central path-constants file;
  one component per file, no giants; short/standard names; imports/exports match existing siblings; API
  wiring stays minimal and Orval/react-query-idiomatic like the lead's code; **flag speculative
  edge-case/normalize code for review instead of shipping it** — add only what the owner confirms.

## Design quality — distinctive, not generic

The default AI aesthetic is a tell: system/Inter fonts, a purple→blue gradient hero, everything
centered, emoji section markers, `rounded-lg` on everything. **Avoid it.** Ground the design in the
subject; pick a deliberate palette and type pairing, real hierarchy and spacing, and one considered
accent. Polished-but-restrained for tools/docs; a distinctive point of view for landing pages. (This is
the discipline the popular third-party `frontend-design` skill encodes, if you have it — but the rule
stands on its own: bake it in, don't ship the default look.)

## Language — TypeScript, always

- **Default:** TypeScript in `strict` mode. No exceptions for app code.
- **Rules:** No `any` — use `unknown` + narrowing. Prefer `type` for unions/composition, `interface`
  only for extendable object contracts. Model domains with **discriminated unions**; make illegal
  states unrepresentable. Infer types where possible; annotate public function boundaries explicitly.
  Prefer `as const`, `satisfies`, and template-literal types over casts. Casts (`as`) are a smell —
  justify each one.
- **Deeper patterns (Total TypeScript):** enable `noUncheckedIndexedAccess` — index access can be
  `undefined`, so the type must admit it. A generic type parameter must **connect two or more things**;
  if it appears only once, it's `any` in a costume — delete it. Use `satisfies` to check an object/config
  literal *without* widening its inferred type. **Derive, don't redeclare** — pull types from the single
  source of truth (`typeof value`, `ReturnType<>`, indexed access `T['field']`) so types can't drift from
  runtime. **Brand** domain ids (`type UserId = string & { readonly __brand: unique symbol }`) so a raw
  `string` can't be passed where an id is required.
- **Avoid:** enums (use `as const` objects / unions), `@ts-ignore` (use `@ts-expect-error` with a
  reason), non-null `!` in app logic.
- **Align with:** Matt Pocock's *Total TypeScript* patterns (see `mentors.md`).

## JavaScript

- **Default:** modern ES; immutable data and pure functions by default. Reason from the runtime (event
  loop micro/macro-tasks, closures, `this`, coercion, TDZ) — not cargo-cult rules.
- **Mental model (Abramov, *Just JavaScript*):** a variable points *at* a value, never at another
  variable; primitives are immutable, so **reassignment ≠ mutation**. Getting this exact kills most
  reference/closure/`this` bugs.
- **Avoid:** mutating shared state, `var`, floating promises, `==`.

## React

- **Default:** function components + hooks. Composition over configuration. Colocate state as low as
  it can live; lift only when genuinely shared.
- **State placement (Epic React; Abramov, *Before You memo()*):** colocate first. Before reaching for
  `memo`, try the two composition fixes — **move state down** into the component that actually uses it,
  and **lift slow content up as `children`** so it sits outside the re-rendering subtree. Group related
  transitions in one **`useReducer`** over many `useState`s. **Reset a subtree by changing its `key`**
  (remount), never by syncing state in an effect.
- **Perf debugging — symptom → cause:** a component that stutters *while typing/interacting* is almost
  always an expensive **sibling** re-rendering on each state change. **Fix the structure first** (move
  the state+input into a small child, or pass the expensive subtree as `children`) — `memo` /
  `useDeferredValue` / virtualization make the wasted render *cheaper*, not *gone*. Reach for those only
  after the structure is right, or for a genuinely huge DOM. (See `lessons.md`.)
- **Advanced composition** — compound components, prop getters, control props, provider patterns: use
  the installed **`vercel-composition-patterns`** skill rather than hand-rolling prop soup; don't
  restate its rules here.
- **State model:** server state ≠ client state. Don't put server data in `useState`. Derive, don't
  sync — if you're writing `useEffect` to copy one state into another, you have a derived value, not
  state.
- **Effects:** `useEffect` is for *synchronizing with external systems*, not for reacting to renders.
  Most effects are a bug or a missing derivation/event handler (per the React docs' "You Might Not
  Need an Effect"). Event logic goes in event handlers.
- **Keys, memo:** stable keys (never index for dynamic lists). Reach for `useMemo`/`useCallback`/
  `memo` only to fix a *measured* problem or to stabilize a dependency — not reflexively.
- **Data fetching:** use a server-state library (**TanStack Query**) or the framework's loader — never
  hand-rolled `useEffect` fetch waterfalls.
- **Client state:** when state is genuinely shared, default to **Zustand** (small, unopinionated; add
  `immer` for nested updates) — not Redux for greenfield, not Context for high-frequency updates. Keep
  *server* data in TanStack Query, never mirrored into the store.
- **Forms:** **React Hook Form + Zod** (`@hookform/resolvers`) — uncontrolled inputs for performance,
  and **one Zod schema validates the form *and* the API boundary** (SSOT, parse-don't-trust).
- **Routing:** on Next.js use its router; for a **Vite SPA, React Router** (v7 data routers — loaders,
  lazy routes, error boundaries). Code-split at the route.
- **Animation:** **Motion** (Framer Motion) for gestures/springs, CSS transitions for simple state,
  Lottie/Rive for designed vector — see **Animation & motion** below for the craft rules.
- **Align with:** Kent C. Dodds (testing, composition, colocation), Dan Abramov (mental model, effects).
- **Avoid:** prop-drilling past ~2 levels (compose or context), giant "god" components, `useEffect`
  for derived state, premature global state.

## Next.js

- **Default when:** you need SSR/SSG/streaming, SEO, file-based routing, edge/serverless, or a
  full-stack React app. App Router + React Server Components for new work.
- **Rules:** Server Components by default; add `"use client"` only at the leaf that needs
  interactivity. Fetch on the server; stream with Suspense. Respect the client/server boundary — keep
  secrets and heavy deps server-side.
- **Don't reach for it when:** a static SPA (Vite + React) fully covers the need. Don't adopt a
  framework's complexity for features you won't use.

## Styling — pick by project scope

There is no single winner; choose by constraints. Ranked defaults:

- **Tailwind CSS** — **default for most app UI.** Fast, consistent, great with component systems.
  Best when velocity + a shared scale matter and the team is comfortable with utility classes.
- **Vanilla Extract** — when you want **type-safe, zero-runtime CSS-in-TS** with a design-token
  system and static extraction (great for design systems / libraries; SSR-safe, no runtime cost).
- **Panda CSS** — when you want Tailwind-like DX **as typed CSS-in-JS with build-time extraction** and
  recipes/variants tied to tokens. A strong middle ground for design systems.
- **StyleX** — atomic, compile-time, type-safe styling built for very large apps (Meta-scale
  determinism, style-merging guarantees, dedup). Reach for it at big-codebase scale; overkill for most.
- **CSS Modules / plain CSS** — when you want zero deps, full control, and no abstraction tax.
- **Runtime CSS-in-JS (styled-components/emotion)** — only in legacy contexts or when dynamic runtime
  theming truly requires it; avoid for new SSR apps (runtime cost, RSC friction).
- **Rule:** whatever the tool, style through **design tokens** (spacing, color, type scales) — never
  magic numbers scattered in components. SSOT for design decisions.

## Animation & motion

Motion is polish that compounds — or noise that annoys. The non-obvious defaults (Emil Kowalski,
animations.dev). The `web-animations` skill carries the build/audit workflow; these are the rules:

- **Animate only `transform` and `opacity`** — GPU-composited, no layout/paint. **Never** animate
  `width/height/margin/padding/top/left` (layout thrash). Framer's `x`/`y` run on the main thread →
  prefer `transform: translateX()` under load.
- **Duration <300ms for UI**, scaled to weight: press 100–160ms · tooltip 125–200ms · dropdown
  150–250ms · modal/drawer 200–500ms. A 180ms dropdown feels *more* responsive than a 400ms one.
- **Easing:** `ease-out` for enter/exit (immediate), `ease-in-out` for on-screen moves, `ease` for
  hover/color, `linear` for continuous. **Never `ease-in` on UI** — it feels sluggish at the same
  duration. Curves: `--ease-out: cubic-bezier(0.23,1,0.32,1)`, `--ease-drawer: cubic-bezier(0.32,0.72,0,1)`.
- **Don't animate high-frequency or keyboard-initiated actions** (command palette, shortcuts, list nav
  done 100×/day) — motion there is friction. Reserve it for occasional (modal/toast) and first-run moments.
- **Springs for interruptible gestures** (drag — retains velocity), **tweens for fixed transitions.**
  Keep bounce subtle (0.1–0.3); Apple-style `{ type:'spring', duration:0.5, bounce:0.2 }`.
- **Interruptible → CSS transitions, not keyframes** (keyframes restart from 0; transitions retarget).
- **Enter from `scale(0.95)+opacity:0`**, never `scale(0)` (looks broken). Press: `scale(0.97)` on
  `:active`. Popover `transform-origin` = trigger location; modals stay centered. Prefer
  `@starting-style` over a `mounted`-state effect for entry.
- **A11y (non-negotiable):** honor `@media (prefers-reduced-motion: reduce)` (drop transform motion,
  keep opacity/color); gate `:hover` transforms behind `@media (hover:hover) and (pointer:fine)`.

## Components — primitives vs kits

- **Default: headless primitives + your own styling.** **Radix** or **Base UI** (accessible,
  unstyled behavior) styled with your tokens — you own the look, inherit the hard 20% (focus, keyboard,
  ARIA). **shadcn/ui** is this exact stack pre-assembled (Radix + Tailwind + `cva`/`cn`), not an
  alternative to it (see `lessons.md`).
- **Batteries-included kits (Ant Design, MUI):** reach for one when you want a full component set fast
  and can live with its design language and weight (admin panels, internal tools). Don't fight its
  theming to force a bespoke brand — that's when headless wins.
- **Never hand-roll** an interactive component (dialog, select, combobox, toast) from raw `div`s — you
  will get a11y wrong. Take the primitive.

## Responsive & layout

The consensus every serious design system converges on (Material, Tailwind, Bootstrap): mobile-first,
simple well-supported primitives, and any newer feature verified safe for the project's target browsers.

- **Default: mobile-first.** Base styles target the smallest screen; layer up with `min-width`
  queries. Leaner CSS, and it forces you to prioritize content.
- **Two axes of "responsive" — don't conflate them.** **Media queries** handle *page-level* structure
  (overall grid, viewport-driven type); **container queries** (`@container`) handle *component-level*
  adaptation — a card sizes to its slot, so the same component works in a hero or a narrow sidebar.
- **Reach for the boring, battle-tested primitives first.** Flexbox for 1D, CSS Grid for 2D and page
  structure, with plain breakpoints and `fr`/percentages. These cover the large majority of layouts,
  read clearly, and behave predictably on every browser and device.
- **Use `clamp()`, `minmax()`, `min()/max()`, `auto-fit/auto-fill` sparingly — only where a plain
  approach genuinely can't do the job**, never reflexively. They solve real problems (a card grid
  with no breakpoints, a truly fluid hero) but add cognitive cost and carry footguns: `minmax(250px,
  1fr)` overflows below 250px (guard: `minmax(min(250px, 100%), 1fr)`), and `clamp()` fluid type must
  include a `rem` term or it fails WCAG 1.4.4 zoom (pure `vw` doesn't scale on zoom). Prefer two clear
  breakpoints over one clever formula the next reader has to decode.
- **Verify uncommon CSS before shipping it.** For any newer or less-common property/function, check
  **caniuse.com** (or Baseline) against the project's target browsers/devices — confirm it's supported
  or degrades safely. Progressively enhance behind `@supports` with a sensible fallback (usually the
  single-column mobile layout). **Feature-detect, never device-sniff.** Prefer logical properties for
  direction-safety (see RTL below).
- **Avoid:** fixed pixel widths for containers, desktop-first overrides, breakpoint soup,
  device-specific breakpoints (`iPhone`-width hacks), UA sniffing, and clever fluid math where two
  breakpoints would read clearer.

## HTML & accessibility

- **Default:** semantic HTML first — the right element (`button`, `nav`, `label`, `dialog`) before any
  ARIA. Accessibility is not optional; it's correctness. Keyboard-operable, labeled, sufficient
  contrast, focus management.
- **Avoid:** `div` soup, click handlers on non-interactive elements, ARIA that re-implements a native
  element badly.

## RTL / i18n — **decide per project, do not assume**

RTL and localization depend entirely on the **audience**. Determine scope first, then commit:

- **Ship RTL** when the audience includes RTL languages (Persian, Arabic, Hebrew). Then: use CSS
  **logical properties** (`margin-inline-start`, `inset-inline`, `padding-block`) everywhere — never
  physical `left/right` — set `dir` at the root, and test both directions.
- **Skip RTL** for LTR-only audiences — don't pay its tax for no user. Still prefer logical properties
  as a cheap hedge, but don't build the direction-switching machinery.
- Never hardcode this either way; read the project's target market and state the decision.

## Data, API & networking

- **Default:** typed client, schema-validated boundaries (**Zod** at the edges — parse, don't trust).
  REST for CRUD; consider tRPC for TS-fullstack type-safety; GraphQL only when the client genuinely
  needs flexible, aggregated queries.
- **Generate from the contract, don't hand-write it.** When the backend publishes an OpenAPI schema,
  codegen the typed client + TanStack Query hooks (**orval**, or **openapi-typescript**) so the API
  contract stays the single source of truth and drift is impossible. `axios`/`fetch` under the hood.
- **Rules:** treat loading/error/empty as first-class states. Kill request waterfalls (parallelize,
  prefetch, colocate). Cache deliberately (HTTP + TanStack Query); debounce user-driven requests;
  retry with backoff on idempotent calls.
- **Avoid:** unvalidated external data, N+1 client requests, storing secrets client-side.

## Performance & optimization

The bar is **Core Web Vitals**, judged at the **75th percentile** of real users across mobile and
desktop (field data via CrUX — not just a green lab Lighthouse score). Measure first, then fix the
metric that's actually failing; premature perf work is complexity with no payoff (`core/mindset.md`).

- **The three metrics + targets:** **LCP** (loading) ≤ **2.5s** · **INP** (responsiveness — replaced
  FID in 2024) ≤ **200ms** · **CLS** (visual stability) ≤ **0.1**. Lab-test with Lighthouse / DevTools;
  confirm with field data.
- **LCP — it's usually the hero image, and usually *discovery*, not download.** ~73% of mobile pages
  have an image LCP, and most delay is the browser finding/prioritizing it late. Give the LCP image
  `fetchpriority="high"`, `preload` it, never lazy-load it, and size it right. Render the main content
  server-side/streamed so it isn't gated on client JS.
- **INP — keep the main thread free.** Break up long tasks (>50ms blocks input), yield to the main
  thread, and **ship less JavaScript** — the cheapest INP win. Code-split, avoid heavy synchronous work
  in event handlers, cut hydration cost (RSC / islands).
- **CLS — reserve space up front.** Always set `width`/`height` or `aspect-ratio` on images/media,
  reserve space for ads/embeds/late content, use `font-display: swap` **with a metric-matched fallback**
  (e.g. `next/font`, `size-adjust`), and never inject content above existing content.
- **Images — usually the biggest single win.** Modern formats (**AVIF → WebP → fallback** via
  `<picture>`), responsive `srcset`/`sizes`, `loading="lazy"` below the fold, and correct dimensions —
  never ship a 2000px image into a 400px slot.
- **Deliver less, sooner.** Code-split by route, tree-shake, `defer`/`async` non-critical JS,
  `preconnect` to critical origins, subset + `preload` fonts. Keep pages **bfcache-eligible** (no
  `unload` handlers, no `Cache-Control: no-store`) so back/forward is instant. Consider the
  **Speculation Rules API** to prefetch/prerender the likely next page.
- **Cache deliberately.** Immutable hashed assets with long `max-age`; a CDN for static delivery;
  server-state caching (TanStack Query) over refetching. (See Data, API & networking above.)
- **Adaptive loading (Addy Osmani) — meet the user's device & network, don't assume yours.** On
  constrained clients serve *less*: read `navigator.connection.effectiveType` / `saveData` (Data Saver),
  `navigator.deviceMemory` (RAM), and `navigator.hardwareConcurrency` (CPU), then adapt — lighter or
  fewer images/video, deferred or skipped non-critical JS, disabled heavy features. In React,
  `react-adaptive-hooks` (`useNetworkStatus` · `useSaveData` · `useMemoryStatus` ·
  `useHardwareConcurrency`); also honor the `Save-Data` request header and `prefers-reduced-data`. Data
  Saver alone cuts image bytes ~50–80%. Your fast laptop is not your user's phone.

## Testing

**First: does this project even test?** Testing/TDD is a project choice — **confirm before adding a
suite, a framework, or TDD to a project that has none** (`core/rigor.md`). Match the repo: follow its
testing conventions where they exist; where they don't, offer tests as a suggestion, don't impose them.
Either way, always **verify the change works by exercising the real flow** — that part isn't optional.
The defaults below apply *when* the project tests:

- **Default:** test behavior, not implementation (Testing Library philosophy — Kent C. Dodds). Unit
  for pure logic, component/integration for user-facing behavior, E2E (Playwright) for critical
  flows. "The more your tests resemble the way your software is used, the more confidence they give."
- **Avoid:** snapshot-everything, testing internal state, brittle selectors.

## Tooling baseline

Vite for SPAs; ESLint + Prettier (formatting is not a debate — automate it); TypeScript strict; a
package manager committed via `packageManager` field; CI that runs typecheck + lint (+ tests where the
project has them) before merge.

- **Monorepos:** for multiple apps + shared packages, **Turborepo + pnpm workspaces** — cached,
  parallel task pipelines; share `ui`, `config`, `types` as internal packages.
- **Git hygiene:** **Husky + lint-staged** (lint/format only staged files pre-commit) and **commitlint**
  (conventional commits) — keep the gate fast and the history clean.
- **PWA:** **vite-plugin-pwa + Workbox** when the app must be installable or work offline; precache the
  shell, choose a deliberate runtime-caching strategy per route.
- **Error monitoring:** ship a reporter (**Sentry**) with source maps and release tracking — unobserved
  production errors are bugs you've decided not to find.
