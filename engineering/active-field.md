# Active Field

MasterMind is **field-parameterized**: a universal core (how to think & work) plus a swappable
**field pack** (what to know & which tools) for the domain the user is working in.

## Current field: **Frontend Engineering** — level 2

- **Field pack:** `engineering/fields/frontend/` (see its `field.md` manifest).
- **Level:** 2. Bumped by the `mastermind-levelup` skill as lessons accumulate and standards are
  refreshed. See the field pack's `lessons.md` for what's been learned so far.

## Get ready for the task (onboarding)

Be ready for whatever the user is building — cheaply. At the start of substantive work:

1. **Detect the field from the project** — `package.json`/deps, configs, file types. Frontend app?
   Backend/API? Mobile? Infra? This is free and usually enough — don't ask if it's obvious.
2. **Ask only when ambiguous** — one short question: *"What are we building (frontend / backend /
   mobile / …) and on what stack?"* Don't interrogate; one question, then proceed.
3. **Load the matching pack** — if a `fields/<field>/` pack exists, use it. If not, offer to
   `mastermind-levelup --bootstrap <field>` (researches + generates it once), then use it.
4. **Token economy** — load only the active field's pack; never preload others. For full-stack work,
   load both packs but only the files each task needs (per the load-on-demand map).

## How to change the field

1. Ensure a pack exists at `engineering/fields/<name>/` with a `field.md` manifest (copy the
   frontend pack's shape: `stack-defaults`, `curriculum`, `mentors`, `learning-sources`, `lessons`).
   If it doesn't exist, run `mastermind-levelup --bootstrap <name>` to research and generate it.
2. Update the "Current field" line above to point at the new pack.
3. The universal core (`engineering/core/*`) never changes between fields — it's field-agnostic.

Multiple fields can be active at once (e.g. `Frontend + Backend`) for full-stack work; load both packs.

## How MasterMind levels up (honest mechanics)

An LLM's weights are fixed — "leveling up" means **editing this knowledge base**, which changes
behavior durably across all future sessions:

1. **Capture** — every correction the user gives, and every real finding from a `code-reviewer` pass,
   becomes a one-line entry in the active field's `lessons.md` (and, if it's a durable default, in
   `stack-defaults.md`). This is the primary learning channel — it compounds.
2. **Refresh** — periodically re-run the curriculum research (`mastermind-levelup --refresh`) so the
   field's best-practice list tracks the moving ecosystem; verify repos still exist/are active.
3. **Adapt to the user** — per-user preferences accumulate in the file-based memory system (separate
   infra); MasterMind recalls them by relevance. Field packs hold *domain* truth; memory holds *user*
   truth.
4. **Mark the level** — bump the level number above and log the change, so improvement is visible and
   reversible via git.
