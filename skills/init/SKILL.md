---
name: init
description: Use on the first substantive work in a project MasterMind isn't set up for yet, when the user says "init", "initialize", "set up MasterMind", "onboard", "get me ready", or when no field pack matches the project's detected stack.
---

# Initialize — get MasterMind ready for this project, fast

The goal: a new user goes from "installed" to "the brain is set up for my stack and knows what I'm
building" in a **few quick steps** — never an interrogation. Detect what you can; ask only what you can't.
Run **once per project**; if this project already built its field, you're set — skip this.

**Nothing ships pre-baked.** A fresh install carries only the engine and `engineering/fields/_template/`
— no field, because a pack tuned to someone else's stack is worse than none (dead weight that misleads).
So init's core job is to **build this project's field from the template**, tuned to the real stack. This
is where the measured quality lift comes from; without it you still apply solid general judgment, but the
domain pack is the difference.

## Keep it short (the #1 rule)
**Detect before asking; never ask what you can read, and never hand the user a menu of technical options.**
A developed project needs **zero questions** — continue with its own stack. A greenfield project needs **one
open question** ("what do you want to build?"), answered in their own words. The whole thing should feel
like 20 seconds, then you're working.

## Path A — the project already has code
1. **Detect the stack** — `package.json`/lockfile, configs, framework + versions, DB, test runner, folder
   shape (`core/agent-loop.md`). This is free; never ask what you can read.
2. **Set up its field:**
   - **This project already built a field that fits** → load it. Done. (Nothing else ships, so this only
     happens on a re-run of a project that was set up before.)
   - **Otherwise — build one** from `engineering/fields/_template/`, tuned to the detected stack: a
     **one-time bootstrap** (`levelup bootstrap`), stated as a trade-off, not a menu: *"a few minutes now
     makes me much sharper on your stack — its real defaults, pitfalls, and review rules. It's once per
     field, then reused for every task."* Build it to fit **one real stack**, and keep it lean — tailoring
     **prunes as much as it adds** (`active-field.md`). Then point `active-field.md` at it and regenerate
     the router from the source clone (`node scripts/build-router.mjs`).
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
  fields:      frontend + backend (built from _template for your stack)
  conventions: matched your existing style
  next:        tell me what to build — I'll run the build loop.
```

Then proceed straight into their actual task. Don't stop and wait after the report.

## Optional preferences — offer once, then remember
After the ready report, offer these once — both skippable, both default **off**:

> *"Two optional preferences, both off by default — I'll remember your answers:*
> *(1) a short written **report** at the end of each build/QA cycle? (markdown / html)*
> *(2) **plan-first** — on bigger tasks, should I show the plan and wait for your OK before editing?"*

Record the answers in **`.mastermind/prefs.md`** (create it), one line each. Both preferences are defined by
their implementations — **`skills/build/SKILL.md`** (plan-first gate) and **`skills/report/SKILL.md`**
(`cycle-report` values); read those for the exact keys and accepted values rather than restating them here.
Don't push it: if they don't care or don't answer, default both `off` and move straight on. They can change
either anytime ("reports on", "plan first from now on"). (Keep it to this single light offer — never turn
setup into an interrogation.)

## Gotchas
- **Don't re-initialize** a project that's already set up — check for a loaded/matching field pack first.
- **One open question, never a menu** — greenfield asks only "what do you want to build?"; if the user
  isn't technical, *you* pick the stack (decide for them), state it, and move — don't make them choose.
- **Full-stack means both packs** — the classic failure is a polished UI on an unguarded backend; load
  the backend pack whenever auth/data/tenancy/billing are in scope.
- This sets up *knowledge*, not your repo's config — it never edits your project without doing the task.
