<p align="center">
  <img src="assets/logo.svg" width="96" height="96" alt="MasterMind logo" />
</p>

<h1 align="center">MasterMind</h1>

<p align="center">
  <a href="https://mastermind.mehrad.me"><strong>🌐 mastermind.mehrad.me</strong></a>
</p>

> A **genius-builder brain** for your AI coding assistant — it brings sharp defaults, real judgment,
> and the discipline to check its own work to Claude Code, Codex, Cursor, Copilot, and more.
> Just markdown, and it **improves itself** over time.

MasterMind is plain Markdown — no app, no dependencies. It's a set of instructions that loads into
your AI assistant and gives it better judgment, good defaults, and the discipline to check its own
work — the habits of the engineers who built the software world.

## Why it exists

Your AI already knows JavaScript, TypeScript, React, and algorithms. Teaching it those again just
wastes tokens and slows it down. MasterMind adds only what it's *missing*:

- **Good defaults** — which tool or pattern to reach for, so it picks the best option, not the average one.
- **A way to decide** — how to choose when there's no obvious default.
- **A habit of checking** — how to verify its work and never ship lazy code.
- **Experts to learn from** — whose approach to follow, with sources.
- **Lessons from real use** — it writes down what it learns and gets better.

## Architecture: a lean kernel + on-demand modules

An AI gets slower and less sharp as its context fills up. So the always-loaded part is tiny, and
everything else loads only when it's needed. The knowledge splits into a **universal core** (how to
think and work) and a **swappable field pack** (what to know for a specific domain).

```text
CLAUDE.md                     # the kernel — always loaded, ~90 lines
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
git clone https://github.com/mehrad-dm/mastermind.git ~/mastermind
cd ~/mastermind && ./install.sh          # sets up the brain + auto-detects Claude Code / Codex
```

`install.sh` symlinks the repo into a tool-neutral home, **`~/.mastermind`**, plus each tool's entry
file — so the repo stays the single source of truth, editing it updates every tool instantly, and
`git pull` upgrades them all. Nothing personal (Claude sessions/memory/settings) is touched or published.

### Or add it as a Claude Code plugin

The skills and agents are also published as a Claude Code plugin:

```text
/plugin marketplace add mehrad-dm/mastermind
/plugin install mastermind@mastermind
```

This registers the **skills and agents** (`build`, `tdd`, `debug`, … + `architect`, `code-reviewer`, …)
as native commands. One caveat: those skills and agents read the brain from **`~/.mastermind`**, so run
`install.sh` (above) once as well — otherwise their `~/.mastermind/engineering/…` references won't
resolve. Think of it as: `install.sh` gives you the brain, the plugin gives you the command surface.

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
