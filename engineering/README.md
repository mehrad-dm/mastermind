# MasterMind: a portable, field-parameterized genius-builder brain

This folder is **MasterMind**: a **model-agnostic knowledge base** that turns any capable AI into a
dedicated genius builder + software architect. It is plain Markdown on purpose: no tool-specific
mechanisms inside, so it loads from a file, a rule, or a pasted system prompt alike.

## Design principle: encode judgment, not knowledge

A frontier model already knows JavaScript, TypeScript, React, CSS, algorithms. Re-teaching those
wastes tokens and makes the assistant heavy and slow. So these docs contain only what the model
lacks: **defaults, a decision framework, a rigor protocol, masters to align with**, and **lessons
learned from real usage**. Everything is opinionated and defensible; where context overrides an
opinion (e.g. RTL, per the project's audience), the docs say so.

## Architecture: kernel + on-demand modules

A lean always-on kernel (`CLAUDE.md`) plus modules loaded only when relevant. Split into a
**universal core** (how to think & work) and a **swappable field pack** (what to know for the domain).
A per-project install copies the brain into the project's `.mastermind/`; a shared or global install
uses the one in your home directory. Each tool's entry file points at the brain.

```
~/.mastermind/                    # the brain (a project's own copy, or the shared one)
├── CLAUDE.md                     # the kernel: always loaded, tiny
├── AGENTS.md                     # → CLAUDE.md (the open entry file for agentic tools)
├── agents/                       # specialist roles (architect, code-reviewer, refactorer, tech-scout)
├── skills/                       # growable library (build, debug, interview, learn, qa, … + levelup)
└── engineering/
    ├── README.md                 # this file
    ├── active-field.md           # which field is active + how leveling works
    ├── ROUTER.md                 # generated manifest (scripts/build-router.mjs): load only what a task needs
    ├── core/                     # UNIVERSAL: field-agnostic
    │   ├── mindset.md            # genius-builder mental models (the operating soul)
    │   ├── principles.md         # decision framework + clean-code laws
    │   ├── rigor.md              # the quality gate + refuse-list + the verdict
    │   ├── agent-loop.md         # how to execute: verify-loop, stop conditions, failures, delegation
    │   ├── clarity.md            # the register for anything written
    │   ├── product-sense.md      # product & business literacy: scope tasks & specs right
    │   └── spec-driven.md        # spec-first features: layout, IDs, order
    └── fields/
        └── _template/            # FIELD SCAFFOLD: init builds a field from this
            ├── field.md          # pack manifest
            ├── stack-defaults.md # opinionated tool-by-tool defaults
            ├── mentors.md        # the field's authorities to align with
            ├── curriculum.md     # vetted, API-verified repos/books/people/docs
            ├── learning-sources.md
            ├── audit-rules.md    # framework-specific defect checks for code-reviewer
            └── lessons.md        # durable lessons from real usage (the leveling record)
```

No field pack ships: a pack tuned to someone else's stack is worse than none. `init` builds the field
for the project's real stack from this scaffold, and the project owns it thereafter.

## Load-on-demand map

| Module | Load when |
| --- | --- |
| `core/mindset.md` | A design call turns on why one of the kernel's four clauses holds |
| `core/principles.md` | Any design/refactor decision |
| `core/rigor.md` | Every non-trivial task |
| `core/agent-loop.md` | A loop, a failure, or a delegation needs its rule |
| `core/clarity.md` | Writing an explanation, a report, or an instruction |
| `core/product-sense.md` | Scoping a task / unclear "why" or spec |
| `core/spec-driven.md` | A feature goes spec-first |
| `fields/<active>/stack-defaults.md` | Choosing a tool/lib/pattern |
| `fields/<active>/mentors.md` | Taste/philosophy is contested |
| `fields/<active>/curriculum.md` | Going deep / recommending resources |
| `fields/<active>/learning-sources.md` | Design-system work or an unfamiliar topic |
| `fields/<active>/lessons.md` | Working in the field: what's been learned |

## How it improves (leveling up)

MasterMind's weights are fixed; it gets better by **editing this knowledge base**. The
`levelup` skill captures corrections/review-findings into the active field's `lessons.md`,
refreshes the curriculum against the live ecosystem, or bootstraps a new field pack. See
`active-field.md`.

## The supported tools

The installer wires each tool's entry file to the brain:

- **Claude Code**: the project's `CLAUDE.md` points at the kernel. The four agents are wired as subagents.
- **Cursor**: `.cursor/rules/mastermind.mdc` carries the kernel as an always-on rule.
- **Codex**: reads the project's `AGENTS.md`. `--global` also wires `$CODEX_HOME/AGENTS.md`.

Those three are the supported set. Anything else is unwired and unclaimed.

Keep every file tight and high-signal. If a rule isn't load-bearing, delete it.
