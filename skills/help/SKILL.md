---
name: help
description: Show the user what MasterMind can do and how to drive it — the full menu of skills and agents, each with the scenario it fires in AUTOMATICALLY and an example of how to call it BY HAND, plus which are auto vs on-request. Use when the user asks "what can you do", "help", "how do I use this", "what commands/skills are there", "list your abilities", or otherwise seems unsure how to drive MasterMind.
---

# Help — what MasterMind can do, and how to use it

Present this as a clear, friendly menu (adapt length to the ask). Lead with the one thing that matters
most, then the tables. Keep it scannable.

## The one rule: you don't run commands — you just talk

MasterMind works by **recognizing intent**. Say what you want in plain language and it applies the right
skill or agent itself, then shows a one-line note that it did (e.g. `▸ build → design · implement ·
verify`). The `/name` calls below are an **optional shortcut** — a way to *force* a specific skill — not
something you need to memorize. Every skill is **Auto** (the model can invoke it); you can also call any
of them by hand.

## Skills — the workflows (all Auto-invocable)

| Skill | What it does | Fires automatically when… | Call it by hand |
| --- | --- | --- | --- |
| **build** | design → implement → verify → review → capture, end to end | you ask to build/add/implement a non-trivial feature | *"build a search box for the header"* |
| **debug** | structured, evidence-first root-cause debugging | a bug is hard, weird, or keeps coming back | *"debug why the list doesn't refresh"* |
| **qa** | prove a change works by driving it for real (+ optional tests) | you finish something / ask to test it | *"qa this"* · *"write tests for it"* |
| **spec** | turn a fuzzy ask into a crisp, buildable spec | the request is ambiguous or spans many files | *"spec out the checkout flow first"* |
| **route** | load only the files/skills a task actually needs | a task is non-trivial or you're unsure where to start | *"route this"* |
| **learn** | get up to speed fast on an unfamiliar stack/API, verify assumptions | the tech is new, fast-moving, or you're guessing | *"learn how the Stripe API handles refunds"* |
| **spike** | build a throwaway spike to learn, then rebuild properly | the right approach is genuinely unknown | *"spike a quick prototype of this"* |
| **signature** | write in your team's style, or a named engineer's documented style | you ask it to fit your conventions / "write like X" | *"write this like Kent C. Dodds"* |
| **explain** | write AI-friendly usage docs beside an internal package | an internal package has little/no docs (asks first) | *"explain this package"* |
| **prompt** | sharpen a vague prompt into a precise, AI-ready one | you ask to optimize/fix a prompt for an AI | *"improve this prompt"* |
| **lab** | set up a private, gitignored quarantine for confidential data | before capturing project/client-specific notes | *"set up a lab here"* |
| **levelup** | improve MasterMind's own knowledge (lessons, curriculum, new field) | after a correction/review, or to refresh standards | *"levelup — remember this"* |
| **handoff** | write a concise handoff so work survives a reset/teammate | before a long-task `/clear`, pausing, or handing off | *"write a handoff"* |

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
setup** — say *"initialize"* or just start working and it'll ask. Verify your install anytime with
`~/.mastermind/install.sh --check`.
