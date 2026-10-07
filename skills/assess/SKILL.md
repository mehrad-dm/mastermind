---
name: assess
description: "Use when someone wants to know whether an idea deserves building before anyone builds it: \"is this worth doing?\", \"should we build X?\", \"evaluate this idea\", \"would users actually want this?\", \"help me decide whether to invest in this\", a product or business idea with no code yet, or a feature request nobody has said yes to. Not for scoping something already decided (that's `interview` or `specify`), not for adopt-vs-build on a library (that's `tech-scout`)."
---

# MasterMind: Assess

A documented "stop" is a good outcome. This decides whether an idea earns a spec, using evidence rather
than enthusiasm (`~/.mastermind/engineering/core/product-sense.md`). It works in a folder with no code.
Paths follow `~/.mastermind/engineering/core/spec-driven.md`.
Idea: **$ARGUMENTS**.

Write one file, `specs/ideas/<slug>.md`, from `specs/.templates/idea.md` if present, else
[`template.md`](template.md) beside this file. Fill it stage by stage; each stage refines the same
file instead of producing a new one.

## The five stages

1. **Intake.** The idea in one sentence, who asked, and who it is for. Then the problem it removes, in
   that person's words. An idea with no named person and no named problem stops here as `clarify`.
2. **Research.** What exists today: the workaround people use, the competitors, the prior attempt in
   this codebase. Search the code by the concept, not the request's wording, and read earlier verdicts in
   `specs/ideas/`. An idea already built stops here with its path; one already stopped needs new evidence. Cite every claim with its source. Label each finding *observed*, *reported* or *assumed*.
3. **Define.** The outcome that would mean it worked, as one to three measurable signals with a target
   and a deadline. Then the constraints: budget, legal, technical, the constitution if one exists.
4. **Shape.** The smallest version that would test the outcome. What it leaves out. The two or three
   assumptions it stands on, each with the cheapest test that could prove it false.
5. **Decide.** One verdict, with its reasons and what would change it:

| Verdict | Means | Next |
| --- | --- | --- |
| **go** | the evidence supports it and the smallest version is clear | hand the shaped version to `specify` |
| **clarify** | a named unknown decides it and can be resolved | the unknown, who resolves it, by when |
| **stop** | the evidence is against it, or the cost outweighs the outcome | the reason, and what would reopen it |

## Gotchas

- **Enthusiasm is not evidence.** "Users would love this" with no source is an assumption. Write it as one.
- **Do not grade your own research.** Before deciding, send the shaped version and its assumptions to a
  fresh-context reviewer with the brief from `interview`'s red-team pass. Fold in what survives.
- **Stopping is the decision people avoid.** If every assumption is untested and the cost is high, the
  honest verdict is `clarify` with the cheapest test, never `go` on hope.
- **The decision is the user's.** You recommend with reasons; they own go or stop. Record who decided.
- **No market numbers from memory.** A figure without a fetched source is labelled `assumed`, or omitted.

## Report

The verdict, the two strongest reasons, the riskiest assumption and its test, and the file path. On
`go`, offer to start `specify` from the shaped version.
