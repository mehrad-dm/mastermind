# Changelog

Notable changes to MasterMind. Format follows [Keep a Changelog](https://keepachangelog.com/).
MasterMind is **experimental** and pre-1.0, so minor versions may change behavior. Full commit
history lives in git.

## [0.27.0] — 2026-07-24

No field pack ships pre-baked anymore. A fresh install carries the engine and
`engineering/fields/_template/` — nothing else — and `init` builds the project's field for its
*real* stack. A pack tuned to someone else's stack was always worse than none: dead weight that
misleads the model toward defaults the project never chose. This makes "the project owns its field"
literally true.

### Changed

- **No field ships, and none lives in the repo anymore.** `engineering/fields/frontend/` was removed
  entirely — the vendored `ui-ux-pro-max` design database, `web-animations`, `improve-ui`, and the field
  knowledge. Only `engineering/fields/_template/` remains. `init` detects the stack and builds the field
  from the template (its defaults, real pitfalls, review rules), then points `active-field.md` at it. The
  design database was MIT-vendored and re-obtainable; the design-engine characterization suite (a preflight
  check) went with it, so the release gate is now 9 checks, not 10.
- **`active-field.md` and `ROUTER.md` are now project-owned, not engine.** Both are *derived* from the
  project's own field, so refreshing them from the source would overwrite what the project generated.
  They seed once (from a `*.seed.md` that declares "no field yet") and are then the project's to
  regenerate. A new install starts field-less and says so.
- **Fields are never refreshed or retired by an update.** Once a `fields/<name>/` directory exists it is
  the project's, untouched forever — the only way "the project owns its field, lessons and stack" can be
  true.

### Migration (safe, automatic)

- A project installed under a release that *did* ship the frontend pack keeps it: those files sit in the
  project's manifest, and reconciliation now **never retires anything under `engineering/fields/`** (nor
  `ROUTER.md`). So upgrading to 0.27.0 does not gut a pack you've been building on — it just stops
  shipping a new one. Covered by a regression test that upgrades a pre-0.27 layout and asserts the pack
  survives.

## [0.26.1] — 2026-07-24

### Fixed

- **An update destroyed a project's own skills and agents.** The engine paths (`skills/`, `agents/`,
  `engineering/core`, …) were refreshed by `rm -rf`-ing the whole directory and re-copying it — so
  anything a project added inside its own brain was deleted on the next `install.sh`. Worse, that wipe
  **short-circuited the manifest reconciliation built precisely to protect those files**, making the
  release note ("never a file the project added") untrue for exactly the case it described. Engine
  paths are now refreshed **file by file**; retirement is left to the manifest, which only ever removes
  paths we shipped before, so a project-added file is invisible to it and survives. Found by adding a
  custom skill to a real project brain and re-running the installer.
- **The installer rewrote the project's own prose.** The `~/.mastermind` → `.mastermind` path rewrite
  walked every `.md` under the brain, including files the project wrote. It is now scoped to the files
  we shipped — the installer never edits a project's own notes.
- Mode bits and symlinks are preserved on refresh (`cp -Rp`, `-type l`), so `hooks/session-start.sh`
  stays executable and `AGENTS.md` stays a symlink.

Installer regression tests: **110 → 118**. The eight new assertions cover a project-added skill, agent
and core file surviving an update, project prose being left alone, the hook staying executable, the
symlink staying a symlink, and — the other direction — a genuinely retired upstream file still being
removed. All four data-loss assertions were proven to fail against the unfixed installer.

## [0.26.0] — 2026-07-22

Each project can now own its brain, and a monorepo can route a different field to each app —
the two things that stop one client's lessons and stack from leaking into another's. The
installer changed the most it has in a while; an adversarial review of the diff caught two
critical bugs before they shipped, both fixed and pinned (see the note at the end).

### Added

- **Isolated per-project install — now the default.** A per-project install copies the engine into
  `<project>/.mastermind/` and commits it, so the project owns its field, `lessons.md` and
  `stack-defaults` — and a teammate cloning the repo gets the same brain. Updates happen only when you
  re-run `install.sh` there, so nothing another project learns can change it. `--shared` opts back into
  the single `~/.mastermind` clone every project reads. `--global` stays shared. On update, a **manifest**
  removes only files we shipped that upstream retired, and never a file the project added; the project's
  own lessons are always kept.
