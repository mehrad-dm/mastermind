# MasterMind Skills: index & router

**You don't need to run these.** MasterMind reads what you ask in plain language and applies the right
skill automatically: no slash command required. This index is the map (for reference, and for power
users who *want* to invoke one directly with `/name`). Each skill is one job with a lean routing-rule
description and an on-demand body. Keep the map honest: a skill it never lists, or one it still lists
after removal, is a router that lies. (Authoring discipline: `levelup/authoring.md`.)

> Skills are **inline workflows**. Isolated-context expert *roles*: `architect`, `code-reviewer`,
> `refactorer`, `tech-scout`: are **agents** (`../agents/`), not skills.

## Start & discover
| Skill | What it does (auto-applies when you…) |
| --- | --- |
| [`init`](./init/SKILL.md) | …first work in a new project. Detect the stack (or ask what you're building), set up the field pack(s), hand back a short "ready" report. Once per project. |
| [`help`](./help/SKILL.md) | …ask "what can you do / how do I use this". The full menu of skills + agents: each with the scenario it auto-fires in and how to call it by hand. |

## Build & ship
| Skill | What it does (auto-applies when you…) |
| --- | --- |
| [`build`](./build/SKILL.md) | …ask to build a feature. The flagship: design → implement-to-rigor → verify → review → capture. |
| [`debug`](./debug/SKILL.md) | …hit a hard bug. Structured six-phase debugging: evidence over guessing. |
| [`performance`](./performance/SKILL.md) | …something's slow ("why is this slow?"). Measure → find the real bottleneck → fix the biggest → verify. Not a correctness bug (that's `debug`). |
| [`qa`](./qa/SKILL.md) | …finish something / want it tested. Prove it works end-to-end; tests / TDD only if you say so (offered after a build). |
| [`report`](./report/SKILL.md) | …ask for a report / write-up of a cycle (or automatically at the end of build/qa, if you turned it on). A shareable record: Markdown default, HTML optional. Opt-in, off by default. |
| [`prototype`](./prototype/SKILL.md) | …face a risky unknown. A fast throwaway prototype to learn, then rebuild properly. |
| [`double-check`](./double-check/SKILL.md) | …are about to claim something works, or a review came back suspiciously clean. Interrogates the claim *before* handoff: the reviewer never sees your conclusion. |
| [`deprecate`](./deprecate/SKILL.md) | …need to remove, migrate, or retire something. Expand → migrate → contract, and proof that nothing still reads it. |

## Think first
| Skill | What it does (auto-applies when you…) |
| --- | --- |
| [`interview`](./interview/SKILL.md) | …give a fuzzy/multi-file ask. Turn it into a crisp spec (problem, scope, key terms, interfaces, acceptance, edges). |
| [`learn`](./learn/SKILL.md) | …work in unfamiliar/fast-moving tech. Learn the real stack to current standards + challenge your assumptions against the source. |
| [`route`](./route/SKILL.md) | …start a non-trivial task. Load only the pack files / docs / code it needs (via `ROUTER.md`); refuses to over-plan a small one. |
| [`prompt`](./prompt/SKILL.md) | …want a request sharpened. Turn a vague ask into a tight, AI-ready prompt. |

## Capture, improve, hand off
| Skill | What it does (auto-applies when you…) |
| --- | --- |
| [`signature`](./signature/SKILL.md) | …want MasterMind to fit your team. Capture the codebase's real patterns (Lab, patterns-not-people) → name-free rules the AI follows. Proposes, never auto-applies. |
| [`persona`](./persona/SKILL.md) | …want code in a named public engineer's style ("write it like *X*"). Grounded in their documented work, cited; homage, never impersonation. |
| [`explain`](./explain/SKILL.md) | …have an under-documented internal package. Generate AI-friendly per-unit usage docs so any model understands it. **Asks first.** |
| [`quarantine`](./quarantine/SKILL.md) | …need to capture sensitive project data safely. Sets up a private, gitignored `lab/` quarantine + the safety guards. |
| [`levelup`](./levelup/SKILL.md) | …teach MasterMind something durable. Capture a lesson / refresh a field / bootstrap a new field. |
| [`lint`](./lint/SKILL.md) | …suspect MasterMind's own files have drifted: bloat, a rule repeated across layers, two layers disagreeing. Counts first, judges only what it flagged, and **proposes; never edits**. |
| [`roadmap`](./roadmap/SKILL.md) | …work spans weeks and the decisions are piling up. A durable decision map that survives dozens of sessions: what's decided, what's still open, what's deliberately out. |
| [`handoff`](./handoff/SKILL.md) | …pause or hand off. A concise handoff so work survives a `/clear` or a new session. |

> **Field-specific abilities** can live inside a field pack rather than here, and load with that field
> via the router (for example, a frontend pack might carry a UI-audit ability and a design database).
> MasterMind ships no field by default: `init` builds one for the project's stack, so a fresh install
> has none of these until a pack is built.


The library grows freely: add a skill for any distinct, useful workflow (one job + lean routing-rule
description + on-demand body). Register every new skill here.
