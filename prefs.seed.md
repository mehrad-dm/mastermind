# Project preferences

Optional preferences, each with a default. MasterMind reads this file; edit a line here, or
just say it in chat ("reports on", "plan first from now on") and MasterMind updates the line for you.

- `cycle-report: off`: a written write-up at the end of a build/QA cycle.
  Values: `off` · `ask` · `markdown` · `html`. Defined by `skills/report/SKILL.md`.
- `plan-first: off`: on bigger tasks, show the plan and wait for your OK before editing.
  Values: `off` · `on`. Defined by `skills/build/SKILL.md`.
- `specs-dir: specs`: where specs, the constitution and the living docs are kept, from the repo root.
  Change it only when `specs/` already holds something else. Defined by `engineering/core/spec-driven.md`.

Anything else you write here is a note to yourself: only the keys above change behaviour.
