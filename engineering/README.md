# MasterMind — a portable, field-parameterized genius-builder brain

This folder is **MasterMind**: a **model-agnostic knowledge base** that turns any capable AI into a
dedicated genius builder + software architect. It is plain Markdown on purpose — it works with Claude
Code, Cursor, Copilot, ChatGPT, or a raw system prompt.

## Design principle: encode judgment, not knowledge

A frontier model already knows JavaScript, TypeScript, React, CSS, algorithms. Re-teaching those
wastes tokens and makes the assistant heavy and slow. So these docs contain only what the model
lacks: **defaults, a decision framework, a rigor protocol, masters to align with**, and **lessons
learned from real usage**. Everything is opinionated and defensible; where context overrides an
opinion (e.g. RTL, per the project's audience), the docs say so.

## Architecture: kernel + on-demand modules

A lean always-on kernel (`CLAUDE.md`) plus modules loaded only when relevant. Split into a
**universal core** (how to think & work) and a **swappable field pack** (what to know for the domain).
The brain lives at the tool-neutral canonical path **`~/.mastermind/`** (symlinked from the repo by
`install.sh`); each tool's entry file just points here, so editing the repo updates every tool at once.

```
~/.mastermind/                    # canonical, tool-neutral (symlink → the repo)
├── CLAUDE.md                     # the kernel — always loaded, tiny
├── AGENTS.md                     # → CLAUDE.md (entry file for Codex & generic agents)
├── agents/                       # specialist roles (architect, code-reviewer, refactorer, tech-scout)
├── skills/                       # growable library (build, debug, spec, learn, qa, … + levelup)
└── engineering/
    ├── README.md                 # this file
    ├── active-field.md           # which field is active + how leveling works
    ├── ROUTER.md                 # generated manifest (scripts/build-router.mjs) — load only what a task needs
    ├── core/                     # UNIVERSAL — field-agnostic
    │   ├── mindset.md            # genius-builder mental models (the operating soul)
    │   ├── principles.md         # decision framework + clean-code laws
    │   ├── rigor.md              # the quality gate + refuse-list + the verdict
    │   ├── agent-loop.md         # how to execute: verify-loop, explore→plan→implement, context
    │   └── product-sense.md      # product & business literacy — scope tasks & specs right
    └── fields/
        └── _template/            # FIELD SCAFFOLD — init builds a field from this
            ├── field.md          # pack manifest
            ├── stack-defaults.md # opinionated tool-by-tool defaults
            ├── mentors.md        # the field's authorities to align with
            ├── curriculum.md     # vetted, API-verified repos/books/people/docs
            ├── learning-sources.md
            ├── audit-rules.md    # framework-specific defect checks for code-reviewer
            └── lessons.md        # durable lessons from real usage (the leveling record)
```

No field pack ships — a pack tuned to someone else's stack is worse than none. `init` builds the field
for the project's real stack from this scaffold, and the project owns it thereafter.

## Load-on-demand map

| Module | Load when |
| --- | --- |
| `core/mindset.md` | Always — the default way of thinking |
| `core/principles.md` | Any design/refactor decision |
| `core/rigor.md` | Every non-trivial task |
| `core/agent-loop.md` | Executing any task |
| `core/product-sense.md` | Scoping a task / unclear "why" or spec |
| `fields/<active>/stack-defaults.md` | Choosing a tool/lib/pattern |
| `fields/<active>/mentors.md` | Taste/philosophy is contested |
| `fields/<active>/curriculum.md` | Going deep / recommending resources |
| `fields/<active>/learning-sources.md` | Design-system work or an unfamiliar topic |
| `fields/<active>/lessons.md` | Always relevant — what's been learned |

## How it improves (leveling up)

MasterMind's weights are fixed; it gets better by **editing this knowledge base**. The
`levelup` skill captures corrections/review-findings into the active field's `lessons.md`,
refreshes the curriculum against the live ecosystem, or bootstraps a new field pack. See
`active-field.md`.

## Use with any AI

Run `install.sh` once to symlink the brain to `~/.mastermind/` + each tool's entry file (see the root
`README.md` for the full table). Then:

- **Claude Code** — auto-loaded via `~/.claude/CLAUDE.md` → the repo. Nothing more to do.
- **Codex** — reads `~/.codex/AGENTS.md` → the repo. Nothing more to do.
- **Cursor / Copilot** — add a one-line rule pointing at `~/.mastermind/CLAUDE.md`.
- **ChatGPT / any chat** — paste `core/mindset.md` + `core/principles.md` + the field's
  `stack-defaults.md` at the top of a session.

Keep every file tight and high-signal. If a rule isn't load-bearing, delete it.
