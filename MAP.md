# MasterMind — the whole thing, at a glance

A bird's-eye map of the repo: what each part is, how big it is, and how a task flows through it.
For the *why*, read [`README.md`](README.md); for the engineering internals, [`engineering/README.md`](engineering/README.md).

> **🗺️ Prefer to explore it visually?** There's a live, pannable version of this map:
> **[foglamp.dev/scan/mastermind-mkfscq](https://foglamp.dev/scan/mastermind-mkfscq)**
> (auto-refreshed by CI, so it stays current). The static map below always works, even offline.

```text
mastermind/                        the brain — symlinked to ~/.mastermind; the model sees only the linked parts
│
├─ CLAUDE.md          1.7k tok  ◄─ KERNEL · always-on: identity · prime directives · operating loop · verdict
├─ AGENTS.md → CLAUDE.md            same brain, for Codex / any AGENTS.md tool
│
├─ engineering/                  ─────────────── THE KNOWLEDGE ───────────────
│  ├─ active-field.md  2.4k        which field is active · onboarding · leveling · token economy
│  ├─ ROUTER.md        1.3k     ◄─ generated manifest → routes a task to the 1–2 files it needs (~65% fewer tokens)
│  ├─ core/            7.0k        UNIVERSAL, field-agnostic — how to think & work
│  │                              mindset · principles · rigor · agent-loop · product-sense
│  └─ fields/
│     ├─ _template/                the shape every new field is copied from (carries the lean/fit rules)
│     └─ frontend/    20.9k        THE ONE FIELD (routed → only ~2–12k loads per task)
│                                 stack-defaults · mentors · curriculum · lessons · web-animations ·
│                                 audit-rules · improve-ui · + ui-ux-pro-max/ (vendored design DB)
│
├─ skills/ (13)       11.7k     ─ WORKFLOWS (model-invoked, "just talk") ─
│                                 build · debug · qa · spec · learn · signature · route · prompt ·
│                                 spike · explain · lab · levelup · handoff
├─ agents/ (4)         2.9k     ─ EXPERT ROLES (isolated context) ─
│                                 architect · code-reviewer · refactorer · tech-scout
│
├─ scripts/ (3)                 ─ EXECUTABLE SPINE (keeps the brain honest) ─
│  ├─ build-router.mjs             generates ROUTER.md — the token saver
│  ├─ check-integrity.mjs          makes the indexes unable to lie (CI-enforced)
│  └─ check-links.mjs              keeps the curriculum's links alive (weekly CI)
│
├─ evals/                       ─ THE HONESTY APPARATUS ─ method · task sets · RESULTS (the proof, misses included)
│
├─ .githooks/ (2)                  pre-commit + pre-push — block private/client data from ever being committed
├─ .github/ (2)                    CI: integrity (every push) · freshness (weekly)
├─ lab/  (gitignored)              quarantine for raw private data — never published, never linked
└─ install.sh · README · CHANGELOG · CONTRIBUTING · SECURITY · VERSION
```

## How a task flows through it

```text
you: "just talk"  →  KERNEL (always on)  →  detect field / load pack (or offer to build one)
                                                     │
                        ROUTER matches task ─────────┘  →  loads only the 1–2 matched files
                                                     │
                        apply CORE rigor + FIELD defaults  →  build  →  VERIFY (against reality)  →  VERDICT
```

Guardrails (`.githooks`) and honesty checks (`scripts/` + CI) wrap the whole loop.

## Shape at a glance

| Layer | Size | Loads |
| --- | --- | --- |
| Kernel (`CLAUDE.md`) | ~1.7k tok | always |
| Core (`engineering/core/`) | ~7.0k tok | on demand, universal |
| Frontend field | ~20.9k tok | **routed** → ~2–12k per task |
| Skills (13) + Agents (4) | ~14.6k tok | when the task invokes them |

**The design in one line:** a *tiny always-on layer* (kernel + core), *depth on demand* (fields routed to just what's needed), a *small executable spine* (3 scripts + CI + hooks) that makes the whole thing self-checking and safe.

## What the model actually sees (on install)

`install.sh` links only the **brain** into the tool (`CLAUDE.md` + `engineering/` + `agents/` + `skills/`).
It never links `evals/`, `scripts/`, `.github/`, or `lab/` — so those cost a user nothing.
