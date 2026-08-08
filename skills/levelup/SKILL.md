---
name: levelup
description: Use after a correction or review finding worth remembering, when standards may have drifted from the live ecosystem, when switching MasterMind to a new domain or stack, or when the user says "remember this", "learn from that", "so you don't repeat it", "don't make that mistake again", "level up", "update your knowledge".
---

# MasterMind: Level Up

MasterMind improves by **editing its own knowledge base** (its weights are fixed). This skill is the
disciplined loop that does it. Read `~/.mastermind/engineering/active-field.md` first to know the active
field and its pack path (`engineering/fields/<field>/`).

## Pick exactly one mode

Take the mode from the argument; default to **capture**. **Do one mode per run**: they touch different
files under different rules, and blending them is how a lesson lands in the wrong file.

| Mode | Trigger | Read |
| --- | --- | --- |
| **`capture`** (default) | a correction, review finding, or bug worth remembering | below. It's the whole job |
| **`refresh`** | standards may have drifted from the live ecosystem | `refresh.md` **before writing anything**: it carries the upstream-only write allowlist |
| **`bootstrap <field>`** | a new domain or stack with no pack | `bootstrap.md` |

Adding or rewriting a **skill or agent** is not a mode. It's a separate discipline: read `authoring.md`.

## Two memory layers: the episode, then the lesson

- **`.mastermind/journal.md`, what happened** (episodic). Dated one-liners appended at each verdict:
  the decision, the reason, the outcome. Cheap, append-only, and the project's own file.
- **`fields/<field>/lessons.md`, what to do next time** (semantic). Distilled *from* the journal.

Keeping both is what lets MasterMind say *"we tried that in March and it failed because X"*: a lesson
alone states a rule but can no longer justify it, so it gets argued with or quietly dropped. The journal
is the evidence behind the rule; distil it forward and let the old entries age out.

## `capture` (default): harvest lessons from this session/recent work

1. Read the **`· wrong ·`** lines of `.mastermind/journal.md` before anything else (`mastermind
   wrong-log`). A miss with its catcher named is the highest-signal lesson there is, it already
   states the rule that was missing. Then read the rest of the journal and scan recent work for
   durable generalizable lessons:
   user corrections ("no, do X"), real `code-reviewer` findings, bugs fixed, and choices that proved
   right. The journal is the higher-signal source. It is what actually happened, already dated and
   deduplicated. Skip one-off/project-specific noise; keep only what applies to *future* tasks.
2. For each: append a one-line rule + bracketed "why" to
   `~/.mastermind/engineering/fields/<field>/lessons.md`. Deduplicate against existing lessons.
3. If a lesson is a general default (not just a gotcha), **promote** it into `stack-defaults.md` at the
   right section. That's where it will actually change behavior.
4. Keep it tight. A lesson that isn't load-bearing is noise; keep only what earns its place.

`capture` is the one mode that may run on a user's install and stay local; it writes only to that field's
`lessons.md` and `stack-defaults.md`.

## Guardrail: keep MasterMind lean (token economy)

Every line is paid in context on every future session, so leveling up must *net* toward leaner, not
heavier. On each change:

- **Only load-bearing lines survive.** For each line ask *"would removing it change behavior?"*: if
  not, cut it. Prefer a sharper sentence over a longer one, a rule over an example, a pointer over a copy.
- **Kernel stays tiny.** New depth goes into on-demand modules/field packs, leaving the always-loaded
  `CLAUDE.md` as-is. Deduplicate: one idea, one home (SSOT); cross-link instead of repeating.
- **Net-zero-or-lighter.** When you add, hunt for something stale to remove; retire superseded
  lessons/resources rather than stacking them. Signal density beats volume: a bloated brain gets ignored.

## Always, after any mode

- **Bump the level** and log the change in `active-field.md` (increment the level number; add a dated
  one-line changelog entry describing what leveled up).
- **Show what changed**: list the files you actually wrote. For `refresh`, check that list against its
  write allowlist before claiming done.
- Report to the user what was learned/changed in 2–3 lines. Improvement must be visible.
- If `~/.mastermind/engineering/` is a git repo, the change is now diffable and reversible, mention it.
