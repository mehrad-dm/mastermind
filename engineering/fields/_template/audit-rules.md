---
field: <field>
route_when: [review, audit, code-review, defect, lint]
---

# Audit rules — framework-specific defect checks

Data-style rules the **`code-reviewer`** loads to catch defects specific to this field's frameworks.
Without this file the reviewer falls back to the universal core alone and misses everything this
domain gets wrong most often — so fill it in, don't ship the pack empty.

Each rule is labelled **convention** (match house style, don't flag) or **correctness** (a real defect —
flag with a citation + the failure it causes). Only correctness rules trigger a must-fix; conventions
live in `lessons.md` / `stack-defaults.md` and are conformed to, never "fixed."

**Scope:** one `## <framework/library>` section per technology in this field. A rule fires **only when
that tech is actually in use** (detect it from the project's manifest — `package.json`, `pyproject.toml`,
`go.mod`, …); never impose one stack's checks on a file written in another.

Every finding is **proposed, never applied**, and needs a concrete failure scenario — not a style opinion.

## <Framework / library>

<!-- Rule shape — copy this line per rule. Prefer 5–12 load-bearing rules over an exhaustive list:
- **<The defect, stated so it's recognizable in a diff>** — *<correctness|convention|security|performance>.*
  <Why it breaks, concretely — the observable failure, not the abstraction.> <The fix.>
  [<primary-source citation: official docs section, spec, or lint rule name>.]
  *(<When NOT to flag it — the legitimate exception.>)*
-->

_(No rules yet — add them as `code-reviewer` findings and real usage reveal what this field
actually gets wrong. A rule earns its place by catching a defect that already happened.)_

## How the reviewer uses this

Load this file when this field's tech appears in the diff. For each match, apply the
convention/correctness gate: flag only correctness (with the citation above + a failure scenario),
propose the fix, and if the same defect recurs, recommend capturing it via `levelup` so generation
stops producing it.
