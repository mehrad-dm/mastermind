# Active Field

MasterMind is **field-parameterized**: a universal core (how to think & work) plus a swappable
**field pack** (what to know & which tools) for the domain the user is working in.

## Current field: **Frontend Engineering** — level 6

- **Field pack:** `engineering/fields/frontend/` (see its `field.md` manifest).
- **Level:** 6. Bumped by the `levelup` skill as lessons accumulate and standards are
  refreshed. See the field pack's `lessons.md` for what's been learned so far.

### Level history

- **level 6** (2026-07-12) — added a **web-animation & motion** capability: vendored Emil Kowalski's
  animation playbook complete (MIT — `emilkowalski/skills`, animations.dev; creator of Sonner + Vaul)
  into the pack as **`web-animations.md`** (decision framework, springs, component principles, CSS
  transform/clip-path, gestures, performance, a11y, the Sonner principles, review checklist), added Emil
  as the **Motion & animation** mentor and animations.dev to `learning-sources.md`, and wired the file
  into `field.md`. It lives entirely in the frontend pack (loaded only for motion work), not as a global
  skill. Also **genericized the worked-stack notes** — the concrete profile and lessons stay, but all
  project/product/person names were stripped so the pack carries patterns, not identities.
- **level 5** (2026-07-12) — captured a **worked stack profile** (a Turborepo monorepo with an in-house
  component kit) in `stack-defaults.md` (Vanilla Extract sprinkles/tokens, Orval + TanStack Query service
  packages, React Router v7, RHF + Zod, pnpm/Turborepo, page→hook→component layering + ui-only
  `components/`). Added refactor lessons: **match the target app's sibling patterns over a generic rule**,
  router/navigation never in `components/`, derive-don't-sync amount state with a ref-guarded one-time
  init, and *minimum change beats DRY* (don't extract a shared hook when the house style deliberately
  duplicates). Sourced while doing a behavior-preserving structural refactor of a wallet flow. Extended in
  the same refactor with a **styling + verification** batch: no inline `style` (sprinkles → `.css.ts`
  class/recipe → inline only for data-driven values like `backgroundImage: url()`), kit primitives over
  raw HTML (verify sprinkles supports the property and that `Box` forwards `ref` before swapping), surface
  owner-rule-vs-sibling-parity conflicts for the owner to arbitrate, and **validate `.css.ts` with a real
  `vite build`, not just `tsc`**.
- **level 4** (2026-07-10) — added a **UI/UX design-intelligence** capability: vendored the third-party
  `ui-ux-pro-max` skill (MIT, NextLevelBuilder — searchable styles/palettes/font-pairings/UX-guidelines/
  charts across stacks) into the frontend field pack at `fields/frontend/ui-ux-pro-max/` — it's field
  knowledge, not a global skill (design *what* ↔ field-pack/rigor *how*). Sourced while overhauling the Playlist
  Telegram Mini App to an Apple/Spotify-grade bar.
- **level 3** — stack-defaults deepened & made explicitly adaptive: "adapt-to-project, never impose"
  posture; Core Web Vitals performance section; components (primitives vs kits); client-state/forms/
  routing/animation/API-codegen/monorepo/PWA/monitoring defaults (covering real production stacks);
  captured signature patterns from Total TypeScript, Epic React, and *Just JavaScript* (verified free
  primary sources). Ask-first testing policy; version/primary-source discipline; `qa` skill.
- **level 2** — frontend field pack populated (`stack-defaults`, `curriculum`, `mentors`,
  `learning-sources`, `lessons`); core loop, skills, and agents wired.
- **level 1** — initial kernel + universal core (mindset · principles · rigor · agent-loop · product-sense).

## Get ready for the task (onboarding)

Be ready for whatever the user is building — cheaply. At the start of substantive work:

1. **Detect the field from the project** — `package.json`/deps, configs, file types. Frontend app?
   Backend/API? Mobile? Infra? This is free and usually enough — don't ask if it's obvious.
2. **Ask only when ambiguous** — one short question: *"What are we building (frontend / backend /
   mobile / …) and on what stack?"* Don't interrogate; one question, then proceed.
3. **Load the matching pack — or create one, with a single confirm.** If a `fields/<field>/` pack
   exists, use it. If not — on first substantive work after MasterMind is added to a project — **detect
   the real stack, confirm once, then build a tailored field pack for them**: *"This looks like a
   `<stack>` project — want me to set up a MasterMind field pack tuned to it?"* On yes, `levelup`
   bootstraps it from `_template` (researches + generates, once); from then on it just loads. One
   question, not an interrogation — and never build a pack silently or refuse to build one they'd benefit from.
4. **Token economy — route, don't read-everything.** If `engineering/ROUTER.md` exists, match the task
   to a node's `route_when` and load **only** that node's file(s) — not the whole pack. It lists each
   file's token cost so you can budget. Loading everything to decide relevance is the waste the router
   removes (~15k → ~6k on a typical task). If `ROUTER.md` is missing or a `hash` no longer matches its
   file, ignore it and fall back to `field.md`'s load-on-demand map — **the router only ever speeds
   things up; it's never a dependency.** Regenerate it with `node scripts/build-router.mjs`.
5. **Let the host cache the stable parts.** The always-loaded kernel + a field's pack are stable text; on
   hosts with **prompt caching** (Claude Code / the API, ~90% cheaper on cached reads) they're reused
   across turns at a fraction of the cost. So keep the loaded set **stable within a session** — route
   once, then build; don't churn which pack files are loaded turn-to-turn. Caching is the host's job, not
   ours — we just structure loads so it pays off. (Verdict from research: this + the router are the real
   token wins; encoding skills as *images* is not — it costs more and misreads code.)

## How to change the field

1. Create the pack at `engineering/fields/<name>/`. Two ways:
   - **Copy the template** — `cp -r engineering/fields/_template engineering/fields/<name>`, then fill
     in each file (the template has the shape + inline guidance; `fields/frontend/` shows the bar).
   - **Bootstrap it** — run `levelup --bootstrap <name>` to research and generate it from
     the template.
2. Update the "Current field" line above to point at the new pack.
3. The universal core (`engineering/core/*`) never changes between fields — it's field-agnostic.

> **This is how "swappable" is real, not just a claim.** The frontend pack is one worked example —
> *your daily field.* Any user, on any agent, can copy `_template/` to stand up their own field
> (backend, mobile, data, game-dev, …) and load it with exactly the stack notes and defaults they
> care about. Multiple packs can be active at once for full-stack work.

Multiple fields can be active at once (e.g. `Frontend + Backend`) for full-stack work — load each pack
you need. Today only the **frontend** pack ships; bootstrap a backend pack
(`levelup --bootstrap backend`) before relying on it.

## How MasterMind levels up (honest mechanics)

An LLM's weights are fixed — "leveling up" means **editing this knowledge base**, which changes
behavior durably across all future sessions:

1. **Capture** — every correction the user gives, and every real finding from a `code-reviewer` pass,
   becomes a one-line entry in the active field's `lessons.md` (and, if it's a durable default, in
   `stack-defaults.md`). This is the primary learning channel — it compounds.
2. **Refresh** — periodically re-run the curriculum research (`levelup --refresh`) so the
   field's best-practice list tracks the moving ecosystem; verify repos still exist/are active.
3. **Adapt to the user** — where your assistant has a memory (e.g. Claude Code's file-based memory),
   per-user preferences accumulate there and MasterMind recalls them by relevance; where there's no
   memory, this channel is simply skipped. Field packs hold *domain* truth; memory holds *user* truth.
4. **Mark the level** — bump the level number above and log the change, so improvement is visible and
   reversible via git.
