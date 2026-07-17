---
name: signature
description: Decide whose coding voice the code should speak in, two ways. (A) Learn a team's real signature — the recurring patterns and corrections they give AI over and over — and turn them into clean, name-free rules the AI follows (patterns only, never judgments about people; identities never leave the Lab; proposes pack edits, never auto-applies; reads a real codebase, asks consent first). (B) Write in the documented public style of an engineer the user names (e.g. a well-known OSS author like Dan Abramov or Kent C. Dodds) — grounded in that person's real public work, on any code, never impersonation or fabricated opinions. Use to make MasterMind fit THIS team, convert repeated corrections into durable rules, or adopt an admired engineer's documented style as the active lens.
---

# Signature — whose voice should the code speak in?

Code has a *voice* — the tacit style choices that make it recognizably someone's. This skill sets that
voice deliberately, two ways.

## Two modes
- **A · Team signature** — capture *your* team's tacit style from its real codebase + the corrections
  people give the AI, and distil it into durable, name-free rules. Private, Lab-gated. (Phases 1–2 below.)
- **B · Authority signature** — write in the *documented public* style of an engineer the user names
  (e.g. a well-known OSS author). Grounded in their real public work; on any code, not just yours; a lens
  on taste, never impersonation. (See **Mode B** below.)

Pick from the ask: "make it fit *our* code / capture what we keep correcting" → **A**; "write this like
*so-and-so* / in the style of *that engineer*" → **B**.

---

## Mode A — capture a team's style, turn it into rules the AI follows

A codebase has a *real* style that's rarely written down — people can't list their own conventions, but
recognize a violation instantly. This mode surfaces that tacit style and makes it durable: **a correction
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

---

## Mode B — write in the documented style of a named engineer

The user names an engineer they admire — "write this like Dan Abramov", "make it read like Kent C. Dodds",
"in the style of *X*" — and MasterMind writes the code in that person's **documented public style**. Not
limited to your codebase; works on any code, any project. This is a *lens on taste*, not a new rulebook.

**What a signature actually is** — the recurring, *public* choices that make someone's code recognizable:
which primitives they reach for, how they name and factor things, their stance on abstraction vs.
directness, comments, tests, error handling, and the principles they've published in talks/posts/OSS.
Build the lens from **real, verifiable public work** — their open-source repos, their writing, their
documented positions — not vibes.

**Four rules — none skippable:**

1. **Documented, not fabricated.** Apply only style you can ground in their real public work. If you don't
   actually know how they'd write something, say so and fall back to `mentors.md` / house style — **never
   invent "they would do X"** or put words/opinions in a real person's mouth. Honesty over performance.
2. **Style is a lens; correctness is not up for grabs.** A persona shapes *taste* — naming, structure,
   idiom. It never overrides `core/rigor.md`, security, or a11y. "They'd skip the null-check" is not a
   licence to ship a bug. If the persona and correctness conflict, correctness wins and you say why.
3. **In the style of — not impersonation.** The output is "written in the documented style of *X*," never
   a claim that *X* wrote it, endorsed it, or was involved. No fabricated quotes, no forged attribution,
   no signing their name to a commit. It's a stylistic homage, stated as one.
4. **Known engineers only, from public record.** This is for public figures with a documented body of work
   (a private colleague's style is **Mode A**, Lab-gated — never profile a named private individual here).

**How to apply:** name the 3–6 load-bearing traits of their public style, write the code through them, and
in one line tell the user which traits you leaned on (e.g. "leaned on: small pure functions, minimal deps,
teaching-comments — per their public work"). Prefer their *principles* over surface mannerisms — a
signature is how someone decides, not just how they format. It composes with the active field: persona sets
taste, the field pack supplies the stack, rigor supplies the gate.

**Self-check before you claim the style (guards against shallow mimicry):** for each trait, ask *"can I
point to a real sample of their public work that shows it?"* — a repo, a talk, a post. If you can't ground
a trait in something they actually wrote, **drop it** rather than inventing a plausible-sounding one. A
stereotype of someone ("they'd use lots of patterns") is the failure mode; the real, cited habit is the
goal. When in doubt, say which traits you're confident about and which you're inferring.

## Gotchas
- **A convention is not a defect** — the commonest failure is "fixing" house style. When unsure, conform.
- **Negative signal dominates** — capture approvals too, or rules drift into timid nitpicks; retire a rule that keeps getting dismissed.
- **One incident is not a pattern** — respect the promotion bar.
- **Don't restate what tooling enforces** — if a lint rule/type/template guarantees it, strengthen that; keep only the "why."
- **`code-reviewer` finds defects; this captures style.** Keep the layers separate.
- **Mode B: homage, not forgery** — style you can cite, never invented opinions, never their name on the work. A cool signature that ships a bug still failed (rigor wins).
- **Mode B ≠ Mode A** — a public figure's documented style is fair game; a named private colleague's style stays in the Lab (Mode A). Don't cross the streams.
