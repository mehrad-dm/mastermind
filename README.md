<p align="center">
  <img src="assets/logo.svg" width="96" height="96" alt="MasterMind logo" />
</p>

<h1 align="center">MasterMind</h1>

<p align="center">
  <a href="https://mastermind.mehrad.me"><strong>🌐 mastermind.mehrad.me</strong></a>
</p>

> A portable, field-parameterized **genius-builder brain** for AI coding assistants — turn any capable
> model (Claude Code, Cursor, Copilot, ChatGPT) into a dedicated senior engineer that decides
> correctly, ships rigorously, and **levels itself up** over time.

MasterMind is plain Markdown. No runtime, no dependencies. It's a set of instructions and knowledge
that loads into an AI assistant to raise its floor — the judgment, defaults, rigor, and taste of the
people who built the software world.

## Why it exists

A frontier model already knows JavaScript, TypeScript, React, algorithms. Re-teaching those wastes
tokens and makes an assistant heavy and slow. MasterMind encodes only what the model *lacks*:

- **Defaults** — which tool/pattern to reach for, so it picks the *best* option, not the average one.
- **A decision framework** — how to choose when there's no default.
- **A rigor protocol** — how to stay dedicated and never ship lazy work.
- **Masters to align with** — whose school of thought to follow, with sources.
- **Lessons from real usage** — it records what it learns and gets better.

## Architecture: a lean kernel + on-demand modules

Performance degrades as context fills, so the always-loaded layer is tiny and everything else loads
only when relevant. The knowledge splits into a **universal core** (how to think & work) and a
**swappable field pack** (what to know for a domain).

```text
CLAUDE.md                     # the kernel — always loaded, ~60 lines
engineering/
├── active-field.md           # which field is active + how leveling works
├── core/                     # UNIVERSAL — field-agnostic
│   ├── mindset.md            # genius-builder mental models (the operating soul)
│   ├── principles.md         # decision framework + clean-code laws
│   ├── rigor.md              # the quality gate + refuse-list
│   ├── agent-loop.md         # how to execute: verify-loop, explore→plan→implement, context
│   └── product-sense.md      # product & business literacy — scope tasks & specs right
└── fields/frontend/          # FIELD PACK — swap or add packs per domain
    ├── stack-defaults.md     # opinionated tool-by-tool defaults
    ├── mentors.md · curriculum.md · learning-sources.md
    └── lessons.md            # durable lessons from real usage (the leveling record)
agents/                       # architect, code-reviewer, refactorer, tech-scout
skills/                       # growable library — build, tdd, debug, spec, learn, grill, … (see skills/README.md)
```

## Install

```bash
git clone https://github.com/<you>/mastermind.git ~/mastermind
cd ~/mastermind && ./install.sh          # canonical + auto-detects Claude Code / Codex
```

`install.sh` symlinks the repo into a tool-neutral home, **`~/.mastermind`**, plus each tool's entry
file — so the repo stays the single source of truth, editing it updates every tool instantly, and
`git pull` upgrades them all. Nothing personal (Claude sessions/memory/settings) is touched or published.

### Per tool

| Tool | How MasterMind loads | Set up by |
| --- | --- | --- |
| **Claude Code** | `~/.claude/CLAUDE.md` + native `agents/` & `skills/` | `./install.sh claude` |
| **Codex** | `~/.codex/AGENTS.md` (the repo's `AGENTS.md`) | `./install.sh codex` |
| **Cursor / Composer** | a rule: `.cursor/rules/mastermind.mdc` → *"Follow `~/.mastermind/CLAUDE.md`."* | per project |
| **GitHub Copilot** | `.github/copilot-instructions.md` → *"Follow `~/.mastermind/CLAUDE.md`."* | per project |
| **Any project, any agent** | drop `ln -s ~/.mastermind/AGENTS.md AGENTS.md` in the repo root | per project |
| **Plain chat (ChatGPT, …)** | paste `core/mindset.md` + `core/principles.md` + the field's `stack-defaults.md` | — |

Because the brain lives at the stable path `~/.mastermind/`, every tool references the same files —
edit once, improve everywhere.

## Set the field

MasterMind is field-parameterized. Edit `engineering/active-field.md` to point at a field pack
(frontend today). To add a new domain, `bootstrap` a pack (see below) — the universal `core/` never
changes between fields.

## How it levels up

An LLM's weights are fixed; MasterMind improves by **editing its own knowledge base**. The
`mastermind-levelup` skill:

- **capture** — turns corrections and code-review findings into durable lessons in the field pack;
- **refresh** — re-verifies the field's best-practice curriculum against the live ecosystem;
- **bootstrap `<field>`** — researches and generates a whole new field pack.

Every run bumps a level marker, so improvement is visible and git-reversible.

## Skills & agents

| | What it does |
| --- | --- |
| `/mastermind-build` | The flagship loop: design → implement-to-rigor → verify → adversarial review → capture |
| `/mastermind-tdd` | Red → green → refactor; test-first design pressure |
| `/mastermind-debug` | Structured six-phase debugging — evidence over guessing |
| `/mastermind-prototype` | Fast throwaway spike to answer one risky unknown, then rebuild properly |
| `/mastermind-learn` | Just-in-time stack/field learning (roadmap.sh + primary docs) before building |
| `/mastermind-spec` | Turn a fuzzy request into a crisp, buildable spec |
| `/mastermind-domain-model` | Build the domain glossary — canonical terms, resolved naming |
| `/mastermind-grill` | Interrogate your understanding against the real docs before building |
| `/mastermind-handoff` | Write a handoff so work survives a `/clear` or takeover |
| `/mastermind-levelup` | Capture lessons / refresh curriculum / bootstrap a field |
| `architect` (agent) | Blueprint before code — boundaries, data model, state, decisions |
| `code-reviewer` (agent) | Adversarial diff review against the rigor gate |
| `refactorer` (agent) | Behavior-preserving structural redesign toward deeper modules |
| `tech-scout` (agent) | Build-vs-buy / library-selection decisions, reuse-with-judgment |

## Model-agnostic by design

Everything is plain Markdown with no runtime — it works with any model (Claude, GPT/Codex, Gemini,
local) and any tool (see the install table). Claude Code gets native agents and skills; other tools
read the same `agents/` and `skills/` files and follow them as procedures. One brain, every editor.

## Use it in your projects

MasterMind installs **globally**, so once set up it's active in *every* project you open — no
per-project setup for Claude Code or Codex. Just work: ask for a feature and it applies its defaults,
rigor, and loop; run `/mastermind-build` to drive design→implement→verify→review→learn end to end.
Improve the brain in the repo and every project picks it up instantly.

## Credits

Created and maintained by [**mehrad-dm**](https://github.com/mehrad-dm). Built with **Claude Code** (Anthropic).

## License

MIT — see [LICENSE](LICENSE).
