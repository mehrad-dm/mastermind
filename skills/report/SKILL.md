---
name: report
description: "Use when the user asks for a written record of what was done, or at the end of a build or QA cycle only if the project's cycle-report preference is on. Off by default: never produce one unprompted."
disable-model-invocation: true
---

# report: a receipt for the work

Turn a completed cycle into a concise, skimmable record someone can read **without re-reading the diff**.
It's the same content as the in-chat verdict, made durable and shareable.

## When it runs

- **On request**: "give me a report", "write up what you did", "summarize this cycle".
- **Automatically** at the end of `build` / `qa` **only if** the project preference says so (below).
  Default is **off**: otherwise the in-chat verdict is the whole deliverable.

## Preference (per project): off by default

Read **`.mastermind/prefs.md`** in the project root for a `cycle-report:` line: one of:

- `off` (default, and the assumption if the file/key is missing): report only on explicit request.
- `ask`: at the end of a report-worthy cycle, offer once: *"want a report? markdown / html / no"*.
- `markdown`: always write a Markdown report.
- `html`: always write a self-contained HTML report.

It stays `off` until the user changes it ("reports on", "always give me html reports"): update the
line in `.mastermind/prefs.md` to match.

## What goes in it: signal, not a log

1. **Title + verdict**: Done · Done, not fully checked · Not done · Wrong thing, one line why,
   and the `not checked:` and `decided for you:` lines.
2. **What changed**: files touched (path + one-line what), grouped by area.
3. **Key decisions**: the non-obvious calls and the one-line reason (not what the model already knows).
4. **How it was verified**: what was actually run/observed end-to-end, and what it produced.
5. **Follow-ups / risks**: anything left, edge cases, TODOs.

Keep it tight: a bloated report gets ignored (same rule as the brain: signal density beats volume).

## Format

- **Markdown (default)**: write `.mastermind/reports/<slug>-<YYYY-MM-DD>.md` (use today's date), or a
  path the user names. Cheap, diffable, opens anywhere.
- **HTML (on request / `cycle-report: html`)**: one **self-contained** file (inline CSS, no external
  assets or scripts), lightly MasterMind-styled, so it opens in any browser. Costs more tokens.

Tool-agnostic: always a plain file on disk, so it survives whatever tool wrote it.

## Cost & restraint

An HTML report costs several times the output tokens of a Markdown one, and the in-chat verdict costs
almost nothing. Match effort to stakes: **for a one-line change, skip the report entirely**: offer
nothing. Reserve it for cycles someone would actually want to read or share.

## The optional quiz

A reader can skim a report and still not know what changed. Offer once, in one line at the end:
*"Want three questions to check the report says what you need?"* On a yes, write three questions whose
answers are in the report: what changed, how it was proven, and what is still open. Give the answers
after the user replies. Never ask the questions unprompted, and never offer twice in a session.
