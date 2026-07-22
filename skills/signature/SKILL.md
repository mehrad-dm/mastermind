---
name: signature
description: Use when code should match a team's real conventions the user keeps correcting the AI toward — "make it match our codebase", "follow our patterns", "you keep writing it wrong" — or when repeated corrections should become durable rules. Private, Lab-gated. For writing in a named public engineer's style, use `persona`.
---

# Signature — capture a team's style, turn it into rules the AI follows

A codebase has a *real* style that's rarely written down — people can't list their own conventions, but
recognize a violation instantly. This skill surfaces that tacit style and makes it durable: **a correction
you give once becomes a permanent rule, not a repeated fix.** Two phases — capture (private, in the Lab),
then distil (name-free, into a field pack).

> **The rule that never bends: patterns, not people.** Describe what the code does ("this codebase resolves
> X by Y"), never rate a person ("so-and-so writes bad code"). The artifact is the pattern; the person is
> incidental — and a file that judges a named person is a career-risk if it leaks. Group by contributor
> only as a *source of signal*, phrased neutrally.

## Phase 1 — Capture (private, stays in the Lab)

1. **Consent + Lab first.** Ask before scanning a real, possibly-private codebase (and which paths). All
   output has names, so it lands in `lab/` (gitignored) — if there's no Lab, set one up (`lab` skill) first.
2. **Two sources — the second is the gold:**
   - **Repeated corrections (highest value).** What people tell the AI over and over — "do X not Y",
     "always…", "stop doing…", recurring review comments, AI diffs reverted-and-redone. Explicit,
     human-validated, de-noised. Weight by **frequency** (seen 20× = a rule; once = noise). Read the
     corrections log if one exists; help start one if not.
   - **Codebase patterns (lower confidence).** Recurring idioms in code/history — naming, layout, how
     state/data/errors are handled. *Candidate* patterns, not truth (blame is noisy; in-repo ≠ endorsed).
3. **Output** — neutral profiles in `lab/analysis/`: `pattern` · `frequency` · `source` · first-pass
   `kind` (convention | correctness | unsure). Neutral wording is not optional — if you can't phrase it
   about the pattern, drop it.

## Phase 2 — Distil into rules (three gates, none skippable)

**Gate 1 — Classify: convention or correctness.**
- **Convention** (style — naming, layout, which primitive) → the rule is "match the house style," **never
  framed as a fix**; justification *is* "the team does it this way."
- **Correctness** (a real defect — a11y gap, unsafe input, a cache/lifecycle bug) → allowed **only** with a
  **primary-source citation + a concrete failure scenario**. No citation/failure → demote to convention or
  drop. The test: *"Can I cite a source saying this is wrong AND name a failure it causes?"*

**Gate 2 — Promotion bar (keep the pack lean).** A candidate graduates only if it **recurs** across more
than one source/author — the antidote to encoding one loud voice as team law, and to bloat. Replay it
against recent examples to confirm it holds. Use all three signals: **corrections** (add a rule),
**approvals** (confirm an existing rule is right — stop second-guessing it), and **implicit edits** (human
shipped it differently than proposed — the richest source of unstated conventions).

**Gate 3 — Sanitize (identities never leave the Lab).** Strip every project/product/person/package/host
name and replace with a generic description before anything reaches a field pack. If a rule can't be
expressed without an internal name, **it stays in the Lab.** The guards are the backstop, not a license.

## Output — propose, never apply
Hand surviving rules to **`levelup`** as **proposed** pack edits (`category · kind · generic rule · why
[+citation]`). Show the user the diff; **never auto-commit or push.** Convention → `lessons`/`stack-defaults`;
correctness-with-citation → same, tagged for the `code-reviewer` audit. Frontend today; the gates apply to any field.

## Gotchas
- **A convention is not a defect** — the commonest failure is "fixing" house style. When unsure, conform.
- **Negative signal dominates** — capture approvals too, or rules drift into timid nitpicks; retire a rule that keeps getting dismissed.
- **One incident is not a pattern** — respect the promotion bar.
- **Don't restate what tooling enforces** — if a lint rule/type/template guarantees it, strengthen that; keep only the "why."
- **`code-reviewer` finds defects; this captures style.** Keep the layers separate.
- **A named private colleague's style stays here (Lab-gated), never in `persona`.** `persona` is for public figures with a documented body of work; a real coworker's style is Mode-A material and never leaves the Lab.
