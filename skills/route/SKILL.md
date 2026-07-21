---
name: route
description: Use at the start of a task that spans multiple files, touches unfamiliar areas of a codebase, or where it isn't obvious what to load or where to begin. Skips itself for a one-line change or an already-scoped task.
---

# MasterMind — Wayfinder

The front door of substantive work: decide **what to load** before you start, so you pull the 1–2 things a
task needs instead of reading the whole brain. It's the skill that operationalizes MasterMind's
token economy (`~/.mastermind/engineering/active-field.md`) — and it knows when *not* to run.

## Method

1. **Name the destination.** One line: what is this task actually producing? Scope before routing.
2. **Refuse to over-plan.** If it's a one-line diff, a typo, or obviously covered by what's already in
   context — say *"no map needed, just do it"* and **exit.** Ceremony on a trivial task is waste (this is
   the same instinct as `~/.mastermind/engineering/core/rigor.md`'s refuse-list and "keep the always-on
   layer tiny").
3. **Detect the field** — `package.json`/configs/file types (usually free and decisive).
4. **Build the load manifest — links, never summaries.** Consult `~/.mastermind/engineering/ROUTER.md`
   and pick, by matching the task to each node's `route_when`:
   - which **field-pack file(s)** to load (and their token cost — budget it),
   - which **skill(s)** fit — pick from the index at `~/.mastermind/skills/README.md` (which also names
     the isolated-context **agents** in `~/.mastermind/agents/`); never route off a remembered list,
   - which **core docs** the task genuinely needs (`mindset`/`principles`/`rigor`/`agent-loop`/`product-sense`
     in `~/.mastermind/engineering/core/`),
   - which **codebase areas** to read first.
   The manifest **points** to files to open; it never paraphrases them (so it can't drift out of sync).
5. **Load progressively.** For a big/foggy task, load the entrance set only; name the next files *after*
   the first decisions resolve. Don't front-load context you won't use.

## Rules

- **The manifest is a list of things to load, not a plan of work.** Wayfinder chooses *what knowledge to
  bring*; the actual building is `build` (which can call this first).
- **Never load a file "just in case."** Every entry earns its tokens or it's cut.
- **If `ROUTER.md` is missing/stale, fall back** to the active field's `engineering/fields/<field>/field.md`
  load-on-demand map — routing is a speed-up, never a dependency.

## Gotchas

- **Don't build a ticket/issue system.** Wayfinder routes knowledge for one session; it is not a project
  tracker. Keep it to a load manifest.
- **Over-routing is as bad as under-routing.** A three-file task doesn't need a map — the refuse step is a
  feature, not a formality.
- **Points, never restates.** The moment the manifest starts summarizing a doc's contents, it will drift
  and lie. Link to the file; let the reader load the source of truth.