- **Field + context routing for monorepos.** `.mastermind/routes.map` maps a path glob to a **context**
  (`apps/web/** → web`). The installer **compiles** each rule into that app directory's own
  tool-native anchor — a nested `CLAUDE.md` / `AGENTS.md` and a glob-scoped `.cursor/rules` — so the tool
  attaches the right context **by file path**, not the model guessing. Selection is therefore
  deterministic and identical across every tool that supports path rules (verified against Claude Code's
  nested memory and Cursor's `globs:`, which its docs call *"deterministically attached"*). A **field**
  holds stack knowledge once (shared by every app on it); a **context** holds one app's own lessons and
  conventions. Web's lessons never reach api. A project with no `routes.map` is single-field and
  nothing changes — the common case stays simple. Design: `engineering/isolation-and-contexts.md`.
- **Install from anywhere in the repo.** `install.sh` resolves the **git root** and installs there, so a
  monorepo gets one brain no matter which subfolder you run from — never one per app.
- **`sniper` — coming soon.** A planned skill: one invocation that reviews and verifies its own work
  before handoff, so you aren't the one finding the mistakes. Listed as coming-soon on the site and in
  `skills/README-sniper-planned.md`; deliberately not a live skill dir yet.
- **`scripts/preflight.sh`** — one command that runs the whole release gate (installer + design tests,
  every check script, all shell parses, version agreement across repo *and* site, map freshness, site
  build) and exits non-zero on any failure. The single answer to "did I test everything before shipping?".
- **`persona` skill** — split out of `signature`, which was doing two different jobs. `signature` now does
  one thing: capture *your team's* conventions (Lab-gated). `persona` is the other: write in the documented
  public style of a *named engineer* you admire, citation-gated, homage not impersonation. Both keep the
  full behavior they had; the split just makes each one job. 17 → 18 skills.

### Changed

- **Cursor now gets the full kernel**, inlined into `.cursor/rules/mastermind.mdc`, instead of a one-line
  "Follow `~/.mastermind/CLAUDE.md`" pointer. The pointer left Cursor knowing only *where* the brain was,
  not *what* it said — so the model often didn't load it and you'd type "use MasterMind" every prompt.
  `--check` now flags a stale pointer-only rule. (`--global` still doesn't cover Cursor — it has no
  user-level rules dir; run install per project. Documented.)
- **The announce line is a two-line bookend.** A plain-language top line (`🧠 MasterMind ▸ building this —
  will verify before handoff`), the internals indented under it, and a closing `🧠 verified ▸` that states
  what was actually checked. The top line is in the user's words, never jargon; the closing line is the
  one that matters — "here's what I checked so you don't have to."

### Fixed (caught by the pre-ship review, before release)

- **`--uninstall` could destroy the user's global wiring.** The new git-root walk-up matched
  `$HOME/.mastermind` (the shared clone), so from any project *under* `$HOME` it resolved the project root
  to `$HOME` — no-op'ing install and, on uninstall, deleting `~/.claude`. Now the walk stops at `$HOME`
  and ignores a symlinked `.mastermind`. Regression test nests the project inside `$HOME` with the clone
  present — the layout the suite could never reproduce before.
- **The anchor block-editor could delete a project's own content.** It matched the `MASTERMIND` markers as
  substrings, so a line that merely *mentioned* them was removed, and a lone unbalanced marker deleted
  everything after it. Now it matches whole lines only and flushes an unbalanced block instead of dropping
  it. Fuzzed with marker-containing content, lone markers, and no-trailing-newline files.
- **A CRLF `routes.map` created a `\r` context** with unresolvable imports that `--check` reported healthy.
  CR is now stripped in every reader.
- **A `routes.map` typo aborted the whole install.** A one-token line (context omitted) or a context name
  containing `/` was interpolated into a `sed` that errored under `set -e`, killing the installer — then a
  re-run "healed" into a silently broken context. Malformed lines now warn and skip; the install completes.
- **Three `check-integrity.mjs` checks were weaker than they claimed** (found by a deep test of the checks
  themselves): the root-README parity check was dead code (its header claim was false — the root README is
  a curated overview, not a complete index; corrected), the level check matched "level N" anywhere so a
  deleted current-level declaration passed, and the `SOURCE.md` copy-aside check accepted a path mentioned
  only in the later `diff` line. All three now verify what they say.
- **The architecture map shipped a stale count.** The scan's catch-all node was hardcoded `+11 more skills`
  — a literal count that broke the script's own "no counts in labels" rule and was already wrong (the
  library held 12). It's now a count-free `more skills` node generated by `update-scan.mjs`, so it can
  never go stale again.
