---
name: init
description: Use on the first substantive work in a project MasterMind isn't set up for yet, when the user says "init", "initialize", "set up MasterMind", "onboard", "get me ready", or when no field pack matches the project's detected stack.
---

# Initialize: get MasterMind ready for this project, fast

The goal: a new user goes from "installed" to "the brain is set up for my stack and knows what I'm
building" in a **few quick steps**: a handoff, not an intake form. Detect what you can; ask the rest.
Run **once per project**; if this project already built its field, you're set: skip this.

**Nothing ships pre-baked.** A fresh install carries only the engine and `engineering/fields/_template/`
no field, because a pack tuned to someone else's stack is worse than none (dead weight that misleads).
So init's core job is to **build this project's field from the template**, tuned to the real stack. This
is where the measured quality lift comes from; without it you still apply solid general judgment, but the
domain pack is the difference.

## Keep it short (the #1 rule)
**Detect before asking: read the answers out of the project, and make the technical calls yourself.**
A developed project needs **zero questions**: continue with its own stack. A greenfield project needs **one
open question** ("what do you want to build?"), answered in their own words. The whole thing should feel
like 20 seconds, then you're working.

## Path A: the project already has code
1. **Detect the stack**: `package.json`/lockfile, configs, framework + versions, DB, test runner, folder
   shape (`core/agent-loop.md`). This is free, read it rather than asking.
2. **Set up its field:**
   - **This project already built a field that fits** → load it. Done. (Nothing else ships, so this only
     happens on a re-run of a project that was set up before.)
   - **Otherwise: build one** from `engineering/fields/_template/`, tuned to the detected stack: a
     **one-time bootstrap** (`levelup bootstrap`), stated as a trade-off, not a menu: *"a few minutes now
     makes me much sharper on your stack: its real defaults, pitfalls, and review rules. It's once per
     field, then reused for every task."* Build it to fit **one real stack**, and keep it lean, tailoring
     **prunes as much as it adds** (`active-field.md`). **Fill the pack's "Where things are" section**
     from what step 1 already detected: the half-dozen entry-point pointers (components, routes, state,
     tests + run command, config, the one file that explains the architecture fastest). This is the
     narrow exception to "skip the directory listing" below: a full tree is re-derivable noise, but
     these few pointers are what stop every future task from re-running discovery. Then point
     `active-field.md` at it and regenerate the router **from the brain you are installed into**:
     `node .mastermind/scripts/build-router.mjs` (per-project, the default), or
     `node ~/.mastermind/scripts/build-router.mjs` with `--shared`. A bare `scripts/…` path is
     the project's own directory and fails with MODULE_NOT_FOUND.
3. **Respect the project**: match its conventions and keep the stack it already chose
   (`stack-defaults.md`: the project wins).

## Path B: greenfield (empty folder / nothing built yet)
Nothing to detect, so ask **one open question, in the user's own words rather than a menu of stack options:**

> *"What do you want to build?"*

Let them describe it freely: a product, an app, a feature, **technical or not**. Then read their answer:
- **They named the tech** (a framework, language, database) → use it.
- **They only described the product** → assume they may not be an engineer, and **make the stack call for
  them.** *You* choose the architecture and tech stack that best fit what they described. That's the
  prime directive (decide for them), then state the choice with a one-line *why* and **proceed without
  pausing**: *"I'll build this as Next.js + Postgres: best fit for a realtime habit tracker."* (If they
  later want something different, they'll say so.)

Then set up the field pack(s) for that stack, **load or bootstrap all it needs** (a real app needs
**frontend + backend**: UI *and* auth/tenancy/data/jobs). Offer to scaffold the starting point
(repo/toolchain/env), then hand to `build` / `architect` for the first slice.

## The first result comes before setup finishes
If the user is eager to build *now*, start the first vertical slice on general judgment and run
pack-bootstrap **as an after-first-slice / background step**: a multi-minute research detour waits its
turn behind their first working result.

## Show the plan before you write the pack

Building a field takes minutes of research and lands real files, so let the user see it as a proposal
first: a few lines, not a document:

```text
Detected: Next.js 15 · React 19 · TypeScript · Postgres/Prisma · Vitest
I'll build a `frontend` field with: stack defaults for this exact combination ·
review rules for React 19 · an empty lessons file that fills as we work.
Starting now: say the word if the stack reading is off.
```

State it and proceed; this announces rather than asks. It costs one line and catches the one failure
worth catching: a wrong stack reading becoming a pack that's subtly wrong about everything.

**Store only what can't be re-derived**: plus the pack's few "Where things are" entry-point pointers
(step 2's named exception). Skip the full directory listing and the dependency list, the model
can read those any time. Keep the pitfalls, the non-obvious conventions, and the decisions someone
would otherwise have to rediscover.

## Always end with a short report
Both paths finish with a **~5-line** report so the setup is visible and the user knows what's ready:

```
▸ MasterMind ready
  stack:       Next.js 15 · React 19 · Postgres/Prisma   (detected)
  fields:      frontend + backend (built from _template for your stack)
  conventions: matched your existing style
  next:        tell me what to build, I'll run the build loop.
```

Then proceed straight into their actual task: the report is a line you pass through, not a checkpoint.

## Optional preferences: offer once, then remember
After the ready report, offer these once: both skippable, both default **off**:

> *"Two optional preferences, both off by default. I'll remember your answers:*
> *(1) a short written **report** at the end of each build/QA cycle? (markdown / html)*
> *(2) **plan-first**: on bigger tasks, should I show the plan and wait for your OK before editing?"*

Record the answers in **`.mastermind/prefs.md`** (create it), one line each. Both preferences are defined by
their implementations, **`skills/build/SKILL.md`** (plan-first gate) and **`skills/report/SKILL.md`**
(`cycle-report` values); read those for the exact keys and accepted values rather than restating them here.
Ask once and let it go: a shrug or silence defaults both `off` and you move straight on. They can change
either anytime ("reports on", "plan first from now on"). (Keep it to this single light offer: one ask,
then work.)

## Gotchas
- **Run once per project**: check for a matching field pack first, and load it if one is already there.
- **One open question, kept open-ended**: greenfield asks only "what do you want to build?"; if the user
  isn't technical, *you* pick the stack (decide for them), state it, and move, the choice is yours to make.
- **Full-stack means both packs**: the classic failure is a polished UI on an unguarded backend; load
  the backend pack whenever auth/data/tenancy/billing are in scope.
- This sets up *knowledge*, not your repo's config, repo edits happen only as part of doing the task.
