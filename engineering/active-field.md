# Active Field

MasterMind is **field-parameterized**: a universal core (how to think & work) plus a swappable
**field pack** (what to know & which tools) for the domain the user is working in.

## Current field: **Frontend Engineering** — level 4

- **Field pack:** `engineering/fields/frontend/` (see its `field.md` manifest).
- **Level:** 4. Bumped by the `mastermind-levelup` skill as lessons accumulate and standards are
  refreshed. See the field pack's `lessons.md` for what's been learned so far.

### Level history

- **level 4** (2026-07-10) — added a **UI/UX design-intelligence** capability: vendored the third-party
  `ui-ux-pro-max` skill (MIT, NextLevelBuilder — searchable styles/palettes/font-pairings/UX-guidelines/
  charts across stacks) into `skills/`, registered it in the skills index, and pointed the frontend
  field pack at it (design *what* ↔ field-pack/rigor *how*). Sourced while overhauling the Playlist
  Telegram Mini App to an Apple/Spotify-grade bar.
- **level 3** — stack-defaults deepened & made explicitly adaptive: "adapt-to-project, never impose"
  posture; Core Web Vitals performance section; components (primitives vs kits); client-state/forms/
  routing/animation/API-codegen/monorepo/PWA/monitoring defaults (covering real production stacks);
  captured signature patterns from Total TypeScript, Epic React, and *Just JavaScript* (verified free
  primary sources). Ask-first testing policy; version/primary-source discipline; `mastermind-verify` skill.
- **level 2** — frontend field pack populated (`stack-defaults`, `curriculum`, `mentors`,
  `learning-sources`, `lessons`); core loop, skills, and agents wired.
- **level 1** — initial kernel + universal core (mindset · principles · rigor · agent-loop · product-sense).

## Get ready for the task (onboarding)

Be ready for whatever the user is building — cheaply. At the start of substantive work:

1. **Detect the field from the project** — `package.json`/deps, configs, file types. Frontend app?
   Backend/API? Mobile? Infra? This is free and usually enough — don't ask if it's obvious.
2. **Ask only when ambiguous** — one short question: *"What are we building (frontend / backend /
   mobile / …) and on what stack?"* Don't interrogate; one question, then proceed.
3. **Load the matching pack** — if a `fields/<field>/` pack exists, use it. If not, offer to
   `mastermind-levelup --bootstrap <field>` (researches + generates it once), then use it.
4. **Token economy** — load only the active field's pack; never preload others. For full-stack work,
   load each field's pack — but only the **frontend** pack ships today; bootstrap the others (e.g.
   backend) on demand, loading only the files each task needs (per the load-on-demand map).

## How to change the field

1. Ensure a pack exists at `engineering/fields/<name>/` with a `field.md` manifest (copy the
   frontend pack's shape: `field.md` (the manifest), `stack-defaults`, `curriculum`, `mentors`,
   `learning-sources`, `lessons`).
   If it doesn't exist, run `mastermind-levelup --bootstrap <name>` to research and generate it.
2. Update the "Current field" line above to point at the new pack.
3. The universal core (`engineering/core/*`) never changes between fields — it's field-agnostic.

Multiple fields can be active at once (e.g. `Frontend + Backend`) for full-stack work — load each pack
you need. Today only the **frontend** pack ships; bootstrap a backend pack
(`mastermind-levelup --bootstrap backend`) before relying on it.

## How MasterMind levels up (honest mechanics)

An LLM's weights are fixed — "leveling up" means **editing this knowledge base**, which changes
behavior durably across all future sessions:

1. **Capture** — every correction the user gives, and every real finding from a `code-reviewer` pass,
   becomes a one-line entry in the active field's `lessons.md` (and, if it's a durable default, in
   `stack-defaults.md`). This is the primary learning channel — it compounds.
2. **Refresh** — periodically re-run the curriculum research (`mastermind-levelup --refresh`) so the
   field's best-practice list tracks the moving ecosystem; verify repos still exist/are active.
3. **Adapt to the user** — where your assistant has a memory (e.g. Claude Code's file-based memory),
   per-user preferences accumulate there and MasterMind recalls them by relevance; where there's no
   memory, this channel is simply skipped. Field packs hold *domain* truth; memory holds *user* truth.
4. **Mark the level** — bump the level number above and log the change, so improvement is visible and
   reversible via git.
