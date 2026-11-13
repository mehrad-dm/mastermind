# Active Field

MasterMind is **field-parameterized**: a universal core (how to think & work) plus a swappable
**field pack** (what to know & which tools) for the domain this project is in.

## Current field: **none yet**

- **Field pack:** _none_, this project has no field pack yet.
- **Level:** 0.

Nothing is pre-loaded on purpose. A pack built for someone else's stack is worse than no pack: it
carries dead weight, misses what actually matters here, and quietly nudges the model toward defaults
this project never chose. So MasterMind ships the **scaffold**, not the content.

## Get a field: say `init`

With no field pack, MasterMind tells you in one line and offers `init`. It does not run `init` unasked,
and it carries on with your task on the universal core. Once you say yes, `init` reads the stack from
the project itself and builds the pack from `fields/_template/` with no questions: its defaults, its
actual pitfalls, its review rules. It is a **one-time** setup, reused for every task.

You can also do it by hand:

```bash
cp -r engineering/fields/_template engineering/fields/<name>
# fill in each file, then point "Current field" above at it
```

Or bootstrap it: `levelup bootstrap <name>` researches and generates the pack from the template.

## Keep it lean: that's where the lift comes from

A pack must fit **one real stack, not grow into a generic superset**. Tailoring **prunes as much as
it adds**; a pack that only accumulates is a bug. When the stack drifts, prune what no longer applies
and add what's missing (via `levelup`): or switch fields. Multiple packs can be active at once for
full-stack work.

## Once you have one

- **Capture**: `levelup` records a correction or a real review finding as a one-line entry in the
  pack's `lessons.md` (durable defaults go to `stack-defaults.md`). It runs only when there is a lesson
  to record, and it never bumps the level.
- **Refresh**: `levelup refresh` re-runs the curriculum research so the pack tracks the ecosystem.
- **Mark the level**: `levelup refresh` and `levelup bootstrap <field>` bump the level above and log
  what changed, so improvement is visible in git.

Fields belong to this project. An update to MasterMind never rewrites, refreshes, or retires a pack
you have built here.
