---
field: frontend
route_when: [learn, curriculum, resource, course, roadmap, deep-dive]
---

# Curriculum — an on-demand reference index

**This is a reference to draw from, not required reading — and not a completeness goal.** When you
build, your default is primary docs + the roadmap.sh checklist + judgment (`learn`), never
this list. A frontier model already knows most of these — don't reload what you already know. Reach
here only to **recommend learning resources to the user**, or when going genuinely deep on a topic.

Load a **single section** on demand — never the whole file. Every GitHub repo here was **verified
against the GitHub API** (exists, active, not archived) as of 2026-07; re-verify periodically.

Discipline (from `learning-sources.md`): prefer primary sources, check dates, learn the *why* not the
syntax, and fold durable lessons back into `principles.md`/`stack-defaults.md`.

---

## JavaScript — the language & under the hood

- **Repos:** `getify/You-Dont-Know-JS` (language mechanics, canonical) · `leonardomso/33-js-concepts`
  (structured syllabus) · `lydiahallie/javascript-questions` (reason from first principles) ·
  `tc39/ecma262` (spec ground truth) · `v8/v8` (real engine internals) · `denysdovhan/wtfjs` (edge cases).
- **Books/Courses:** *You Don't Know JS Yet* 2e — Simpson (free) · *Eloquent JavaScript* 4e — Haverbeke
  (free) · Deep JavaScript Foundations v3 — Simpson (FEM) · JavaScript: The Hard Parts v2 — Sentance (FEM).
- **People:** Kyle Simpson · Mathias Bynens (V8 shapes/ICs) · Jake Archibald (event loop) · Benedikt
  Meurer (JIT/TurboFan) · Lin Clark (code-cartoons) · Lydia Hallie (visual internals).
- **Docs:** MDN JS · v8.dev/blog · tc39.es/ecma262 · WHATWG HTML "Event loops" · mathiasbynens.be/notes/shapes-ics.

## TypeScript — advanced types, patterns, tooling

- **Repos:** `type-challenges/type-challenges` · `sindresorhus/type-fest` · `mattpocock/ts-reset`
  (was total-typescript/ts-reset) · `microsoft/TypeScript` · `danvk/effective-typescript` ·
  `colinhacks/zod` (type-first API design).
- **Books/Courses:** Total TypeScript — Pocock (freemium) · *Effective TypeScript* 2e — Vanderkam ·
  Type-Level TypeScript — Vergnaud (freemium) · TypeScript Deep Dive — Basarat (free).
- **People:** Matt Pocock · Anders Hejlsberg · Ryan Cavanaugh · Andrew Branch · Dan Vanderkam · Gabriel Vergnaud.
- **Docs:** TS Handbook · TS Release Notes · tsconfig reference · devblogs.microsoft.com/typescript.

## React — mental models, patterns, testing, performance

- **Repos:** `facebook/react` · `reactjs/react.dev` · `alan2207/bulletproof-react` (production
  architecture) · `kentcdodds/advanced-react-patterns` · `testing-library/react-testing-library` ·
  `TanStack/query` (server state) · `pmndrs/zustand` (minimal client state).
- **Books/Courses:** Epic React v2 (React 19 + TS) — Kent C. Dodds · Advanced React — Nadia Makarevich ·
  The Road to React — Wieruch (freemium) · The Joy of React — Josh Comeau.
- **People:** Dan Abramov (overreacted.io) · Nadia Makarevich (developerway.com) · Kent C. Dodds ·
  Josh Comeau · Tanner Linsley (TanStack).
- **Docs:** react.dev/learn · "React as a UI Runtime" (Abramov) · Testing Library principles ·
  TanStack Query docs · patterns.dev/react.

## Next.js — App Router, RSC, full-stack

- **Repos:** `vercel/next.js` · `vercel/commerce` · `vercel/platforms` · `shadcn-ui/taxonomy`
  (real-world App Router) · `t3-oss/create-t3-app` · `vercel/next-learn`.
- **Courses:** Next.js Learn (official, free) · Next.js Fundamentals v4 — Scott Moss (FEM) · Joy of React — Comeau.
- **People:** Lee Robinson · Dan Abramov · Josh Comeau · Delba de Oliveira · Jack Herrington.
- **Docs:** nextjs.org/docs/app · "Making Sense of RSC" (Comeau) · react.dev RSC reference · Next.js
  Caching docs · "RSC From Scratch" (Abramov).

