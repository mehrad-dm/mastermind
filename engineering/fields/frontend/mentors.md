# Mentors — the masters MasterMind reasons like

When taste, philosophy, or "what's the *right* way" is in question, align with these schools of
thought. This is not name-dropping — it's a shortcut to well-tested judgment. Prefer primary sources.

## Software philosophy

- **John Ousterhout** — *A Philosophy of Software Design.* Complexity is the enemy; deep modules;
  information hiding; design it twice; pull complexity downward. The backbone of `principles.md`.
- **Linus Torvalds** — taste = eliminating special cases so the general path just works ("good taste"
  is making the edge case disappear, not adding an `if`). Pragmatism over cleverness; data structures
  over code ("bad programmers worry about the code; good programmers worry about data structures").
- **Rich Hickey** — *Simple Made Easy.* Simple (un-braided, one concern) ≠ easy (familiar). Choose
  simple; it's what stays maintainable. Avoid "complecting" unrelated things.
- **Martin Fowler / Kent Beck** — refactoring as a discipline; "make the change easy, then make the
  easy change"; YAGNI; evolutionary design. Robert C. Martin for clean-code vocabulary (applied with
  judgment, not as religion).

## TypeScript

- **Matt Pocock** — *Total TypeScript.* Make illegal states unrepresentable; `satisfies`; generics as
  functions over types; `as const`; discriminated unions; inference-first APIs. The TS default voice.
- **Anders Hejlsberg / the TS team** — the language's own docs and design intent as ground truth.

## React

- **Dan Abramov** — accurate mental models: reconciliation, effects as synchronization, "Before You
  memo()," "A Complete Guide to useEffect." When effects feel needed, re-derive from his model.
- **Kent C. Dodds** — composition, colocation, state-down/events-up, and *testing behavior not
  implementation* (Testing Library). "Write tests. Not too many. Mostly integration."
- **The React docs (react.dev)** — "You Might Not Need an Effect," "Thinking in React," "Escape
  Hatches." Treat as canonical.
- **Rich Harris (Svelte)** — sharp critiques of framework overhead; a useful outside-view on when
  React/Next is the wrong tool. Reason about cost, don't default blindly.

## CSS & the platform

- **Josh Comeau** — modern CSS mental models (stacking contexts, flexbox/grid intuition, spacing).
- **Kevin Powell** — intrinsic/fluid, mobile-first, container queries, "stop fighting the browser."
- **Una Kravets / web.dev** — modern layout, logical properties, performance, a11y as baseline.
- **Addy Osmani** — web-performance authority: Core Web Vitals, image/asset optimization, code-splitting
  (PRPL), and **adaptive loading** — tailor JS, media, and features to the user's real device & network,
  not your own. Reason about the low-end phone on a slow network, always.
- **Kyle Simpson** — *You Don't Know JS.* Under-the-hood JavaScript: closures, `this`, coercion,
  the event loop. Reason from the runtime, not from superstition.

## Curricula & breadth (use to find gaps, not to pad)

- **roadmap.sh** — Frontend, JavaScript, TypeScript, React, System Design roadmaps. Use as a checklist
  to spot what a topic is *missing*, then go deep on primary sources — don't copy it in wholesale.
- **web.dev / MDN** — the browser platform's ground truth for HTML/CSS/JS/APIs, performance, a11y.
- **patterns.dev** — rendering, performance, and design patterns for modern web apps.

## How to use them

Don't cite them for show. When a decision is genuinely contested, ask: *what would this school do, and
why?* Then apply the reasoning — not the name — and, if it clarifies, note the "why" in one line.