- **`preflight.sh` could never pass a legitimate uncommitted release.** Its map-freshness check compared
  `scan.json` against `HEAD`, conflating "stale" with "not yet committed" — so the gate failed on the very
  release it was meant to clear. It now checks the working file against a fresh regeneration, independent of
  commit state.

Installer regression tests: **37 → 110**, including every critical scenario above (each proven to fail
against the unfixed code). A separate deep functional pass exercised install.sh across all modes and the
five check scripts against their own broken invariants. This release is mechanism work — no new
model-behavior eval was run, so the published eval numbers are unchanged, and `evals/RESULTS.md` says so.

## [0.25.0] — 2026-07-21

Clears the entire backlog from the v0.24.0 documentation pass, then audits the files that pass never
touched. **A minor bump, not a patch:** several skills now behave differently — `debug` refuses to guess
at an unreproducible bug, `spike` stops at a bound, `signature` drops uncited claims, and motion
durations changed. Three review passes over the work found real defects each time, including two
security holes and a bug that destroyed installs; those are called out below rather than buried.

### Mechanical fixes — the four that blocked everything else

Mechanical bug fixes found by reading the source during a documentation pass. No behavior change to
any skill or agent — these fix things that were silently broken or quietly untrue.

#### Fixed

- **A new field pack was silently unroutable — this is why only `frontend` ever existed.** None of the
  files in `engineering/fields/_template/` carried `route_when` frontmatter, and `build-router.mjs`
  skips any field file without it. So `cp -r _template` produced a pack with **zero router nodes and no
  warning**: the model could never find it. Every template file is now tagged (copying the template now
  yields 6 routable nodes), and `_`-prefixed directories are excluded from the router so the template's
  own placeholder files can never be routed to.
- **The template shipped no `audit-rules.md`,** so a bootstrapped pack left `code-reviewer` with no
  framework-specific rules at all. Added, listed in the pack's contents table, and now required.
- **`check-integrity.mjs` fails on the above instead of letting it pass silently** — every field-pack
  file except `field.md` must carry `route_when`, and every pack must ship `field.md` + `audit-rules.md`.
- **Every documented `ui-ux-pro-max` command was broken.** The docs said
  `skills/ui-ux-pro-max/scripts/search.py`; the real path is
  `engineering/fields/frontend/ui-ux-pro-max/`. All 14 occurrences corrected to a path that works from
  any directory, and verified by running one.
- **`ui-ux-pro-max` advertised 6 stacks it cannot serve.** `javafx`, `wpf`, `winui`, `avalonia`, `uno`,
  and `uwp` were configured with no data files, so `--stack wpf` was accepted and then failed with
  "Stack file not found". The dead entries are gone and the available list is now derived from the CSVs
  that actually ship, so config and disk cannot drift apart again.
- **Corrected `ui-ux-pro-max`'s own stats** — 73 font pairings (said 57) across 16 stacks (said 10).
  Palettes (161), UX guidelines (99), product types (161), and chart types (25) were already accurate.
- **`help`'s "17 skills · 4 agents" header is now verified, not hand-synced.** It had to be updated by
  hand on every skill addition, which guarantees it eventually lies; `check-integrity.mjs` now fails if
  it disagrees with what ships. `tests/install.test.sh` likewise derives its expected counts from the
  repo rather than hardcoding 17/4/18.

### Design fixes — where a skill contradicted its own stated rule

Clears the rest of the backlog from the v0.24.0 documentation pass — ten design defects where a skill
or agent contradicted its own stated rule, plus the first tests for the design engine. Two real bugs
surfaced along the way that were not on the list.

#### Fixed

- **The `lab` push guard only scanned five file extensions.** A secret in a `.env`, `.py`, `.yaml`, or
  `.txt` walked straight past `pre-push` — the layer that exists to catch exactly what `--no-verify`
  and pre-guard history let through. `pre-commit` had no such filter, so the two layers disagreed on
  scope. Now scans every file type, excluding `lab/` itself (the quarantine legitimately contains the
  terms, and self-matching would block every future push). Found while writing the guard's first test.
- **`lab`'s own cleanup step could destroy uncommitted work** — it ended with `git reset --hard`,
  run from the user's real repo mid-setup. Now `--soft` plus a targeted unstage.
