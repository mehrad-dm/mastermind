---
name: mastermind-handoff
description: Write a concise handoff so work survives a context reset or a teammate/next-session takeover — what's done, what's next, key decisions and why, where things live, and the gotchas. Use before a /clear on a long task, when pausing, or when handing off. A summary, not a context dump.
---

# MasterMind — Handoff

Context is the fundamental constraint (`~/.mastermind/engineering/core/agent-loop.md`); a long task shouldn't lose its thread to a
reset. Capture just enough to resume cold — high signal, low tokens.

## Capture

1. **Goal** — the outcome being built, in one line.
2. **State** — Done / In-progress / Next, as a short checklist. Be honest about what's *not* verified.
3. **Key decisions & why** — the non-obvious choices and their rationale (so they aren't relitigated).
4. **Map** — where the relevant code/files/config live; the entry points.
5. **Gotchas** — traps, failing things, env quirks, anything that bit you.
6. **How to resume & verify** — the exact command(s)/check to pick up and confirm green.

## Rules
Summarize, don't dump — link or point to detail rather than pasting it. Write it where the next session
will look (`HANDOFF.md`, a scratch file, or the issue). Prune it when the work completes.

## Output
A tight `HANDOFF.md`: goal, state checklist, decisions, file map, gotchas, resume+verify steps.
