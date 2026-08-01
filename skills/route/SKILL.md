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
2. **Right-size the map.** If it's a one-line diff, a typo, or obviously covered by what's already in
   context — say *"no map needed, just do it"* and **exit.** Ceremony on a trivial task is waste (this is
   the same instinct as `~/.mastermind/engineering/core/rigor.md`'s refuse-list and "keep the always-on
   layer tiny").
3. **Detect the field** — `package.json`/configs/file types (usually free and decisive).
4. **Build the load manifest — links only, no summaries.** Consult `~/.mastermind/engineering/ROUTER.md`
   and pick, by matching the task to each node's `route_when`:
   - which **field-pack file(s)** to load (and their token cost — budget it),
   - which **skill(s)** fit — pick from the index at `~/.mastermind/skills/README.md` (which also names
     the isolated-context **agents** in `~/.mastermind/agents/`) — read that index, since memory goes stale,
   - which **core docs** the task genuinely needs (`mindset`/`principles`/`rigor`/`agent-loop`/`product-sense`
     in `~/.mastermind/engineering/core/`),
   - which **codebase areas** to read first.
   The manifest **points** to files to open; it links instead of paraphrasing (so it can't drift out of sync).
5. **Load progressively.** For a big/foggy task, load the entrance set only; name the next files *after*
   the first decisions resolve. Front-load only the context this step uses.

## Offer what fits — at most once, and only when it changes the outcome

Most users know three or four skills and never discover the rest, so a capability they already own stays
invisible until it's too late to help. Routing is the one moment you can see the whole task *and* the whole
library, so it's the right place — and the only place — to say something.

Offer only when **every** gate holds:

- **It changes the outcome, not the ceremony.** "This is a risky unknown — want a throwaway spike first?"
  earns its line. "You could also run qa" does not.
- **They didn't already ask for it**, and haven't turned it down this session. One decline retires that
  offer for good.
- **One per task, maximum.** If two fit, offer the one with the larger consequence and stay quiet about
  the other.
- **Say the value, not the tool.** *"There's client data in this repo — I can quarantine it so it can't be
  committed"* lands; *"invoke the lab skill"* is homework.

Then continue with your own recommendation either way — an offer is a sentence they can ignore, never a
question that blocks the work. **Silence is the default**: when it's a close call, skip it. A suggestion
that isn't obviously worth its line costs attention, tokens, and trust, and those are the things the
routing step exists to protect.

## Seat the task as well as the knowledge (model economics)

Routing decides what to *load*; spend one extra second deciding what should *run* it. Four task shapes
are small-model work billed at top rate only by inertia: **classify, extract fields, rename, summarise**.
Name the shape when you see it — on Claude Code that means suggesting the cheap seat (`/model`, or an
agent whose file pins one); on Cursor/Codex it's advice the user applies. The inverse holds too:
**planning is one expensive call at the top**, not something to repeat mid-task on the execution seat.
And grading is its own seat — `code-reviewer` pins a fixed model so the judge's seat doesn't follow
the writer's (a guarantee of fresh context always, and of a different grader whenever the session runs
another tier). Upgrading the execution seat to the planning seat doubles the bill and changes nothing.

## Rules

- **The manifest is a list of things to load, not a plan of work.** Wayfinder chooses *what knowledge to
  bring*; the actual building is `build` (which can call this first).
- **Load a file for a reason you can name.** Every entry earns its tokens or it's cut.
- **If `ROUTER.md` is missing/stale, fall back** to the active field's `engineering/fields/<field>/field.md`
  load-on-demand map — routing is a speed-up over a fallback that already works.

## Gotchas

- **A load manifest, not a ticket/issue system.** Wayfinder routes knowledge for one session; it is not a
  project tracker. Keep it to a load manifest.
- **Over-routing is as bad as under-routing.** A three-file task needs no map — the right-size step is a
  feature, not a formality.
- **Points to the source.** The moment the manifest starts summarizing a doc's contents, it will drift
  and lie. Link to the file; let the reader load the source of truth.
