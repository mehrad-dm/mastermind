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
in `skills/README.md`. Full discipline: `skills/levelup/authoring.md`.

## Adding a field pack

Copy `engineering/fields/_template/` to `engineering/fields/<your-field>/` and fill in the
angle-brackets — it ships every file a pack needs (`field.md`, `stack-defaults.md`, `audit-rules.md`,
`mentors.md`, `curriculum.md`, `learning-sources.md`, `lessons.md`), each already carrying `route_when`
frontmatter. **Retag that frontmatter for your field; don't drop it** — the router serves only tagged
files, so an untagged file is invisible to the model. `field.md` is the one deliberate exception (it's
the pack's table of contents). `check-integrity.mjs` fails if a pack breaks either rule.
`engineering/fields/frontend/` is the reference implementation. The `levelup` skill can bootstrap and
research a pack for you.

## The one hard rule: never commit private data

MasterMind is public. Anything derived from a real, possibly-private codebase — client names, internal
patterns, proprietary code — stays in the **gitignored `lab/`** and only leaves it once every project,
product, and person name is stripped (*patterns, not identities*). The `.githooks/` guards block
commits that violate this, but the judgment is yours. See [SECURITY.md](SECURITY.md).

## Before you open a PR

1. **Run preflight — the one gate that must pass before anything ships:**

   ```bash
   ./scripts/preflight.sh
   ```

   It runs everything and exits non-zero if any of it fails: the installer suite, the
   design-engine tests, all shell parses, the router/library/integrity/link checks, that the
   version strings agree across the repo *and* the site, that the architecture map is fresh,
   and that the site builds. Add a check to `preflight.sh` the moment you find something a
   release should never ship without — it's the single answer to "did I test everything?".

   (The pre-commit hook still runs `check-integrity` + `build-router` on every commit for fast
   feedback; preflight is the full pre-release gate.)

2. **Keep it lean** — smaller, sharper diffs merge faster than big ones.
3. **Write a clear commit** — conventional style is appreciated (`feat(frontend): …`, `docs(core): …`).

## Testing a change

There's no build — the test is **behavioral**. Make the edit, run the assistant on a relevant task, and
confirm its behavior actually shifts the way you intended. If it doesn't, the wording is probably
ambiguous or buried — tighten it.

## Settled decisions — please don't relitigate

Each of these was argued once and decided. Reopening one needs a new argument, not a preference.

- **Per-project install is the default**; `--global` is opt-in.
- **The project always wins.** On a skill-name collision the user's file is never displaced: ours
  installs as `mastermind-<name>` and both work. If theirs is later removed, ours reclaims the plain
  name and the alias is pruned.
- **Skill descriptions state WHEN, never WHAT.** A description that summarizes its own workflow becomes
  a shortcut the model takes *instead of* reading the skill body.
- **Skills name actions, not tools** — this is what lets one body run on every harness.
- **Proportionality over ceremony.** We deliberately rejected maximalism (mandatory TDD,
  `<EXTREMELY-IMPORTANT>` shouting). Match effort to stakes.
- **Adopt patterns, never Claude-only machinery.** Workflow APIs, `/loop`, worktrees and friends stay
  optional accelerators, never dependencies.
- **Site docs are generated, never hand-written** — `scripts/build-library.mjs` builds them from
  `skills/*/ABOUT.md`, so a page cannot claim something the skill doesn't say.
- **Prose column stays 768px** on the site; navigation may span the full container. 🧠 stays a literal
  emoji in terminal lines; genuine UI uses the icon component.

## Gotchas — learned the hard way

Each of these cost real debugging time at least once. They're here so nobody rediscovers them.

**Shell (the installer targets bash 3.2 — what macOS ships):**

- `local a="$1" b="$a"` — `$a` expands **before** it's assigned. Split into two `local` statements.
- An empty array under `set -u` counts as unbound. Use `${ARR[@]+"${ARR[@]}"}`.
- `return` immediately after an arithmetic assignment returns 0: `COUNT=$((COUNT+1)); return` reports
  success no matter what. Use an explicit `return 1`.
- A trailing `[ x ] && cmd` as a function's **last** line can trip `set -e`. Use `if`.

**Consistency:**

- **Never bulk find-and-replace a version string.** Doing so once rewrote a comment recording *when*
  eval numbers were measured, silently relabelling old results as a new release's. Change each
  occurrence deliberately; `evals/` records history and must keep its original versions.
- **Never bulk-fix spelling from a partial word list.** A pass that declared "0 remaining" had left
  `memorise`, `licence`, `colour`, and `analyse` untouched.
- **Don't restate a count — derive or assert it.** Hardcoded totals ("17 skills") drift the moment one
  is added. `check-integrity.mjs` now fails on the ones we ship; keep it that way.
- **Always use `git -C <path>`.** A `cd` mistake once tagged and released on the *site* repo instead of
  this one.

**Site (`../mastermind-site`):**

- `pkill -f "astro preview"` never matches — the real process string is `astro.mjs preview`.
- `astro preview` binds **IPv6 only** (`[::1]:4321`); `127.0.0.1:4321` returns nothing. Use
  `http://localhost:4321`. If the port is taken it silently moves to 4322 — check the startup log.
- Fonts must be preloaded, and imported with `?url` so Astro resolves the **hashed** filename; a
  hardcoded path 404s silently on the next build.
- A Lighthouse 98 is a real defect, not noise. Read the failing audit before dismissing a 2-point drop.

**Evals:**

- **A subagent is not a clean baseline** — it inherits the brain from the session harness, so a
  "no MasterMind" control still emitted MasterMind's announce line. Park `~/.claude/CLAUDE.md` *and*
  `~/.claude/skills`, then run `claude -p` as a **separate process** from an empty directory. See
  `evals/README.md` → "Isolation".
