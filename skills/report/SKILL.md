---
name: report
description: Use when the user asks for a written record of what was done — "write it up", "give me a report", "summarize what you changed", "document this cycle" — or at the end of a build/QA cycle ONLY if the project's cycle-report preference is on. Off by default: never produce one unprompted, and skip it for a one-line change.
---

# report — a receipt for the work

Turn a completed cycle into a concise, skimmable record someone can read **without re-reading the diff**.
It's the same content as the in-chat verdict, made durable and shareable.

## When it runs

- **On request** — "give me a report", "write up what you did", "summarize this cycle".
- **Automatically** at the end of `build` / `qa` **only if** the project preference says so (below).
  Default is **off** — never auto-generate otherwise.

## Preference (per project) — off by default

Read **`.mastermind/prefs.md`** in the project root for a `cycle-report:` line — one of:

- `off` (default, and the assumption if the file/key is missing) — never auto-report.
- `ask` — at the end of a report-worthy cycle, offer once: *"want a report? markdown / html / no"*.
- `markdown` — always write a Markdown report.
- `html` — always write a self-contained HTML report.

The `init` skill sets this once, at the first task. The user can change it anytime ("reports off",
"always give me html reports") — update the line in `.mastermind/prefs.md` to match.

## What goes in it — signal, not a log

1. **Title + verdict** — ship / needs-work / redirect, one line why.
2. **What changed** — files touched (path + one-line what), grouped by area.
3. **Key decisions** — the non-obvious calls and the one-line reason (not what the model already knows).
4. **How it was verified** — what was actually run/observed end-to-end (never "looks right").
5. **Follow-ups / risks** — anything left, edge cases, TODOs.

Keep it tight — a bloated report gets ignored (same rule as the brain: signal density beats volume).

## Format

- **Markdown (default)** — write `.mastermind/reports/<slug>-<YYYY-MM-DD>.md` (use today's date), or a
  path the user names. Cheap, diffable, opens anywhere.
- **HTML (on request / `cycle-report: html`)** — one **self-contained** file (inline CSS, no external
  assets or scripts), lightly MasterMind-styled, so it opens in any browser. Costs more tokens.

Tool-agnostic: always a plain file on disk — never rely on a tool-specific artifact surface.

## Cost & restraint

An HTML report adds meaningful output tokens (~1.5–4k) vs Markdown (~0.4–1k); the in-chat verdict is
~free. Match effort to stakes: **for a one-line change, skip the report entirely** — offer nothing. Reserve
it for cycles someone would actually want to read or share.
