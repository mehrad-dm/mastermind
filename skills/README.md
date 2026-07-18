# MasterMind Skills — index & router

**You don't need to run these.** MasterMind reads what you ask in plain language and applies the right
skill automatically — no slash command required. This index is the map (for reference, and for power
users who *want* to invoke one directly with `/name`). Each skill is one job with a lean routing-rule
description and an on-demand body. Keep the map honest: a skill it never lists, or one it still lists
after removal, is a router that lies. (Authoring discipline: `levelup` → "Authoring a new skill".)

> Skills are **inline workflows**. Isolated-context expert *roles* — `architect`, `code-reviewer`,
> `refactorer`, `tech-scout` — are **agents** (`../agents/`), not skills.

## Start & discover
| Skill | What it does (auto-applies when you…) |
| --- | --- |
| [`initialize`](./initialize/SKILL.md) | …first work in a new project. Detect the stack (or ask what you're building), set up the field pack(s), hand back a short "ready" report. Once per project. |
| [`help`](./help/SKILL.md) | …ask "what can you do / how do I use this". The full menu of skills + agents — each with the scenario it auto-fires in and how to call it by hand. |

## Build & ship
| Skill | What it does (auto-applies when you…) |
| --- | --- |
| [`build`](./build/SKILL.md) | …ask to build a feature. The flagship: design → implement-to-rigor → verify → review → capture. |
| [`debug`](./debug/SKILL.md) | …hit a hard bug. Structured six-phase debugging — evidence over guessing. |
| [`qa`](./qa/SKILL.md) | …finish something / want it tested. Prove it works end-to-end; tests / TDD only if you say so (offered after a build). |
| [`spike`](./spike/SKILL.md) | …face a risky unknown. A fast throwaway spike to learn, then rebuild properly. |

## Think first
| Skill | What it does (auto-applies when you…) |
| --- | --- |
| [`spec`](./spec/SKILL.md) | …give a fuzzy/multi-file ask. Turn it into a crisp spec (problem, scope, key terms, interfaces, acceptance, edges). |
| [`learn`](./learn/SKILL.md) | …work in unfamiliar/fast-moving tech. Learn the real stack to current standards + grill your assumptions against the source. |
| [`route`](./route/SKILL.md) | …start a non-trivial task. Load only the pack files / docs / code it needs (via `ROUTER.md`); refuses to over-plan a small one. |
| [`prompt`](./prompt/SKILL.md) | …want a request sharpened. Turn a vague ask into a tight, AI-ready prompt. |

## Capture, improve, hand off
| Skill | What it does (auto-applies when you…) |
| --- | --- |
| [`signature`](./signature/SKILL.md) | …want MasterMind to fit your team. Capture the codebase's real patterns (Lab, patterns-not-people) → name-free rules the AI follows. Proposes, never auto-applies. |
| [`explain`](./explain/SKILL.md) | …have an under-documented internal package. Generate AI-friendly per-unit usage docs so any model understands it. **Asks first.** |
| [`lab`](./lab/SKILL.md) | …need to capture sensitive project data safely. Sets up a private, gitignored Lab + the safety guards. |
| [`levelup`](./levelup/SKILL.md) | …teach MasterMind something durable. Capture a lesson / refresh a field / bootstrap a new field. |
| [`handoff`](./handoff/SKILL.md) | …pause or hand off. A concise handoff so work survives a `/clear` or a new session. |

> **Frontend-field abilities** live in the frontend pack, not here — they load with that field via the
> router: **`improve-ui`** (audit a UI against its own design language → a fix plan) and the
> **`ui-ux-pro-max`** design-intelligence database.

The library grows freely — add a skill for any distinct, useful workflow (one job + lean routing-rule
description + on-demand body). Register every new skill here.
