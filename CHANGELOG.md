# Changelog

Notable changes to MasterMind. Format follows [Keep a Changelog](https://keepachangelog.com/).
MasterMind is **experimental** and pre-1.0, so minor versions may change behavior. Full commit
history lives in git.

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
