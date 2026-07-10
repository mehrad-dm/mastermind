# MasterMind Skills — index & router

The skill library. Each is one job with a lean routing-rule description and an on-demand body. This
index is the map — keep it honest: a skill it never lists, or one it still lists after removal, is a
router that lies. (Authoring discipline: `mastermind-levelup` → "Authoring a new skill".)

> Skills are for **inline workflows**. Isolated-context expert roles — review, architecture, refactor,
> adopt-decisions — are **agents** (`../agents/`), not skills. Don't duplicate them here.

## Core loop
| Skill | Job |
| --- | --- |
| [`mastermind-build`](./mastermind-build/SKILL.md) | The flagship: design → implement-to-rigor → verify → review → capture, end to end |
| [`mastermind-debug`](./mastermind-debug/SKILL.md) | Structured six-phase debugging — evidence over guessing |
| [`mastermind-tdd`](./mastermind-tdd/SKILL.md) | Red → green → refactor; test-first design pressure |
| [`mastermind-verify`](./mastermind-verify/SKILL.md) | Confirm a change works by exercising it end-to-end — QA without a test suite (ask-first on tests) |
| [`mastermind-prototype`](./mastermind-prototype/SKILL.md) | Fast throwaway spike to answer one risky unknown, then rebuild properly |

## Think before you build
| Skill | Job |
| --- | --- |
| [`mastermind-learn`](./mastermind-learn/SKILL.md) | Just-in-time learning of the stack/field before building (roadmap.sh + primary docs) |
| [`mastermind-spec`](./mastermind-spec/SKILL.md) | Turn a fuzzy request into a crisp, buildable spec |
| [`mastermind-domain-model`](./mastermind-domain-model/SKILL.md) | Build the domain glossary — canonical terms, resolved naming |
| [`mastermind-grill`](./mastermind-grill/SKILL.md) | Interrogate your understanding against the real docs before building |

## Keep the work moving
| Skill | Job |
| --- | --- |
| [`mastermind-handoff`](./mastermind-handoff/SKILL.md) | Write a concise handoff so work survives a `/clear` or takeover |
| [`mastermind-levelup`](./mastermind-levelup/SKILL.md) | Level MasterMind up — capture lessons / refresh curriculum / bootstrap a field |

The library grows freely — add a skill for any distinct, useful workflow, held to the one-job + lean-
description + on-demand-body bar. Register every new skill here.
