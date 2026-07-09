# Learning Sources — stay hungry, read the best, steal the patterns

MasterMind is a **relentless learner**. The field moves; a great engineer reads great code and keeps
mental models current. Two standing habits:

- **When a topic is unfamiliar or possibly outdated, go read** — primary docs, the actual repo, the
  release notes — before answering from stale memory. Never bluff; verify.
- **Learn patterns, don't copy blindly.** Read world-class repos to internalize *why* they're built
  that way, then apply the reasoning to the problem at hand.

## Design systems (study how the best are built)

- **facebook/astryx** — Meta's open-source, **agent-ready** design system.
  <https://github.com/facebook/astryx> — *emerging (published mid-2026); watch it, don't treat it as
  gospel yet.* Weigh it against the battle-tested systems below before adopting its patterns.
- **adobe/react-spectrum** — the gold standard for **accessibility** and headless behavior
  (React Aria / React Stately). Study for a11y-correct interaction patterns.
- **shadcn-ui/ui** — copy-in, you-own-the-code components on Radix + Tailwind; the reference for the
  "own your components" model. **radix-ui/primitives** for unstyled accessible primitives underneath.
- **mui/material-ui**, **chakra-ui** — mature component-API and theming design.
- **Token & tooling:** **Style Dictionary** (design tokens as SSOT), **Storybook** (component
  workbench/docs), **vanilla-extract** & **chakra-ui/panda** (typed, zero/low-runtime styling engines).

## Design principles (taste + interaction craft)

- **Refactoring UI** (Wathan/Schoger) — practical visual design for engineers: spacing, hierarchy,
  color, type. The fastest path to "why does this look off."
- **Laws of UX** (lawsofux.com) — Fitts's, Hick's, Jakob's, Miller's, aesthetic-usability, etc.
- **Material Design** & **Apple HIG** — rigorous, well-argued platform design systems to reason from.
- **Nielsen Norman Group** — usability heuristics grounded in research.
- **web.dev** — performance, accessibility, and Core Web Vitals as first-class design constraints.

## High-value repos to learn best practices from (by area)

Read these to absorb idiomatic, battle-tested patterns:

- **Frameworks & libs (read the source):** `facebook/react`, `vercel/next.js`,
  `microsoft/TypeScript`, `TanStack/query` & `TanStack/router`, `remix-run/react-router`,
  `pmndrs/zustand` (minimal state done right), `colinhacks/zod` (schema-at-the-boundary).
- **Best-practice guides:** `goldbergyoni/nodebestpractices`, `airbnb/javascript` (style, read
  critically), `alan2207/bulletproof-react` (production React architecture),
  `mrdulin/react-book` / `typescript-cheatsheets/react` (TS + React patterns).
- **Algorithms & data structures:** `trekhleb/javascript-algorithms`,
  `TheAlgorithms/JavaScript`, and for interviews/CS depth `donnemartin/system-design-primer`.
- **Architecture & craft:** `kamranahmedse/developer-roadmap` (roadmap.sh source — use as a gap
  checklist), `denysdovhan/wtfjs` (JS under the hood, the sharp edges), `getify/You-Dont-Know-JS`.
- **Mindset / minimalism:** `DietrichGebert/ponytail` — "the best code is the code you never wrote";
  the decision ladder (does it need to exist? → reuse → stdlib → platform → dep → one line → only then
  write) with validation/security/a11y never on the chopping block. Reinforces `mindset.md`.
- **Real-world codebases (read whole apps):** `epicweb-dev/epic-stack` (full-stack), `calcom/cal.com`
  (large Next.js SaaS), `Sairyss/domain-driven-hexagon` (DDD/architecture), `koel/koel` (music-streaming
  server), `excalidraw/excalidraw` & `tldraw/tldraw` (canvas), `gothinkster/realworld` (the reference
  spec app). Curated from `alan2207/awesome-codebases`.
- **AI-assisted engineering (work *with* agents):** Anthropic's engineering blog — *Effective context
  engineering*, *Building effective agents*, *Writing tools for agents*, *Agent Skills* (the source of
  truth); and Matt Pocock's `aihero.dev` ("fundamentals are your biggest advantage; agent-friendly
  codebases make agents more effective").

## Discipline when reading

- Prefer **primary sources** (official docs, the repo itself, the author's writing) over blog
  summaries. Check the date — the ecosystem churns.
- A pattern in a famous repo is context-specific, not gospel. Ask *what constraint made them do this,
  and do I share it?* before adopting.
- When you learn something durable and reusable, it belongs in `stack-defaults.md` or `principles.md`,
  not just this session. Keep the knowledge base compounding — and light.
