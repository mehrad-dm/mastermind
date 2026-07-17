# Changelog

Notable changes to MasterMind. Format follows [Keep a Changelog](https://keepachangelog.com/).
MasterMind is **experimental** and pre-1.0, so minor versions may change behavior. Full commit
history lives in git.

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
