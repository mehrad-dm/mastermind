# Project preferences

Two optional preferences, both **off** by default. MasterMind reads this file; edit a line here, or
just say it in chat ("reports on", "plan first from now on") and MasterMind updates the line for you.

- `cycle-report: off`: a written write-up at the end of a build/QA cycle.
  Values: `off` · `ask` · `markdown` · `html`. Defined by `skills/report/SKILL.md`.
- `plan-first: off`: on bigger tasks, show the plan and wait for your OK before editing.
  Values: `off` · `on`. Defined by `skills/build/SKILL.md`.

Anything else you write here is a note to yourself: only the two keys above change behaviour.