- **`lab` never tested its most important guard.** Its rule is *"a guard you haven't tested is a guard
  you don't have"*, but only `pre-commit` was proven. `pre-push` now has a real test — against a local
  throwaway remote, because a direct invocation silently passes (the hook reads refs from stdin, so
  with no stdin the loop body never runs).
- **`debug` had no exit when a bug can't be reproduced.** It said "no repro, no fix" and stopped there.
  Now: ship instrumentation, state what was ruled out, hand back with evidence — never guess at a fix.
  The hypothesize↔test loop also gained a budget of three refuted hypotheses, after which the framing
  is wrong, not the ranking.
- **`spike` had no time-box despite naming endless exploration as its failure mode.** Now 5 attempts
  (≈30 min), with a defined expiry: stop, report what's known and unknown, recommend, discard the code.
- **`signature`'s anti-fabrication guard was self-referential** — the model checked its own citations,
  so a hallucinated rule came with a hallucinated verification. Now every claimed style trait needs a
  resolvable primary-source link *in the output*, or it is dropped. No sources at all → say so and fall
  back; never synthesize a persona from reputation. This matters because the mode attributes opinions
  to real, named people.
- **`levelup` violated two of its own authoring rules** (one job; lean body). 135 → 58 lines, with
  `authoring.md`, `refresh.md`, and `bootstrap.md` loaded on demand. Its "refresh is upstream-only"
  rule is now an explicit path allowlist plus a `git status` check, so a violation shows up in a diff.
- **Motion advice contradicted itself.** `web-animations.md` allowed 200–500ms for modals while its own
  checklist said "reduce >300ms", and `motion.csv` said 400–800ms for page transitions. One policy now
  arbitrates, tiered by the area the motion covers (small 100–200ms · medium 200–350ms · large
  350–500ms, 600ms ceiling), grounded in Material 3's duration tokens. A modal is medium, not large.
  Added a verified CSS↔GSAP easing map — transcribed from GSAP's source, not from the widely-circulated
  `power2.out ↔ cubic-bezier(0.215, 0.61, 0.355, 1)`, which is measurably wrong by 2.2%. Curves that
  *cannot* be expressed as a cubic Bézier (elastic, bounce, every `inOut`) are listed as omitted rather
  than approximated.
- **`route` inlined a skill list that was wrong** (`review` is an agent, not a skill) while its own rule
  is "point, never restate". Now points at the index. Its broken file references are corrected.
- **`qa` wrote test files to disk before asking**, undercutting its own rule. Permission now comes first
  — excluding the trivial case of adding a case to a suite that already exists.
- **`spec` and the `architect` agent had no stated relationship** despite overlapping. Boundary and
  handoff are now explicit: spec owns the *what*, architect the *how*.
- **`perf` was the only skill that never ran `levelup`**, so performance lessons were never captured;
  its suspect list was also web-biased. Now field-agnostic bottleneck classes plus a pointer to the
  active pack; the frontend specifics moved into the frontend pack.
- **`explain`'s "keep docs in sync" had no mechanism.** Now records the source commit and content hash
  in the generated doc, so drift is detectable the same way `ROUTER.md` detects it.
- **`code-reviewer`'s reproduce-gate was meaningless for architecture findings** — you cannot reproduce
  a deep-module violation, so the gate either blocked real findings or got ignored. Correctness and
  security keep the reproduce-gate; architecture findings now need a cited principle, a `file:line`,
  and a concrete maintenance cost. Taste is not a principle and discomfort is not a cost.
- **`refactorer` cited two external sites but has no web tools.** The guidance is inlined; the URLs
  remain only as human-facing references, marked unfetchable.
- **`tech-scout`'s rubric had no thresholds**, so it could weigh criteria but never actually decide.
  Now a first-match-wins ladder to a verdict. It also listed RTL as a fixed constraint, against the
  kernel's "RTL/i18n is decided per project's audience — never assumed"; now evaluated per project.
- **`lessons.md` grew without pruning**, against the project's own "a pack that only grows is a bug".
  Both the frontend pack and the template now carry a pruning trigger and four delete conditions.

#### Added

- **First tests for the design engine** — 46 characterization tests over `design_system.py`, 1329 lines
  that had none. They pin determinism, dial clamping and tier edges, no-match paths, and that
  persistence writes only under its output dir. Standard library only; no new dependency. They pin
  current behavior rather than assert it is correct: three of them document real bugs, including a
  **path traversal** in `persist_design_system` where a crafted project name writes outside the tree.
  Coverage is partial by design and `scripts/tests/README.md` says so — roughly 700 lines of output
  formatting remain untested.

