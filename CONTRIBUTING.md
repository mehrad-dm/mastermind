# Contributing to MasterMind

MasterMind is a knowledge base, not code — contributions are edits to Markdown that make an AI
assistant a better engineer. The bar is **signal density**: every line is paid in context on every
session, so a change must earn its place.

## Principles for edits

- **Encode judgment, not knowledge.** Don't add what a frontier model already knows (language syntax,
  standard APIs). Add defaults, decisions, rigor, taste, and lessons.
- **Keep it light.** Ask of each line: *"Would removing this cause the assistant to make a mistake?"*
  If not, cut it. A bloated kernel gets ignored.
- **Core vs. field.** Universal reasoning goes in `engineering/core/`. Domain specifics go in a field
  pack under `engineering/fields/<field>/`. Never leak field specifics into the core.
- **Cite and verify.** For a repo/tool/authority, prefer primary sources and verify it exists and is
  active. Don't bluff.
- **Lessons are earned.** New entries in a field's `lessons.md` should come from real usage or a
  code-review finding, with the "why" attached.

## Adding a field pack

Copy the shape of `engineering/fields/frontend/` (`field.md`, `stack-defaults.md`, `mentors.md`,
`curriculum.md`, `learning-sources.md`, `lessons.md`). The `mastermind-levelup` skill can bootstrap and
research one for you.

## Adding a skill

The skill library grows freely — add one for any distinct, useful workflow. Hold the bar that keeps a
large library lean: **one job, an unambiguous routing-rule description, a lean on-demand body, and a
Gotchas section** (only what pushes the model off its defaults); don't duplicate an agent. Register it in
`skills/README.md`. Full discipline: `mastermind-levelup` → "Authoring a new skill".

## Testing a change

There's no build — the test is behavioral. Make the edit, run the assistant on a relevant task, and
confirm its behavior actually shifts the way you intended. If it doesn't, the wording is probably
ambiguous or buried.
