---
name: persona
description: Use when the user wants code written in the documented public style of a named engineer they admire — "write this like Dan Abramov", "make it read like Kent C. Dodds", "in the style of that OSS author". For a public figure with a real body of work; a private colleague's style is `signature` (Lab-gated). A lens on taste, never impersonation.
---

# Persona — write in the documented style of a named engineer

The user names an engineer they admire and MasterMind writes the code in that person's **documented public
style**. Works on any code, any project — not just your own. It's a *lens on taste*, not a new rulebook.

**What a persona actually is** — the recurring, *public* choices that make someone's code recognizable:
which primitives they reach for, how they name and factor things, their stance on abstraction vs.
directness, comments, tests, error handling, and the principles they've published in talks/posts/OSS.
Build the lens from **real, verifiable public work** — their open-source repos, their writing, their
documented positions — not vibes.

**Four rules — none skippable:**

1. **Documented, not fabricated.** Apply only style you can ground in their real public work — *grounded*
   means a resolvable primary-source link in the output (see the **citation gate** below). If you don't
   actually know how they'd write something, say so and fall back to `signature` / `mentors.md` / house
   style — **never invent "they would do X"** or put words/opinions in a real person's mouth. Honesty over
   performance.
2. **Style is a lens; correctness is not up for grabs.** A persona shapes *taste* — naming, structure,
   idiom. It never overrides `core/rigor.md`, security, or a11y. "They'd skip the null-check" is not a
   licence to ship a bug. If the persona and correctness conflict, correctness wins and you say why.
3. **In the style of — not impersonation.** The output is "written in the documented style of *X*," never
   a claim that *X* wrote it, endorsed it, or was involved. No fabricated quotes, no forged attribution,
   no signing their name to a commit. It's a stylistic homage, stated as one.
4. **Known engineers only, from public record.** This is for public figures with a documented body of work.
   A private colleague's style is `signature` (Lab-gated) — never profile a named private individual here.

**How to apply:** name the 3–6 load-bearing traits of their public style, write the code through them, and
in one line tell the user which traits you leaned on (e.g. "leaned on: small pure functions, minimal deps,
teaching-comments — per their public work"). Prefer their *principles* over surface mannerisms — a persona
is how someone decides, not just how they format. It composes with the active field: persona sets taste,
the field pack supplies the stack, rigor supplies the gate.

**Citation gate — every trait ships a resolvable link, or it doesn't ship:**

- **No citation, no trait.** Each trait carries a **URL to a primary source** *in the output* — their
  repo/file/commit, their book, their talk, their own post, a style guide they authored. An actual link the
  user can click, not "as documented by *X*". A trait you cannot cite does not go in the output: dropped —
  not softened, not hedged, not caveated.
- **Verify, don't assert.** This skill declares no `allowed-tools`, so it inherits the session's. If
  `WebSearch`/`WebFetch` are available, actually fetch each link and confirm it resolves and says what you
  claim — a check you *run*, not one you report. If they aren't, say so, cite only sources you can name
  precisely enough for the user to check by hand (exact repo + path, book + chapter, talk + title/year),
  and mark the set **unverified**. Never write "I checked / read / verified" for a check you didn't run.
- **No sources, no persona.** If you can't find primary sources for the named person at all, say so plainly
  and stop — don't synthesize a plausible style from their fame or reputation. Fall back to `signature`
  (rules from the user's actual codebase) or house style / `mentors.md`, and tell the user which.

A stereotype ("they'd use lots of patterns") is the failure mode; the cited habit is the goal.

## Gotchas
- **Homage, not forgery** — borrow the cited habit, never put their name on the work or invent opinions for
  them. A cool signature that ships a bug still failed (rigor wins).
- **Public figures only** — a real coworker's style is `signature`, Lab-gated. Don't cross the streams.
- **Principles over mannerisms** — copying surface tics (their brace style) misses the point; capture how
  they *decide* (what they abstract, what they leave direct).
