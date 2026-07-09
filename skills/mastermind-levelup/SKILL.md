---
name: mastermind-levelup
description: Level MasterMind up — capture lessons from recent work into the active field pack, refresh the field's best-practice curriculum against the live ecosystem, or bootstrap a whole new field pack. Invoke after a review/correction, periodically to refresh standards, or when switching MasterMind to a new field.
---

# MasterMind — Level Up

MasterMind improves by **editing its own knowledge base** (its weights are fixed). This skill is the
disciplined loop that does it. Read `~/.mastermind/engineering/active-field.md` first to know the active
field and its pack path (`engineering/fields/<field>/`).

Pick the mode from the argument; default to **capture**.

## `capture` (default) — harvest lessons from this session/recent work

1. Scan the recent work for durable, generalizable lessons: user corrections ("no, do X"), real
   `code-reviewer` findings, bugs fixed, and choices that proved right. Ignore one-off/project-specific
   noise — only keep what will apply to *future* tasks.
2. For each: append a one-line rule + bracketed "why" to `fields/<field>/lessons.md`. Deduplicate
   against existing lessons.
3. If a lesson is a general default (not just a gotcha), **promote** it into `stack-defaults.md` at the
   right section — that's where it will actually change behavior.
4. Keep it tight. A lesson that isn't load-bearing is noise; don't hoard.

## `refresh` — track the moving ecosystem

1. Re-run the curriculum research for the active field (the same multi-angle, verify-each-repo sweep
   that built `curriculum.md`): best repos/courses/people/docs, current, each GitHub repo checked
   against the API for existence + recent activity.
2. Diff against the current `curriculum.md`: add what's newly best-in-class, drop what's archived/dead,
   flag anything that changed. Update `learning-sources.md` and `mentors.md` if authorities shifted.
3. Note the refresh date in `curriculum.md`'s verification note.
4. **Listen to the source of truth for agent engineering** — Anthropic / Claude Code docs, the
   engineering blog, and ClaudeDevs — for evolving best practices (prompting, model/effort, skills,
   context management). Fold the *durable* ones into `core/` or the skill-authoring discipline; verify
   against the primary source, and adopt the judgment, not the hype.

## `bootstrap <field>` — create a new field pack

1. Create `engineering/fields/<field>/` with the same shape as the frontend pack: `field.md`,
   `stack-defaults.md`, `mentors.md`, `curriculum.md`, `learning-sources.md`, `lessons.md`.
2. Research the field (the verified sweep) to populate `curriculum.md`/`mentors.md`/`learning-sources.md`,
   and write opinionated `stack-defaults.md` for it. Start `lessons.md` empty.
3. Do NOT touch `engineering/core/*` — it's field-agnostic and shared.

## Guardrail: keep MasterMind lean (token economy)

Every line is paid in context on every future session, so leveling up must *net* toward leaner, not
heavier. On each change:

- **Only load-bearing lines survive.** For each line ask *"would removing it change behavior?"* — if
  not, cut it. Prefer a sharper sentence over a longer one, a rule over an example, a pointer over a copy.
- **Kernel stays tiny.** New depth goes into on-demand modules/field packs, never the always-loaded
  `CLAUDE.md`. Deduplicate — one idea, one home (SSOT); cross-link instead of repeating.
- **Net-zero-or-lighter.** When you add, hunt for something stale to remove; retire superseded
  lessons/resources rather than stacking them. Signal density beats volume — a bloated brain gets ignored.

## Authoring a new skill

The library grows freely — add a skill for any distinct, useful workflow. But hold the quality bar that
keeps a large library lean and navigable (the lesson from the best skill kits):

- **One job.** The mega-skill (commits + PRs + changelog + …) is the top mistake. Split it.
- **Description = a routing rule** — specific enough that it activates at exactly the right moment, and
  not otherwise. **Unambiguous:** if a human can't say which skill applies, neither can the agent.
- **Only what pushes away from defaults.** Don't restate what the model already does well; the
  highest-signal part is a **Gotchas** section — the failure points it hits *without* the skill. (Anthropic.)
- **Lean body, detail on demand** — core instructions fit on a phone screen; push edge cases into
  companion files that load only when needed.
- **Don't duplicate an agent** — review, architecture, refactor, adopt-decisions are agents (isolated
  context). Skills are for inline workflows.
- **Deterministic work → deterministic code** (`core/agent-loop.md`) — script it, don't narrate it.
- Mark **user-invoked** (`disable-model-invocation: true`) vs model-invoked, and add the skill to
  `skills/README.md` so the index stays honest.

## Always, after any mode

- **Bump the level** and log the change in `active-field.md` (increment the level number; add a dated
  one-line changelog entry describing what leveled up).
- Report to the user what was learned/changed in 2–3 lines. Improvement must be visible.
- If `~/.mastermind/engineering/` is a git repo, the change is now diffable and reversible — mention it.
