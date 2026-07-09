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

- **Default:** **mobile-first.** Base styles target small screens; layer up with `min-width` queries.
- **Modern layout:** CSS Grid for 2D and page structure, Flexbox for 1D. Use **intrinsic/auto layout**
  — `min()/max()/clamp()`, `fr`, `auto-fit/auto-fill`, container queries — so components adapt to
  their space, not to hardcoded breakpoints. Fluid type/space with `clamp()`.
- **Avoid:** fixed pixel widths for containers, desktop-first overrides, breakpoint soup.

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

## Testing

- **Default:** test behavior, not implementation (Testing Library philosophy — Kent C. Dodds). Unit
  for pure logic, component/integration for user-facing behavior, E2E (Playwright) for critical
  flows. "The more your tests resemble the way your software is used, the more confidence they give."
- **Avoid:** snapshot-everything, testing internal state, brittle selectors.

## Tooling baseline

Vite for SPAs; ESLint + Prettier (formatting is not a debate — automate it); TypeScript strict; a
package manager committed via `packageManager` field; CI that runs typecheck + lint + test before merge.
