# Contributing to MasterMind

Thanks for wanting to make MasterMind sharper. It's a **knowledge base, not code**: contributions are
edits to Markdown that make an AI assistant a better engineer. The bar is **signal density**: every
line is paid in context on every session, so a change must earn its place.

You don't need to be an expert in all of it. Pick one small thing and improve it.

## Ways to contribute

- **Fix or add a lesson**: a durable rule you learned from real usage goes in a field's `lessons.md`.
- **Add a skill**: a new, distinct workflow (see below).
- **Add or improve a field pack**: bring a domain MasterMind doesn't cover yet (backend, mobile, …).
- **Improve the docs**: anything confusing or out of date. If *you* were confused, others will be too.
- **Report a rough edge**: open an issue describing where MasterMind gave bad guidance and why.

## Quick start

```bash
git clone https://github.com/mehrad-dm/mastermind
cd mastermind

# Use it locally: symlink the repo to where tools look for the brain.
ln -s "$PWD" ~/.mastermind

# Enable the safety guards (they block accidental commits of private data, see below).
git config core.hooksPath .githooks
```

There's no build step and no dependencies: you edit Markdown and test behaviorally (below).

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

## House style: how we write

Two rules about the writing itself. Both are enforced, because both were broken repeatedly while
everyone agreed with them.

- **No em dashes. Anywhere.** Not in prose, code, comments, commit messages, changelog entries or
  the website. Use a colon when what follows explains what came before, a comma otherwise. It is
  the most reliable tell that a machine wrote the line. `scripts/check-prose.mjs` looks for the
  character, the JSON escape and the HTML entities, including inside fenced code blocks,
  because the announce line MasterMind prints is written in one. Two lines in `install.sh` are
  exempt on the record: uninstall matches that exact text to remove pointers written before
  0.31.3, so rewording it would strand our text in existing users' files.

- **Comments are rare, short, and explain why.** Never restate what the line does. If the reason
  needs a paragraph, it belongs in `CHANGELOG.md`, not above a guard. `scripts/check-comments.mjs`
  caps a comment block at five lines, ten for a file header, and reports files where comments run
  over 30% of the code as something to look at rather than a failure.

- **Never name who found a defect**, or that a review or audit happened, in anything public:
  commits, the changelog, code comments, the website. Say what broke and what it cost.

Both checks run in `preflight.sh`, in CI on every pull request, at the release gate, and in
`pre-push`. If a line genuinely needs an exemption, add it to the script with the reason attached,
so the exception is on the record rather than in someone's memory.

## A new check is proven both ways before it is wired in

The rule above about tests applies to checks too, and for the same reason: a check nobody has
watched fail is not known to work. Before wiring one into `preflight.sh` or CI:

- run it against the commit that carried the defect, and confirm it **fires**
- run it against the current tree, and confirm it is **clean**
- say how many things it flags on the current tree, and look at every one

That last step is the one that gets skipped. Both checks added recently flagged the wrong thing on
their first run: the comment limit counted a heredoc the installer writes into a user's file, and
the pipeline check flagged three dozen `printf | sed | head` lines where the exit status is
discarded. Neither was caught by a test. They were caught by reading the output.

A check that fires on the wrong thing is worse than no check, because people learn to skip it, and
then it is not there on the day it would have mattered.

## When a lesson repeats, it becomes a check

Notes do not run. Every rule in this repo that stayed prose has been broken again later, and every
one that became a gate has not. The em dash rule shipped three times before a check existed. The
`grep -q` under `pipefail` bug was found, fixed, written down, and then written straight back in
by the person who had fixed it.

So: **the second time a lesson is violated, it stops being a note and becomes a gate.** Not the
first, most mistakes are one-offs and a check for each would drown the real ones. The second time
is the signal that memory is not going to hold it.

Keep the gate narrow. `check-shell-patterns.mjs` flags `grep -q` downstream of a pipe and
deliberately ignores `head`, which is almost always harmless truncation: a check that fires on the
wrong thing teaches people to ignore it, which is worse than not having it.

## Adding a skill

The skill library grows freely: add one for any distinct, useful workflow. Hold the bar that keeps a
large library lean: **one job, an unambiguous routing-rule description, a lean on-demand body, and a
Gotchas section** (only what pushes the model off its defaults); don't duplicate an agent. Register it
in `skills/README.md`. Full discipline: `skills/levelup/authoring.md`.

## Adding a field pack

