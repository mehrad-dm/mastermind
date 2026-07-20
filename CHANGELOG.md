# Changelog

Notable changes to MasterMind. Format follows [Keep a Changelog](https://keepachangelog.com/).
MasterMind is **experimental** and pre-1.0, so minor versions may change behavior. Full commit
history lives in git.

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
