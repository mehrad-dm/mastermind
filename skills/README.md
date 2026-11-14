# MasterMind Skills: index & router

**You don't need to run these.** MasterMind reads what you ask in plain language and applies the right
skill itself: no slash command required. Six run only when you ask for them, or when another skill sends
the model to their file: `help`, `handoff`, `report`, `levelup`, `lint`, `signature`. This index is
the map (for reference, and for power users who *want* to invoke one directly with `/name`). Each skill
is one job with a lean routing-rule description and an on-demand body. Keep the map honest: a skill it
never lists, or one it still lists after removal, is a router that lies. (Authoring discipline:
`levelup/authoring.md`.)

> Skills are **inline workflows**. Isolated-context expert *roles*: `architect`, `code-reviewer`,
> `refactorer`, `tech-scout`: are **agents** (`../agents/`), not skills.

## Start & discover
| Skill | What it does (applies when you…) |
| --- | --- |
| [`init`](./init/SKILL.md) | …say "init", or say yes when MasterMind offers it. Reads the stack, builds the field pack with no questions, hands back a short "ready" report. Once per project, never run unasked. |
| [`help`](./help/SKILL.md) | …ask "what can you do / how do I use this". The full menu of skills + agents: each with the scenario it applies in and how to call it by hand. |

## Build & ship
| Skill | What it does (applies when you…) |
| --- | --- |
| [`build`](./build/SKILL.md) | …ask for a feature, change or fix whose scope is clear. The flagship: a design sized to the change, code to rigor, proof it works, and a fresh-context review above the kernel's threshold. |
| [`debug`](./debug/SKILL.md) | …hit a hard bug. Structured six-phase debugging: evidence over guessing. |
| [`performance`](./performance/SKILL.md) | …something's slow ("why is this slow?"). Measure → find the real bottleneck → fix the biggest → verify. Not a correctness bug (that's `debug`). |
| [`qa`](./qa/SKILL.md) | …finish something / want it tested. Prove it works by running it; tests / TDD only if you say so. |
| [`report`](./report/SKILL.md) | …ask for a report / write-up of a cycle (or automatically at the end of build/qa, if you turned it on). A shareable record: Markdown default, HTML optional. Opt-in, off by default. |
| [`prototype`](./prototype/SKILL.md) | …face a risky unknown. A fast throwaway prototype to learn, then rebuild properly. |
| [`clarify`](./clarify/SKILL.md) | …did not follow the last answer. Re-pitches it in plain words or as a picture, and records where MasterMind wrote badly. |
| [`deepen`](./deepen/SKILL.md) | …feel the design is hurting but not what to fix. Surveys an area, ranks candidates by the cost each will cause, you pick one. |
| [`double-check`](./double-check/SKILL.md) | …are about to hand over a claim that running code cannot settle (a diagnosis, a design call), or a review came back suspiciously clean. The reviewer never sees your conclusion. Not run at the end of every build. |
| [`deprecate`](./deprecate/SKILL.md) | …need to remove, migrate, or retire something. Expand → migrate → contract, and proof that nothing still reads it. |

## Think first
| Skill | What it does (applies when you…) |
| --- | --- |
| [`interview`](./interview/SKILL.md) | …give an ask whose scope is unclear. Turn it into a crisp spec (problem, scope, key terms, interfaces, acceptance, edges). A clear ask skips it, however many files it spans. |
| [`learn`](./learn/SKILL.md) | …work in unfamiliar/fast-moving tech. Learn the real stack to current standards + challenge your assumptions against the source. |
| [`route`](./route/SKILL.md) | …start a task where it is not obvious what to load. Load only the pack files / docs / code it needs (via `ROUTER.md`); it chooses what to read and does not scope or build. |
| [`prompt`](./prompt/SKILL.md) | …want a request sharpened. Turn a vague ask into a tight, AI-ready prompt. |

## Spec-driven: from idea to a feature that provably matches its spec
Documents live in the project's `specs/` folder; the method, layout and IDs are in
[`engineering/core/spec-driven.md`](../engineering/core/spec-driven.md). Small changes skip all of this.

| Skill | What it does (applies when you…) |
| --- | --- |
| [`assess`](./assess/SKILL.md) | …wonder whether an idea deserves building. Intake → research → define → shape → **go / clarify / stop**, with evidence. Works with no code. |
| [`constitution`](./constitution/SKILL.md) | …set the rules every feature must obey. A short, versioned list of checkable `MUST`s, with every amendment recorded and rippled. |
| [`living-docs`](./living-docs/SKILL.md) | …need the product, business or tech knowledge written down and kept current. Reads first, asks the gaps, marks what is unconfirmed. |
| [`specify`](./specify/SKILL.md) | …start a feature spec-first. What and why, no technology: prioritized stories, traceable requirements, at most three open questions. |
| [`blueprint`](./blueprint/SKILL.md) | …need the technical plan for a spec. Constitution gate, decisions with reasons, design from `architect`, contracts, a runnable quickstart. |
| [`breakdown`](./breakdown/SKILL.md) | …need the task list. Grouped by user story so each ships alone, every task traced to a requirement. |
| [`checklist`](./checklist/SKILL.md) | …want one concern's requirements tested (security, UX, API…). Questions about the spec's wording, never about the code. |
| [`analyze`](./analyze/SKILL.md) | …want spec, plan and tasks checked against each other before coding. Six passes, run by the `code-reviewer` agent, read-only. |
| [`converge`](./converge/SKILL.md) | …built a feature and need to know it is really done. Code against intent, every ticked box re-checked, gaps appended as tasks. |

`interview` resolves a spec's open questions before planning, and `build` works through `tasks.md`.

## Capture, improve, hand off
| Skill | What it does (applies when you…) |
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
