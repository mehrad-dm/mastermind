---
name: levelup
description: "Use when the user asks MasterMind to remember a lesson or refresh its standards: \"remember this\", \"learn from that\", \"so you don't repeat it\", \"don't make that mistake again\", \"level up\", \"update your knowledge\", when switching to a new stack's field pack, or when another skill sends you here with a durable lesson to record."
---

# MasterMind: Level Up

MasterMind improves by **editing its own knowledge base** (its weights are fixed). This skill is the
disciplined loop that does it. Read `~/.mastermind/engineering/active-field.md` first to know the active
field and its pack path (`engineering/fields/<field>/`).

## Pick exactly one mode

Take the mode from the argument; default to **capture**. **Do one mode per run**: they touch different
files under different rules, and blending them is how a lesson lands in the wrong file.

| Mode | Written as | Trigger | Read |
| --- | --- | --- | --- |
| **capture** (default) | `levelup` | a correction, review finding, or bug worth remembering | below. It's the whole job |
| **refresh** | `levelup refresh` | standards may have drifted from the live ecosystem | `refresh.md` **before writing anything**: it carries the upstream-only write allowlist |
| **bootstrap** | `levelup bootstrap <field>` | a new domain or stack with no pack | `bootstrap.md` |

**Capture runs only when there is a lesson to record.** A cycle that taught nothing durable writes
nothing, and a skill that sends you here with no lesson is answered with "nothing to capture".

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
   Under a shared or global brain that file is in the home directory, outside the project: name the
   file and get a yes before the first write (kernel → Ask before).
3. If a lesson is a general default (not just a gotcha), **promote** it into `stack-defaults.md` at the
   right section. That's where it will actually change behavior.
4. Keep it tight. A lesson that isn't load-bearing is noise; keep only what earns its place.
5. **A mechanical lesson becomes a check, not a sentence.** When the mistake is detectable by a script,
   lint rule, hook or test, propose that check to the user alongside the lesson line. A rule that
   stays prose gets broken again.

`capture` is the one mode that may run on a user's install and stay local; it writes only to that field's
`lessons.md` and `stack-defaults.md`. It never bumps the level and never edits `active-field.md`.

## Guardrail: keep MasterMind lean (token economy)

Every line is paid in context on every future session, so leveling up must *net* toward leaner, not
heavier. On each change:

- **Only load-bearing lines survive.** For each line ask *"would removing it change behavior?"*: if
  not, cut it. Prefer a sharper sentence over a longer one, a rule over an example, a pointer over a copy.
- **Kernel stays tiny.** New depth goes into on-demand modules/field packs, leaving the always-loaded
  `CLAUDE.md` as-is. Deduplicate: one idea, one home (SSOT); cross-link instead of repeating.
- **Net-zero-or-lighter.** When you add, hunt for something stale to remove; retire superseded
  lessons/resources rather than stacking them. Signal density beats volume: a bloated brain gets ignored.

## After a mode

- **After `refresh` or `bootstrap`, bump the level** in `active-field.md`: increment the number and add
  a dated one-line entry saying what leveled up. `capture` does not bump it.
- **Show what changed**: list the files you actually wrote. For `refresh`, check that list against its
  write allowlist before claiming done.
- Report to the user what was learned or changed in two or three lines.
- If `~/.mastermind/engineering/` is a git repo, the change is diffable and reversible: mention it.