#### Removed

- **`data/draft.csv`** (~104KB) — an unreferenced near-duplicate of `design.csv` that no code path
  reads, and which documents its own deadness in a comment. `design.csv` was dead by the same evidence
  and is removed here too.
- **The duplicated cycle-report / plan-first preference block**, restated in `init` and `help` where it
  would drift. `build` and `report` keep the authoritative definitions; the others point.

### Audit — the installer, the hooks, and the checks themselves

A fresh-eyes audit of the files the fixes above never touched — the installer, the hooks, and the
checks themselves. It found that the previous release's headline security fix had only landed in half
the places it needed to, plus a bug that could destroy an install outright.

#### Fixed

- **The documented update command destroyed the install.** `REPO` was resolved with `pwd`, which
  returns the *logical* path — so running `~/.mastermind/install.sh` (the command in the README, the
  installer's own header, and every "how to update" doc) set `REPO=~/.mastermind` and then ran
  `ln -sfn ~/.mastermind ~/.mastermind`, pointing the brain symlink at **itself**. The result is an
  unreadable loop: every glob stops matching, so skills link as a literal `*`, agents as `*.md`, and
  the kernel is gone — while the installer still prints `✓ 1 skills, 1 agents linked`. Now resolved
  with `pwd -P`, with a hard refusal if the two paths ever coincide again, and three regression tests
  that reproduce the exact symptom.
- **The push-guard fix above only landed in the copy we ship.** `.githooks/pre-push` — the guard
  actually protecting this public repo — kept the extension allowlist, so a secret in a `.env`, `.py`,
  or `.yaml` still walked past it here. `CHANGELOG.md` and `SECURITY.md` both claimed otherwise. Synced,
  and `check-integrity.mjs` now fails when the live guards and the shipped guards diverge.
- **A trailing space in `lab/.denylist` silently disabled that term.** Terms were never trimmed, so
  `"Acme Corp "` became an alternation branch requiring a literal trailing space — the guard then printed
  `✓ clean` while that client's name went unscanned. Same failure with a CRLF denylist. **Fails open,
  silently, per-term**, which is the worst shape a leak guard can have. Now trims whitespace and CR.
- **`--uninstall` left behind everything it wrote.** It removed symlinks but not the `SessionStart`
  entry it merged into `settings.json`, `.cursor/hooks.json`, or `.github/hooks/mastermind.json` — so
  following the printed advice to "delete the clone" left every session firing a hook that pointed at a
  missing script. Now unwired properly, and the user's own settings are still preserved untouched.
- **`--global --uninstall` deleted files from the current project.** It removed `GEMINI.md`,
  `.cursor/rules/mastermind.mdc`, and the Copilot instructions from `$PWD` regardless of scope, while
  announcing it was operating on global. Project artifacts are now project-scope only.
- **The skills index check was vacuous for 6 of 17 skills.** `skills/README.md` was verified with a
  bare substring match, so deleting the row for `qa`, `build`, `report`, `route`, `learn`, or `debug`
  passed clean — their names occur in ordinary prose. It also never detected an *extra* entry. Now
  parses the table rows and compares sets both ways.
- **`build-library.mjs` invented a repo that wasn't there.** With no sibling site checkout it created
  the whole `../mastermind-site/src/pages/library/` tree and reported success. Now exits 1 with a clear
  message.
- **Three bugs in the vendored design engine**, found by the new characterization suite and fixed
  locally (recorded in `SOURCE.md` so a re-vendor can't silently undo them): a **path traversal** in
  `persist_design_system` where a crafted project name wrote outside the output tree; a keyword pass so
  loose that the token `"e"` made every unrecognized category inherit E-commerce rules; and a
  bidirectional name match where a short style name beat the intended target. All 161 real categories
  resolve unchanged and normal output is byte-identical.

#### Added

- **Three integrity checks** (7 → 10), each proven to fail before being kept: the active field points
  at a pack that exists; a `SOURCE.md` preserve list is honored; and the repo's own guards match the
  guards it ships.
- **Seven installer regression tests** (30 → 37) covering the symlink-invocation path, uninstall
  completeness, and global/project scope separation.

## [0.24.0] — 2026-07-21

Twelve improvements drawn from two agent-engineering courses (harness, graph) and the `obra/superpowers`
repo — adopted as **portable discipline** that works on any model. The kernel is unchanged in size, and
everything new lives in on-demand files or shell.

### Fixed

- **Your own skills are never displaced again.** Installing into a project that already had a `build`,
  `debug`, or `qa` skill used to move yours aside. Now **both survive**: yours keeps its name, MasterMind's
  installs alongside as `mastermind-<name>`, and the installer says so. If your file later disappears,
  ours reclaims the plain name and the alias is cleaned up. `--uninstall` still never touches your files.

### Added

- **Bootstrap re-injection — the brain now survives a compaction.** A `SessionStart` hook re-injects the
  kernel on `startup|clear|compact`. Previously the kernel was read once and faded as the window filled,
  so long sessions silently ran without MasterMind's discipline — no error, just confident answers without
  the rigor. Merges into an existing `settings.json` without clobbering it, is idempotent, and leaves an
  unparseable settings file strictly alone. `--check` reports whether it's registered.
- **Graph thinking** (`core/agent-loop.md`) — the **edge test** (does the next step actually read the last
  step's output? if not, the wait is wasted), **node contracts**, **edges are free** (never pay a model to
  do plumbing), the **diamond** (fan out → reduce → synthesize), **barriers cost wall-clock**, **loop
  convergence** (dedupe against everything *seen*, not only what was confirmed), and **isolate only where
  steps write in parallel**.
- **Prove a skill changes behavior** (`levelup`) — watch an agent fail *without* the skill and record its
  actual rationalizations before writing it. "If you never watched it fail, you don't know whether the
  skill teaches the right thing."
- **Plan quality bar** (`build`, plan-first mode) — a plan must be followable by *an enthusiastic junior
  engineer with poor taste, no judgement, no project context, and an aversion to testing*: exact file
  paths, bite-sized steps, and a stated way to tell each one worked.
- **Installer regression tests** (`tests/install.test.sh`) — 27 assertions over the scenarios that guard
  our actual promises: never destroy your files, never lose a MasterMind capability, always idempotent,
  merge settings rather than clobber them, leave an unparseable config alone. `install.sh` is the
  highest-risk file we ship and had no coverage until now.
- **Cursor hook wiring** (`.cursor/hooks.json`, `sessionStart` + `preCompact`). **Unverified upstream:**
  Cursor has open bug reports where a hook's `additional_context` is accepted but never reaches the
  model, and we cannot test Cursor here. It costs nothing and starts working the moment that's fixed —
  but the `.mdc` rule remains Cursor's load-bearing path, and we do not claim re-injection works there.
- **Copilot CLI hook wiring** (`.github/hooks/mastermind.json`, `sessionStart`) — built against GitHub's
  published hooks reference and verified to match its schema. Copilot loads every `.github/hooks/*.json`,
  so we ship our own file and never touch yours. **Startup-only:** Copilot exposes no compaction event,
  so the brain reloads each session but can still fade inside a long one.
- The bootstrap script now takes an explicit **shape argument** (`cursor|claude|sdk`) instead of relying
  on environment sniffing. A project-level Cursor hook gets no `CURSOR_PLUGIN_ROOT`, so detection alone
  would have silently emitted the wrong field and injected nothing.

### Known limits — what re-injection actually covers

| Tool | Level | Status |
| --- | --- | --- |
| Claude Code | startup **+ compaction** | verified (`evals/RESULTS.md` Run M1e) |
| Cursor | startup + `preCompact` | wired, **unverified** — upstream bug reports |
| Copilot CLI | **startup only** | schema-verified, untested live; no compaction event exists |
| Codex | — | has a hook system; not yet wired |
| Gemini | startup only | loads via `contextFileName`; no evidence it re-fires on compaction |
| Plain chat | — | **impossible**; no mechanism exists |

Only the Claude Code row is measured. The rest are built to published schemas and stated as unverified
rather than claimed.

### Changed

- **Every skill description now states WHEN, never WHAT.** A description that summarizes its own workflow
  becomes a shortcut the model takes *instead of* reading the skill — measured elsewhere as an agent running
  one review where the body specified two. All 17 rewritten as triggering conditions in the user's own
  words, which also sharpens router matching.
- **New authoring rule: name actions, not tools** (`levelup`) — "dispatch a subagent", never a specific
  tool's name. This is what lets one skill body run unedited on Claude Code, Codex, Cursor, Gemini, and
  plain chat.

## [0.23.0] — 2026-07-19

### Added

- **Plan-first mode** (opt-in, off by default) — on a bigger task, MasterMind presents the plan (goal,
  approach, files it'll touch, steps, risks) and **waits for your approval before editing anything**. On your
  OK it announces `🧠 MasterMind ▸ implementing the plan` and proceeds. Set per project in
  `.mastermind/prefs.md` (`plan-first: on`); `init` offers it alongside the cycle report, and it's skipped for
  trivial one-liners. The counterpart to the after-the-fact `report`: this one gates *before* work starts.

## [0.22.4] — 2026-07-19

### Changed

- **Site/UX polish** — consistent caption spacing under tables/bars/maps, a fix for the inline `--global`
  token (Geist-Mono leading-hyphen was eating the space; now an inline-code pill), footer restored, and
  version synced across repo + site. No changes to the brain itself since 0.22.0.

## [0.22.0] — 2026-07-19

Adopt three proven agent-engineering patterns as **portable discipline** (works on any AI model), all in
**on-demand files** — the always-loaded kernel is untouched, so the per-task baseline cost is unchanged.

### Added

- **Rubric-driven self-correcting loop** (`core/agent-loop.md`) — for non-trivial work, write the pass/fail
  done-rubric up front (reusing `spec`'s acceptance criteria) and loop against it, self-correcting until it's
  green, without stopping to ask mid-loop. **Bounded: ≤2 correction passes**, then surface/escalate; skipped
  for one-liners. (Anthropic "outcomes" / long-horizon self-correction.)
- **Verified review + opt-in fan-out** (`code-reviewer`) — every finding must be **reproduced before it's
  reported** (drop what you can't demonstrate); substantial diffs get a second independent pass. Higher
  signal, fewer style-nits. On Claude Code, `/code-review ultra` is the cloud version; the discipline is the
  portable core. (ultrareview.)
- **`route_when` = the question the user would ask** (`levelup` authoring) — phrase routing triggers as the
  real question ("why is this slow?"), not a topic label, so the router matches intent more precisely.
  (Knowledge-base retrieval lesson — Cerebras.)
- **`🧠 MasterMind ▸` proof-of-life mark** — the announce line now leads with the name + brain logo, so you
  see MasterMind engage on each task (one line, skipped for trivial).

## [0.21.0] — 2026-07-19

### Added

- **`report` skill — an opt-in cycle report.** A shareable write-up of a build/QA cycle (what changed,
  the key decisions and why, how it was verified, the verdict) as a durable file — **Markdown by default,
  HTML on request**. Tool-agnostic (a plain self-contained file, never a tool-specific artifact).
- **Off by default; asked once.** `init` offers it a single skippable time at your first task and records
  the choice in a project-local `.mastermind/prefs.md` (`cycle-report: off|ask|markdown|html`). `build`
  and `qa` honor it at the end of a cycle. Skipped entirely for one-line changes; HTML only when asked, so
  no one pays the token cost unless they turn it on.

## [0.20.0] — 2026-07-18

**Per-project by default.** MasterMind now installs into the project you run it in — not your whole
machine — and wires **every AI tool you have**, not just Claude Code.

### Changed

- **Install scope is now per-project by default.** `install.sh` (run inside a project) wires that repo's
  `.claude/` for Claude Code plus `AGENTS.md` / `.cursor/rules/*.mdc` / `GEMINI.md` for Codex / Cursor /
  Gemini — active only there. Run it in each project you want it in. `--global` keeps the old machine-wide
  behavior (Claude + Codex in `~/`). The one-liner run from inside a project wires that project.
- **Non-destructive for every tool.** An existing `AGENTS.md` / `GEMINI.md` / Copilot file is **appended**
  to (pointer line), never overwritten; a real `CLAUDE.md` is still backed up.

### Added

- **`--uninstall`** (scoped) — cleanly removes MasterMind's links from a project (or `--global`), leaving
  your own files untouched. This is the migration path off a pre-0.20 global install.
- **`--check` is project-aware** — verifies only what's wired here, and says so when a project isn't set up.

### Migration

- A pre-0.20 **global** install keeps working. To move to per-project: `~/.mastermind/install.sh --global
  --uninstall`, then run `~/.mastermind/install.sh` inside each project you want.

## [0.19.0] — 2026-07-18

The **getting-started** release: make MasterMind as easy to start as possible, and make setup for
a project one clear step. Nothing about the mindset changed — this is all onboarding, distribution,
and honesty.

### Added

- **`init` skill** — first substantive work in a project sets MasterMind up once: detect the stack
  (or, on an empty folder, ask *one* open question — "what do you want to build?"), load/tailor the
  field pack, and hand back a short "ready" report. Runs automatically on the first task, or on
  request (say "init"; `/init` in Claude Code / Gemini).
- **`help` skill** — the full menu of skills + agents, each with the scenario it auto-fires in and how
  to call it by hand. Ask "what can you do?".
- **`perf` skill** — measure → find the real bottleneck → fix the biggest one → verify.
- **One-line install** — `curl -fsSL …/bootstrap.sh | bash` clones (or updates) and runs the installer.
- **Self-healing installer** — `install.sh` prunes stale/renamed skill links and relinks the current
  set on every run, so an upgrade can never leave a skill silently dead. `--check` is a doctor that
  verifies everything resolves and now reports when your clone is **behind origin** (network-optional).
- **Interactive architecture map** — a Foglamp map of the kernel → router → field pack → skills/agents,
  auto-refreshed by CI and embedded on the site's `/architecture` page.

### Changed

- **Renamed `initialize` → `init`** (shorter). All phrasings — init / set up / onboard — route to the
  same one skill; no conflict.
- **Cross-tool onboarding** — the installer wires Claude Code + Codex; Cursor / Copilot / Gemini / any
  `AGENTS.md` tool load the same brain via one line. "Just talk, no commands" holds on every tool.
- **Honest router number** — the measured **~65%** token reduction everywhere (was overstated).
- **Kernel** — "show the brain working" (announce a skill/agent in one line, never a permission prompt)
  plus an inlined skill/agent menu so the disciplines apply in non-native tools too.

### Removed

- **Static `MAP.md`** — superseded by the live, auto-refreshed interactive map. One map, always current.

## [0.18.1] — 2026-07-17

A lean markdown "brain" that gives an AI coding assistant sharp defaults, real judgment, and the
discipline to check its own work — on any tool (Claude Code, Codex, Cursor, Copilot, or any
AGENTS.md agent). You don't learn commands; you just talk, and it applies the right discipline.

### Added

- **Router** — `scripts/build-router.mjs` generates `engineering/ROUTER.md`, a deterministic manifest
  so a task loads only the field/skill files it needs (~65% fewer tokens per task, measured). No AI, no network.
  Degrades safely: if the manifest is missing, MasterMind loads the field the normal way.
- **`signature` skill — two modes.** Capture a team's real style into clean, name-free rules (private,
  Lab-gated); or write in the documented public style of a named engineer — grounded in their real
  public work, never impersonation.
- **The Verdict.** Non-trivial work now ends with an explicit **ship / needs-work / redirect** call
  plus the evidence and the one-line "why" (`core/rigor.md`) — closing the accountability hand-off.
- **Lab quarantine.** A gitignored `lab/` with a denylist plus pre-commit/pre-push guards, so private
  or client material can never reach the repo or its history.
- **Frontend field:** a web-animations capability (Emil Kowalski) and framework-specific `audit-rules`
  for the `code-reviewer`.
- **Honesty tooling:** a link-checker + weekly freshness CI, and a **multi-model eval suite**
  (`evals/pilot-multimodel/`) with published results — the router's ~65% saving and per-model quality
  deltas measured, misses included.
- **Maps:** a bird's-eye [`MAP.md`](MAP.md) plus an auto-refreshed interactive map (Foglamp).
- **Onboarding:** if a task's field has no pack, MasterMind offers a one-time setup and explains the
  trade-off; every pack must fit one real stack and stay lean (prune as it grows).

### Changed

- **Skills renamed to short, memorable names and merged where they overlapped** — now 13: `build`,
  `debug`, `qa` (verify + tdd), `spec` (+ glossary), `learn` (+ grill), `signature` (character +
  signature), `explain`, `route`, `prompt`, `spike`, `lab`, `levelup`, `handoff`. All are
  model-invocable — MasterMind applies them itself.
- **`code-reviewer`** absorbed the audit role: a convention-vs-correctness gate that proposes fixes and
  never applies them.
- **`ui-ux-pro-max`** design database moved from a global skill into the frontend field pack
  (`engineering/fields/frontend/ui-ux-pro-max/`) — it's field knowledge, not a global skill.
- Kernel gained **"apply automatically — never wait for a command."**

### Removed

- The knowledge-graph experiment — it added confusion, not value, and nothing consumed it.