## CSS — fundamentals & modern CSS

- **Repos:** `micromata/awesome-css-learning` · `argyleink/gui-challenges` (Argyle) ·
  `argyleink/open-props` (design tokens) · `mdn/content` · `web-platform-dx/web-features`.
- **Courses:** CSS for JS Developers — Josh Comeau · Learn CSS — web.dev · Conquering Responsive
  Layouts — Kevin Powell (freemium) · Ahmad Shadeed's interactive guides (free).
- **People:** Kevin Powell · Adam Argyle · Josh Comeau · Ahmad Shadeed · Miriam Suzanne · Una Kravets.
- **Docs:** MDN CSS · CSS-Tricks Complete Guides (Grid/Flexbox) · MDN Container Queries · MDN Logical
  Properties · stateofcss.com.

## CSS styling engines & methodologies

- **Repos:** `tailwindlabs/tailwindcss` · `facebook/stylex` · `chakra-ui/panda` ·
  `vanilla-extract-css/vanilla-extract` · `css-modules/css-modules` · `emotion-js/emotion`.
- **Books:** CSS for JS Developers — Comeau · Refactoring UI — Wathan & Schoger.
- **People:** Adam Wathan (Tailwind) · Mark Dalgleish (vanilla-extract/CSS Modules) · Segun Adebayo
  (Panda/Chakra) · Sam Magura (emotion; the "breaking up with CSS-in-JS" essay) · Naman Goel (StyleX).
- **Docs:** tailwindcss.com/docs · panda-css.com/docs · vanilla-extract.style · stylexjs.com · the
  runtime CSS-in-JS cost essay (dev.to/srmagura).
  > See `stack-defaults.md` for *when to choose which* — this is the reference, that is the decision.

## HTML & accessibility

- **Repos:** `w3c/aria-practices` (APG) · `dequelabs/axe-core` (the a11y test engine) ·
  `KittyGiraudel/a11y-dialog` (reference accessible component) · `a11yproject/a11yproject.com` · `w3c/wcag` ·
  `alphagov/govuk-frontend` (rigorously accessible components).
- **Courses:** Practical Accessibility — Sara Soueidan · Inclusive Components — Heydon Pickering
  (freemium) · Web Accessibility Cookbook — Matuzović · Learn Accessibility — web.dev (free).
- **People:** Adrian Roselli · Sara Soueidan · Scott O'Hara · Léonie Watson · Heydon Pickering · Manuel Matuzović.
- **Docs:** MDN Accessibility · ARIA APG · WCAG 2.2 · WAI-ARIA 1.2 · webaim.org.

## Responsive, mobile-first & intrinsic layout

- **Repos:** (see CSS: `argyleink/open-props`, `argyleink/gui-challenges`, `mdn/content`).
- **Courses:** Every Layout — Pickering & Bell · CSS for JS Developers — Comeau · Learn Responsive
  Design — web.dev (free) · Learn CSS — web.dev (free).
- **People:** Jen Simmons · Rachel Andrew · Una Kravets · Andy Bell · Kevin Powell · Adam Argyle.
- **Docs:** MDN Responsive Design · MDN Grid common layouts · web.dev Container Queries · every-layout.dev.

## Design systems

- **Repos:** `shadcn-ui/ui` · `radix-ui/primitives` · `adobe/react-spectrum` (a11y gold standard) ·
  `primer/react` (GitHub) · `carbon-design-system/carbon` (IBM) · `style-dictionary/style-dictionary`
  (tokens) · `storybookjs/storybook` · **`facebook/astryx`** (agent-ready design system).
- **Courses:** Atomic Design — Brad Frost (free) · Design Systems Handbook — DesignBetter (free) ·
  Intro to Storybook (free) · Refactoring UI — Wathan & Schoger.
- **People:** Brad Frost · Nathan Curtis · Dan Mall · Adam Wathan · shadcn.
- **Docs:** Design Tokens CG spec · Storybook docs · Radix Primitives docs · Style Dictionary docs · USWDS.

## Design principles & UI/UX craft

- **Repos:** `raunofreiberg/interfaces` (web interface guidelines) · `goabstract/Awesome-Design-Tools`.
- **Books:** Refactoring UI — Wathan & Schoger · The Design of Everyday Things — Norman · Don't Make Me
  Think — Krug · Laws of UX — Yablonski · Universal Principles of Design — Lidwell et al.