Copy `engineering/fields/_template/` to `engineering/fields/<your-field>/` and fill in the
angle-brackets: it ships every file a pack needs (`field.md`, `stack-defaults.md`, `audit-rules.md`,
`mentors.md`, `curriculum.md`, `learning-sources.md`, `lessons.md`), each already carrying `route_when`
frontmatter. **Retag that frontmatter for your field; don't drop it**: the router serves only tagged
files, so an untagged file is invisible to the model. `field.md` is the one deliberate exception (it's
the pack's table of contents). `check-integrity.mjs` fails if a pack breaks either rule.
MasterMind ships no field pack: only the scaffold at `engineering/fields/_template/`, and `init` builds one per project. The `levelup` skill can bootstrap and
research a pack for you.

## The one hard rule: never commit private data

MasterMind is public. Anything derived from a real, possibly-private codebase: client names, internal
patterns, proprietary code: stays in the **gitignored `lab/`** and only leaves it once every project,
product, and person name is stripped (*patterns, not identities*). The `.githooks/` guards block
commits that violate this, but the judgment is yours. See [SECURITY.md](SECURITY.md).

## Before you open a PR

1. **Run preflight: the one gate that must pass before anything ships:**

   ```bash
   ./scripts/preflight.sh
   ```

   It runs everything and exits non-zero if any of it fails: the installer suite, the
   design-engine tests, all shell parses, the router/library/integrity/link checks, that the
   version strings agree across the repo *and* the site, that the architecture map is fresh,
   and that the site builds. Add a check to `preflight.sh` the moment you find something a
   release should never ship without: it's the single answer to "did I test everything?".

   (The pre-commit hook still runs `check-integrity` + `build-router` on every commit for fast
   feedback; preflight is the full pre-release gate.)

2. **If you fixed a bug, prove the test would have caught it.**

   ```bash
   scripts/prove-regression.sh v0.30.1        # or whichever release had the defect
   ```

   A test written after a fix passes against that fix by construction, so on its own it tells you
   nothing. Point it at the release that shipped the bug: if the new assertion does not fail
   there, it is not testing the bug. Four audits in a row found real defects while this suite was
   green, which is what the rule is for.

3. **How changes reach `master`.**

   Branch, pull request, let the checks run, merge:

   ```bash
   git checkout -b fix/whatever
   git push -u origin fix/whatever
   gh pr create --fill
   gh pr merge --auto --squash
   ```

   `master` requires a pull request and four green checks, with no approval required, so you are
   never waiting on yourself. The reason for the PR is not ceremony: users run `master` directly
   (`~/.mastermind` is a clone of it), so CI has to run before code lands there, not after.

   `pre-push` runs the suites locally whenever the push touches `install.sh`, `cli/`, `bin/`,
   `tests/`, `hooks/` or `scripts/`. `MM_SKIP_TESTS=1 git push` skips it and says so.

   Releasing is a separate process: see [RELEASING.md](RELEASING.md).

   **What preflight cannot tell you:** every check above inspects *files*, that the right
   things landed in the right place. None of them starts an agent, so none proves a tool
   actually loads the brain. `scripts/verify-tools.sh` does: it installs into a throwaway
   project, asks a real Cursor/Codex session whether it is running as MasterMind, and fails if
   the answer is no. It needs each tool's CLI and a logged-in account, so it stays a local
   command rather than a CI gate, and skips whatever isn't installed. Run it when you change
   anything about how a tool is wired: `.cursor/rules`, `hooks.json`, `AGENTS.md`.

2. **Keep it lean**: smaller, sharper diffs merge faster than big ones.
3. **Write a clear commit**: conventional style is appreciated (`feat(install): …`, `docs(core): …`).

## Testing a change

There's no build: the test is **behavioral**. Make the edit, run the assistant on a relevant task, and
confirm its behavior actually shifts the way you intended. If it doesn't, the wording is probably
ambiguous or buried: tighten it.

## Settled decisions: please don't relitigate

Each of these was argued once and decided. Reopening one needs a new argument, not a preference.

- **Per-project install is the default**; `--global` is opt-in.
- **The project always wins.** On a skill-name collision the user's file is never displaced: ours
  installs as `mastermind-<name>` and both work. If theirs is later removed, ours reclaims the plain
  name and the alias is pruned.
- **Skill descriptions state WHEN, never WHAT.** A description that summarizes its own workflow becomes
  a shortcut the model takes *instead of* reading the skill body.
- **Skills name actions, not tools**: this is what lets one body run on every harness.
- **Proportionality over ceremony.** We deliberately rejected maximalism (mandatory TDD,
  `<EXTREMELY-IMPORTANT>` shouting). Match effort to stakes.
- **Adopt patterns, never Claude-only machinery.** Workflow APIs, `/loop`, worktrees and friends stay
  optional accelerators, never dependencies.
- **Site docs are generated, never hand-written**: `scripts/build-library.mjs` builds them from
  `skills/*/ABOUT.md`, so a page cannot claim something the skill doesn't say.
- **Prose column stays 768px** on the site; navigation may span the full container. 🧠 stays a literal
  emoji in terminal lines; genuine UI uses the icon component.

## Gotchas: learned the hard way

Each of these cost real debugging time at least once. They're here so nobody rediscovers them.

**Shell (the installer targets bash 3.2: what macOS ships):**

- `local a="$1" b="$a"`: `$a` expands **before** it's assigned. Split into two `local` statements.
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
- **Don't restate a count: derive or assert it.** Hardcoded totals ("17 skills") drift the moment one
  is added. `check-integrity.mjs` now fails on the ones we ship; keep it that way.
- **Always use `git -C <path>`.** A `cd` mistake once tagged and released on the *site* repo instead of
  this one.

**Site (`../mastermind-site`):**

- `pkill -f "astro preview"` never matches: the real process string is `astro.mjs preview`.
- `astro preview` binds **IPv6 only** (`[::1]:4321`); `127.0.0.1:4321` returns nothing. Use
  `http://localhost:4321`. If the port is taken it silently moves to 4322, check the startup log.
- Fonts must be preloaded, and imported with `?url` so Astro resolves the **hashed** filename; a
  hardcoded path 404s silently on the next build.
- A Lighthouse 98 is a real defect, not noise. Read the failing audit before dismissing a 2-point drop.

**Evals:**

- **A subagent is not a clean baseline**: it inherits the brain from the session harness, so a
  "no MasterMind" control still emitted MasterMind's announce line. Park `~/.claude/CLAUDE.md` *and*
  `~/.claude/skills`, then run `claude -p` as a **separate process** from an empty directory. See
  `evals/README.md` → "Isolation".
