---
name: help
description: Use when the user asks what MasterMind can do or how to drive it — "help", "what can you do", "how do I use this", "what commands are there", "list your skills", "what are my options" — or when they seem unsure how to get started.
---

# Help — what MasterMind can do, and how to use it

Present this as a clear, friendly menu (adapt length to the ask). **Open with the brand header**, then
lead with the one thing that matters most, then the tables. Keep it scannable. Header:

```
🧠  MasterMind — a genius-builder brain for your AI
    22 skills · 4 agents · Claude Code · Cursor · Codex
```

## Lead with what fits *this* project

Before the full menu, name **up to three** skills that would earn their keep here right now, each with
the reason it applies — read from what's actually in front of you (the stack, the current task, what the
last few turns were about, whether a field pack exists yet):

```text
Most useful here right now
  · init      — no field pack yet for this Django project; one-time setup, then I'm sharper on it
  · quarantine — there's client data in this repo; this keeps it out of git
  · handoff   — this session is long; a handoff survives the reset
```

A full menu is a catalogue; three fitting picks are advice. Then give the tables below — the catalogue
still matters, because the point is that the user learns what they already own.

## The one rule: you don't run commands — you just talk

MasterMind works by **recognizing intent**. Say what you want in plain language and it applies the right
skill or agent itself, then shows a short note that it did (e.g. `🧠 MasterMind ▸ building this — will verify
before handoff`, with `└ build · design → implement → verify` beneath it). The `/name` calls below are an **optional shortcut** — a way to *force* a specific skill — not
something you need to memorize. Every skill is **Auto** (the model can invoke it); you can also call any
of them by hand.

## Skills — the workflows (all Auto-invocable)

| Skill | What it does | Fires automatically when… | Call it by hand |
| --- | --- | --- | --- |
| **init** | set MasterMind up for this project — detect the stack (or ask what you're building), load the field pack | your first real task in a project it isn't set up for | *"init"* · *"set up MasterMind"* |
| **build** | design → implement → verify → review → capture, end to end | you ask to build/add/implement a non-trivial feature | *"build a search box for the header"* |
| **debug** | structured, evidence-first root-cause debugging | a bug is hard, weird, or keeps coming back | *"debug why the list doesn't refresh"* |
| **performance** | measure → find the real bottleneck → fix the biggest → verify | something's slow or janky ("why is this slow?") | *"why is this page so slow?"* |
| **qa** | prove a change works by driving it for real (+ optional tests) | you finish something / ask to test it | *"qa this"* · *"write tests for it"* |
| **report** | a shareable write-up of a cycle — changed files, decisions, verification, verdict (MD default, HTML on request) | you ask for a report; or end of build/qa if you turned it on (off by default) | *"give me a report of this"* · *"reports on"* |
| **interview** | turn a fuzzy ask into a crisp, buildable spec | the request is ambiguous or spans many files | *"spec out the checkout flow first"* |
| **route** | load only the files/skills a task actually needs | a task is non-trivial or you're unsure where to start | *"route this"* |
| **learn** | get up to speed fast on an unfamiliar stack/API, verify assumptions | the tech is new, fast-moving, or you're guessing | *"learn how the Stripe API handles refunds"* |
| **prototype** | build a throwaway spike to learn, then rebuild properly | the right approach is genuinely unknown | *"spike a quick prototype of this"* |
| **signature** | capture your team's real conventions as durable rules it follows | you ask it to match your codebase / keep correcting the same thing | *"make it match our patterns"* |
| **persona** | write in the documented public style of a named engineer, cited | you ask for someone's style ("write like X") | *"write this like Kent C. Dodds"* |
| **explain** | write AI-friendly usage docs beside an internal package | an internal package has little/no docs (asks first) | *"explain this package"* |
| **prompt** | sharpen a vague prompt into a precise, AI-ready one | you ask to optimize/fix a prompt for an AI | *"improve this prompt"* |
| **quarantine** | set up a private, gitignored quarantine for confidential data | before capturing project/client-specific notes | *"set up a lab here"* |
| **levelup** | improve MasterMind's own knowledge (lessons, curriculum, new field) | after a correction/review, or to refresh standards | *"levelup — remember this"* |
| **double-check** | interrogate a claim before handing it over — adversarial, reviewer never sees your conclusion | you're about to say "it works", or a review came back suspiciously clean | *"doubt this"* |
| **deprecate** | remove/migrate/retire safely — expand → migrate → contract | deleting a feature, column, flag, or endpoint | *"can we delete this?"* |
| **roadmap** | a durable decision map for multi-week work | work spanning many sessions; "why did we decide X?" | *"map this project"* |
| **lint** | check MasterMind's own files for bloat, repeated rules, contradictions | before a release, or the brain feels bloated | *"lint the brain"* |
| **handoff** | write a concise handoff so work survives a reset/teammate | before a long-task `/clear`, pausing, or handing off | *"write a handoff"* |
| **help** | show this menu — what every skill/agent does and when it fires | you ask "what can you do?" / "help" / "how do I use this" | *"what can you do?"* |

## Agents — the deep expert roles (isolated context)

Agents run in their own context for a focused job. MasterMind delegates to them inside a task; you can
also summon one directly.

| Agent | What it does | Used automatically when… | Call it by hand |
| --- | --- | --- | --- |
| **architect** | designs the solution before code (boundaries, data model, APIs) | a feature is non-trivial (inside `build`) | *"architect this feature"* |
| **code-reviewer** | reviews a diff against the rigor gate; proposes fixes, never applies | after a change, before "done" | *"review this"* |
| **refactorer** | restructures working code to a better design, behavior-preserving | you ask to clean up / restructure working code | *"refactor this component"* |
| **tech-scout** | decides adopt-vs-build for a library/tool/pattern, with a verdict | choosing a dependency or approach | *"should we use Zustand or Redux here?"* |

## Skills vs agents (one line)

**Skills** are inline workflows that run in the current conversation; **agents** are separate expert
roles with their own fresh context for a heavier, focused job. You rarely pick — MasterMind reaches for
the right one and tells you.

## Getting set up

If MasterMind isn't set up for this project yet (no field pack for your stack), it will offer a **one-time
setup** — say *"init"* or just start working and it'll ask. Verify your install anytime with
`~/.mastermind/install.sh --check`.

**Two optional preferences** (per project, both **off** by default, kept in `.mastermind/prefs.md`):
- **cycle report** — a written write-up at the end of a build/QA cycle. Turn on: *"reports on"*.
- **plan-first** — on bigger tasks, MasterMind shows the plan and waits for your OK before editing. Turn on:
  *"plan first from now on"*.

Both behave exactly as their implementations define them — `skills/build/SKILL.md` (plan-first gate) and
`skills/report/SKILL.md` (report formats).
