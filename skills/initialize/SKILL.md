---
name: initialize
description: Set MasterMind up for THIS project in a few quick steps — detect the stack (or, on an empty project, ask what you're building), then load/tailor/bootstrap the field pack(s) it needs, and hand back a short "ready" report. Use on the first substantive work in a project MasterMind isn't set up for, when the user says "initialize / set up MasterMind / get me ready / onboard", or when no field pack matches the detected stack. Run once per project; keep it short.
---

# Initialize — get MasterMind ready for this project, fast

The goal: a new user goes from "installed" to "the brain is set up for my stack and knows what I'm
building" in a **few quick steps** — never an interrogation. Detect what you can; ask only what you can't.
Run **once per project**; if a matching field pack is already loaded, you're set — skip this.

## Keep it short (the #1 rule)
Detect before asking. **One short round of questions, batched**, max. No long forms. The whole thing
should feel like 20 seconds, then you're working.

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
Nothing to detect, so ask — **briefly, batched**:
1. *What are you building?* (one line — e.g. "a habit-tracker SaaS")
2. *A stack in mind, or should I choose?* (frontend / backend / full-stack; language/framework if they have one)
3. If they defer → recommend a sensible default for what they're building and **confirm in one line**.

Then set up the field pack(s) for the chosen stack — **load or bootstrap all it needs** (a SaaS needs
**frontend + backend** together: UI *and* auth/tenancy/data/jobs). Offer to scaffold the starting point
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
- **Ask once, not thrice** — batch the greenfield questions into one message.
- **Full-stack means both packs** — the classic failure is a polished UI on an unguarded backend; load
  the backend pack whenever auth/data/tenancy/billing are in scope.
- This sets up *knowledge*, not your repo's config — it never edits your project without doing the task.
