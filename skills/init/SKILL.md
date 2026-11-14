---
name: init
description: "Use when the user asks to set MasterMind up for this project: \"init\", \"initialize\", \"set up MasterMind\", \"get me ready\", or a yes to the setup offer. Builds the field pack for the project's real stack. Never run unasked: with no field pack, offer it on the first announce line and carry on with the task."
---

# Initialize: get MasterMind ready for this project, fast

**Nothing ships pre-baked.** A fresh install carries only the engine and `engineering/fields/_template/`,
because a pack tuned to someone else's stack is worse than none. This skill builds this project's field
from the template, tuned to the real stack. Run it **once per project**; if this project already built
a field that fits, load it and stop.

## The field-setup rule (stated here once)

- **With no field pack, end the first task's announce line with "no field pack yet: say init to build one".**
  Do not run it unasked.
- **Carry on with the task on the universal core.** The offer never blocks the work.
- **Under a shared or global brain, say so in the offer.** The pack is then written in the user's home
  directory, outside the project, which the kernel's Ask-before rule covers. Their yes to that offer is
  the approval.
- **Once the user says yes, ask nothing.** Detect the stack, make the technical calls, build the pack.
  There are no closing preference questions.

The offer rides on the announce line: *"🧠 MasterMind ▸ fixing the login redirect, no field pack yet: say
init to build one"*. Under a shared or global brain, add: *"(the pack goes in your home directory)"*.

## Path A: the project already has code

1. **Detect the stack**: `package.json`/lockfile, configs, framework + versions, DB, test runner, folder
   shape (`core/agent-loop.md`). Read it from the project.
2. **Build the field** from `engineering/fields/_template/`, tuned to the detected stack
   (`levelup bootstrap <field>` has the research steps). Fit **one real stack**, and keep it lean:
   tailoring **prunes as much as it adds** (`active-field.md`).
3. **Fill the pack's "Where things are" section** from what step 1 detected: the half-dozen entry-point
   pointers (components, routes, state, tests + run command, config, the one file that explains the
   architecture fastest). These few pointers stop every future task from re-running discovery.
4. **Point `active-field.md` at the pack:** its `## Current field:` line names the pack, its **Level:** is 1.
   Then deliver it to every wired tool, offline:
   `.mastermind/bin/mastermind sync` for a per-project brain, the default, or
   `~/.mastermind/bin/mastermind sync` under a shared or global brain. It regenerates the router,
   writes the Cursor field rule and refreshes monorepo route anchors. The user re-runs nothing. If
   that command is missing, run the brain's `scripts/build-router.mjs` with node (in `.mastermind/`, or
   `~/.mastermind/` under a shared or global brain) and say Cursor waits for the next install.
5. **Fill the project brief** (`.mastermind/brief.md`). An isolated install seeds it; under a shared
   brain there is no project brain, so create the file at that path. The field pack holds the stack;
   the brief holds *this* project: what it is, the words it uses, what breaks and who feels it, what
   cannot be undone here, how it ships. Write what the code shows. Mark a line the code cannot settle
   as `unconfirmed`. **Keep it under about 40 lines**: it is read every session.
6. **Respect the project**: match its conventions and keep the stack it already chose.

## Path B: greenfield (empty folder, nothing built yet)

There is nothing to detect, so take what to build from what the user has already said.

- **They named the tech** (a framework, language, database): use it.
- **They only described the product**: choose the architecture and stack that best fit it, and state
  the choice with a one-line why: *"I'll build this as Next.js + Postgres: best fit for a realtime
  habit tracker."*
- **They have said nothing about what to build**: there is no stack to build a pack for. Say that in
  one line. Build the pack when the first task names the product.

Then set up the field pack(s) for that stack. A real app needs **frontend and backend**: UI *and*
auth, tenancy, data, jobs. Hand to `build` for the first slice.

## The first result comes before setup finishes

When the user has a task waiting, start it on general judgment and build the pack after the first
slice: a multi-minute research detour waits its turn behind their first working result.

## Show the plan as you start

Building a field lands real files, so show what you read and what you will build, in a few lines, and
proceed. This announces; it does not ask. It catches the one failure worth catching: a wrong stack
reading becoming a pack that is subtly wrong about everything.

```text
Detected: Next.js 15 · React 19 · TypeScript · Postgres/Prisma · Vitest
Building a `frontend` field with: stack defaults for this exact combination ·
review rules for React 19 · an empty lessons file that fills as we work.
```

**Store only what can't be re-derived**, plus the pack's few "Where things are" pointers. Skip the full
directory listing and the dependency list: the model can read those any time. Keep the pitfalls, the
non-obvious conventions, and the decisions someone would otherwise have to rediscover.

## End with a short report

Both paths finish with a report of about five lines, then go straight into the user's task:

```
▸ MasterMind ready
  stack:       Next.js 15 · React 19 · Postgres/Prisma   (detected)
  fields:      frontend + backend (built from _template for your stack)
  conventions: matched your existing style
  prefs:       cycle-report off · plan-first off (say "reports on" or "plan first from now on")
```

The two preferences default to **off** and are not asked about. `.mastermind/prefs.md` holds them,
seeded by an isolated install; `skills/build/SKILL.md` (plan-first gate) and `skills/report/SKILL.md`
(`cycle-report` values) define them. The user turns either on by saying so, at any time.

## Gotchas

- **Run once per project**: check for a matching field pack first, and load it if one is already there.
- **Full-stack means both packs**: the classic failure is a polished UI on an unguarded backend. Load
  the backend pack whenever auth, data, tenancy or billing are in scope.
- This sets up *knowledge*, not the repo's config. Repo edits happen only as part of doing the task.