- **People:** Steve Schoger · Adam Wathan · Rauno Freiberg · Josh Comeau · Jakob Nielsen · Jon Yablonski.
- **Docs:** NN/g 10 Usability Heuristics · lawsofux.com · interfaces.rauno.me · Apple HIG · Material Design 3.

## Algorithms & data structures

- **Repos:** `trekhleb/javascript-algorithms` · `yangshun/tech-interview-handbook` ·
  `TheAlgorithms/TypeScript` · `TheAlgorithms/JavaScript` · `loiane/javascript-datastructures-algorithms`.
- **Books/Courses:** Cracking the Coding Interview — McDowell · The Algorithm Design Manual — Skiena ·
  Algorithms I & II (Princeton/Coursera) — Sedgewick & Wayne (free) · Algorithms Illuminated —
  Roughgarden · NeetCode roadmap (freemium).
- **People:** Oleksii Trekhleb · Yangshun Tay · Steven Skiena · Tim Roughgarden · Steven Halim (VisuAlgo) · NeetCode.
- **Docs:** bigocheatsheet.com · visualgo.net · Tech Interview Handbook cheatsheets · MDN JS data structures.

## Networking, HTTP, APIs & API architecture

- **Repos:** `zalando/restful-api-guidelines` · `microsoft/api-guidelines` · `trpc/trpc` ·
  `graphql/graphql-spec` · `OWASP/API-Security` · `public-apis/public-apis` · `apollographql/apollo-client`.
- **Books/Courses:** High Performance Browser Networking — Grigorik (free) · How to GraphQL (free) ·
  Build APIs You Won't Hate — Sturgeon · web.dev network reliability & caching (free).
- **People:** Mark Nottingham (HTTP specs) · Ilya Grigorik · Roy Fielding (REST) · Phil Sturgeon · Theo Browne.
- **Docs:** RFC 9110 (HTTP Semantics) · MDN HTTP · graphql.org/learn · OWASP API Security Top 10 · oauth.net/2.

## Software design, clean code & architecture

- **Repos:** `mehdihadeli/awesome-software-architecture` · `ryanmcdermott/clean-code-javascript` ·
  `nilbuild/design-patterns-for-humans` (was kamranahmedse) · `DovAmir/awesome-design-patterns` ·
  `donnemartin/system-design-primer`.
- **Books:** A Philosophy of Software Design 2e — Ousterhout · Refactoring 2e — Fowler · Tidy First? —
  Beck · Domain-Driven Design — Evans · Clean Architecture — Martin.
- **People:** Martin Fowler · Kent Beck · John Ousterhout · Robert C. Martin · Vaughn Vernon.
- **Docs:** refactoring.com/catalog · martinfowler.com/architecture · refactoring.guru · 12factor.net.

## The mindset of the greatest builders

- **Repos:** `papers-we-love/papers-we-love` · `matthiasn/talk-transcripts` (Hickey & others) ·
  `codecrafters-io/build-your-own-x` (build it to understand it) · `mtdvio/every-programmer-should-know` ·
  `ossu/computer-science` (full self-taught CS). Also `DietrichGebert/ponytail` (see `mindset.md`).
- **Books:** Coders at Work — Seibel · A Philosophy of Software Design — Ousterhout · The Mythical
  Man-Month — Brooks · The Pragmatic Programmer 20e — Hunt & Thomas · SICP — Abelson & Sussman (free).
- **People:** John Carmack · Dan Luu · Bryan Cantrill · Rich Hickey · Julia Evans · Jeff Dean.
- **Docs:** "Simple Made Easy" — Hickey · E.W. Dijkstra Archive (EWD) · Joel on Software · "No Silver
  Bullet" — Brooks · John Carmack's .plan archive.

---

### Verification note (rigor in action)
All 78 candidate repos were API-checked. Dropped as dead/mismatched: `input-output-hk/hydra` (a Cardano
blockchain project, wrong match), `Shopify/polaris` (archived), `Andy-set-studio/modern-css-reset`
(archived/superseded), `jensimmons/labs` (stale). `GoogleChrome/web.dev` repo is archived — its site
web.dev remains the live reference. Re-verify periodically; the ecosystem drifts.
