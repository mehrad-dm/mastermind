---
name: initialize
description: Set MasterMind up for THIS project in a few quick steps — detect the stack (or, on an empty project, ask what you're building), then load/tailor/bootstrap the field pack(s) it needs, and hand back a short "ready" report. Use on the first substantive work in a project MasterMind isn't set up for, when the user says "initialize / set up MasterMind / get me ready / onboard", or when no field pack matches the detected stack. Run once per project; keep it short.
---

# Initialize — get MasterMind ready for this project, fast

The goal: a new user goes from "installed" to "the brain is set up for my stack and knows what I'm
building" in a **few quick steps** — never an interrogation. Detect what you can; ask only what you can't.
Run **once per project**; if a matching field pack is already loaded, you're set — skip this.

## Keep it short (the #1 rule)
**Detect before asking; never ask what you can read, and never hand the user a menu of technical options.**
A developed project needs **zero questions** — continue with its own stack. A greenfield project needs **one
open question** ("what do you want to build?"), answered in their own words. The whole thing should feel
like 20 seconds, then you're working.

## Path A — the project already has code
1. **Detect the stack** — `package.json`/lockfile, configs, framework + versions, DB, test runner, folder
   shape (`core/agent-loop.md`). This is free; never ask what you can read.
2. **Match it to a field pack:**
   - **Pack exists and fits** → load it. Done.
   - **Pack exists but mismatches** (e.g. the frontend pack on a Vue/Svelte app, or a Next.js app vs a
     Turborepo profile) → **tailor it**: prune what doesn't apply, add what's missing (via `levelup`) —
     never force a mismatched pack (`active-field.md`).
   - **No pack for this field** → offer a **one-time bootstrap** (`levelup bootstrap`), stating the
     trade-off: *"a few minutes now makes me much sharper on your stack; it's once per field, then reused."*
3. **Respect the project** — match its conventions; never impose a stack (`stack-defaults.md`: the
   project wins).

## Path B — greenfield (empty folder / nothing built yet)
Nothing to detect, so ask **one open question, in the user's own words — never a menu of stack options:**

> *"What do you want to build?"*

Let them describe it freely — a product, an app, a feature — **technical or not**. Then read their answer:
- **They named the tech** (a framework, language, database) → use it.
- **They only described the product** → assume they may not be an engineer, and **never make them pick a
  stack.** *You* choose the architecture and tech stack that best fit what they described — that's the
  prime directive (decide for them) — then state the choice with a one-line *why* and proceed; **don't ask
  permission**: *"I'll build this as Next.js + Postgres — best fit for a realtime habit tracker."* (If they
  later want something different, they'll say so.)

Then set up the field pack(s) for that stack — **load or bootstrap all it needs** (a real app needs
**frontend + backend**: UI *and* auth/tenancy/data/jobs). Offer to scaffold the starting point
(repo/toolchain/env), then hand to `build` / `architect` for the first slice.

## Never gate the first result on setup
If the user is eager to build *now*, start the first vertical slice on general judgment and run
pack-bootstrap **as an after-first-slice / background step** — never let a multi-minute research detour
block their first working result.

## Always end with a short report
Both paths finish with a **~5-line** report so the setup is visible and the user knows what's ready:

```
▸ MasterMind ready
  stack:       Next.js 15 · React 19 · Postgres/Prisma   (detected)
  fields:      frontend (loaded) · backend (bootstrapped)
  conventions: matched your existing style
  next:        tell me what to build — I'll run the build loop.
```

Then proceed straight into their actual task. Don't stop and wait after the report.

## Gotchas
- **Don't re-initialize** a project that's already set up — check for a loaded/matching field pack first.
- **One open question, never a menu** — greenfield asks only "what do you want to build?"; if the user
  isn't technical, *you* pick the stack (decide for them), state it, and move — don't make them choose.
- **Full-stack means both packs** — the classic failure is a polished UI on an unguarded backend; load
  the backend pack whenever auth/data/tenancy/billing are in scope.
- This sets up *knowledge*, not your repo's config — it never edits your project without doing the task.
