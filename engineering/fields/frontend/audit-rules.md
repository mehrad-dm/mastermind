---
field: frontend
route_when: [review, audit, code-review, defect, react-bug, lint, a11y-check]
---

# Audit rules — framework-specific defect checks

Data-style rules the **`code-reviewer`** loads to catch framework-specific defects. Each rule is
labelled **convention** (match house style, don't flag) or **correctness** (a real defect — flag with the
citation + failure). Only correctness rules trigger a must-fix; conventions live in `lessons.md` /
`stack-defaults.md` and are conformed to, never "fixed."

**Scope:** React only, today. Add a new `## <framework/library>` section (Vue, Svelte, Next server
components, TanStack Query, etc.) as the field grows — same format. A rule fires **only when that
tech is actually in use** (detect from `package.json`); never impose React checks on a non-React file.

Every finding is **proposed, never applied**, and needs a concrete failure scenario — not a style opinion.

## React

- **Array index as `key` for a reorderable/mutable list** — *correctness.* Keys must be stable identity,
  not position. On reorder/insert/delete, index keys make React reuse the wrong DOM/state (wrong item
  animates, input keeps the previous row's value). Use a stable id. [react.dev — "Rendering Lists: keeping
  list items in order with key".] *(Static, never-reordered lists are fine — don't flag those.)*
- **Effect with a missing/incorrect dependency** — *correctness.* An effect that reads props/state not in
  its dependency array captures stale values (a stale closure); an object/array/function dep recreated each
  render causes an infinite loop. [react.dev — "Removing Effect Dependencies" / the `react-hooks/exhaustive-deps`
  lint rule.] Fix the deps or restructure; don't silence the lint.
- **Effect that has a subscription/timer/listener but no cleanup** — *correctness.* Returns nothing where
  it should return a teardown → leaked intervals/listeners/sockets, double-fires, memory growth.
  [react.dev — "Synchronizing with Effects: how to clean up".]
- **Direct state mutation** (`state.x = …`, `arr.push()` then `setState(arr)`) — *correctness.* Same
  reference → React may skip the re-render, and it corrupts concurrent-mode assumptions. Produce a new
  object/array. [react.dev — "Updating Objects/Arrays in State".]
- **`useEffect` used to compute derived state** — *correctness/perf.* Setting state from other state in an
  effect causes an extra render and can desync; compute it during render (or `useMemo` if expensive).
  [react.dev — "You Might Not Need an Effect".]
- **`dangerouslySetInnerHTML` with unsanitized/user input** — *security.* XSS. Sanitize (e.g. DOMPurify)
  or don't inject HTML. [react.dev — the prop's own warning; OWASP XSS.]
- **Interactive behaviour on a non-interactive element** (`onClick` on a `div`/`span` with no role,
  `tabIndex`, or key handler) — *correctness (a11y).* Not focusable or keyboard-operable; invisible to
  screen readers. Use a `<button>`, or add role + `tabIndex` + key handling. [WAI-ARIA Authoring Practices.]
- **Context value that is a fresh object/array each render, unmemoized** — *performance.* Every provider
  render re-renders all consumers. Memoize the value (`useMemo`) or split contexts. [react.dev — "Passing
  Data Deeply with Context" / performance notes.] *(A rarely-changing provider may not need it — judge cost.)*
- **Input flipping controlled ↔ uncontrolled** (`value={x}` where `x` can be `undefined`) — *correctness.*
  React warns and the field loses/keeps state unexpectedly. Default to `''`/controlled. [react.dev warning.]

## How the reviewer uses this
Load this file when React is in the diff. For each match, apply the convention/correctness gate: flag only
correctness (with the citation above + a failure scenario), propose the fix, and if the same defect recurs,
recommend capturing it via `levelup` so generation stops producing it.
