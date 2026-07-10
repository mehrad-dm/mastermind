# Stack Defaults — choose the best, every time

Opinionated defaults so MasterMind reaches for the *right* tool instead of the average one. Format:
**Default → when to deviate → what to avoid.** Deviate only for a concrete, stated reason.

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
- **Avoid:** enums (use `as const` objects / unions), `@ts-ignore` (use `@ts-expect-error` with a
  reason), non-null `!` in app logic.
- **Align with:** Matt Pocock's *Total TypeScript* patterns (see `mentors.md`).

## JavaScript

- **Default:** modern ES (modules, `const`, arrow fns, optional chaining, `async/await`). Immutable
  data by default; pure functions where practical.
- **Know under the hood:** the event loop (macro/microtasks), closures, prototype chain, `this`
  binding, reference vs value, hoisting, coercion. Reason from these, not from cargo-cult rules.
- **Avoid:** mutation of shared state, `var`, floating promises, `==`.

## React

- **Default:** function components + hooks. Composition over configuration. Colocate state as low as
  it can live; lift only when genuinely shared.
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
- **Rules:** handle loading/error/empty states as first-class. Avoid request waterfalls — parallelize,
  prefetch, colocate data needs. Cache deliberately (HTTP caching, TanStack Query). Debounce/throttle
  user-driven requests. Know the network model: HTTP methods & status codes, idempotency, CORS,
  auth (JWT/session/OAuth), REST vs RPC, latency vs bandwidth, retries/backoff.
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
