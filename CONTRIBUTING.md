# Contributing to MasterMind

Thanks for wanting to make MasterMind sharper. It's a **knowledge base, not code** — contributions are
edits to Markdown that make an AI assistant a better engineer. The bar is **signal density**: every
line is paid in context on every session, so a change must earn its place.

You don't need to be an expert in all of it. Pick one small thing and improve it.

## Ways to contribute

- **Fix or add a lesson** — a durable rule you learned from real usage goes in a field's `lessons.md`.
- **Add a skill** — a new, distinct workflow (see below).
- **Add or improve a field pack** — bring a domain MasterMind doesn't cover yet (backend, mobile, …).
- **Improve the docs** — anything confusing or out of date. If *you* were confused, others will be too.
- **Report a rough edge** — open an issue describing where MasterMind gave bad guidance and why.

## Quick start

```bash
git clone https://github.com/mehrad-dm/mastermind
cd mastermind

# Use it locally: symlink the repo to where tools look for the brain.
ln -s "$PWD" ~/.mastermind

# Enable the safety guards (they block accidental commits of private data — see below).
git config core.hooksPath .githooks
```

There's no build step and no dependencies — you edit Markdown and test behaviorally (below).

## Principles for edits

- **Encode judgment, not knowledge.** Don't add what a frontier model already knows (language syntax,
  standard APIs). Add defaults, decisions, rigor, taste, and lessons.
- **Keep it light.** Ask of each line: *"Would removing this cause the assistant to make a mistake?"*
  If not, cut it. A bloated kernel gets ignored.
- **Core vs. field.** Universal reasoning goes in `engineering/core/`. Domain specifics go in a field
  pack under `engineering/fields/<field>/`. Never leak field specifics into the core.
- **Convention vs. correctness.** When encoding a rule, separate house-style (*conform to it*) from a
  real defect (*flag it, with a primary-source citation and a concrete failure*). Don't dress up a
  preference as a bug.
- **Cite and verify.** For a repo/tool/authority, prefer primary sources and verify it exists and is
  active. Don't bluff.
- **Lessons are earned.** New entries in a field's `lessons.md` come from real usage or a code-review
  finding, with the "why" attached.

## Adding a skill

The skill library grows freely — add one for any distinct, useful workflow. Hold the bar that keeps a
large library lean: **one job, an unambiguous routing-rule description, a lean on-demand body, and a
Gotchas section** (only what pushes the model off its defaults); don't duplicate an agent. Register it
in `skills/README.md`. Full discipline: `levelup` → "Authoring a new skill".

## Adding a field pack

Copy the shape of `engineering/fields/frontend/` (`field.md`, `stack-defaults.md`, `mentors.md`,
`curriculum.md`, `learning-sources.md`, `lessons.md`). Tag any file the router should serve with
`route_when` frontmatter. The `levelup` skill can bootstrap and research a pack for you.

## The one hard rule: never commit private data

MasterMind is public. Anything derived from a real, possibly-private codebase — client names, internal
patterns, proprietary code — stays in the **gitignored `lab/`** and only leaves it once every project,
product, and person name is stripped (*patterns, not identities*). The `.githooks/` guards block
commits that violate this, but the judgment is yours. See [SECURITY.md](SECURITY.md).

## Before you open a PR

1. **Run the checks** (the pre-commit hook runs these too):

   ```bash
   node scripts/check-integrity.mjs   # indexes & cross-references are consistent
   node scripts/build-router.mjs      # regenerate ROUTER.md if you added/changed routed files
   ```

2. **Keep it lean** — smaller, sharper diffs merge faster than big ones.
3. **Write a clear commit** — conventional style is appreciated (`feat(frontend): …`, `docs(core): …`).

## Testing a change

There's no build — the test is **behavioral**. Make the edit, run the assistant on a relevant task, and
confirm its behavior actually shifts the way you intended. If it doesn't, the wording is probably
ambiguous or buried — tighten it.
