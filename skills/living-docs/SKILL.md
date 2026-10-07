---
name: living-docs
description: "Use when the project's product, business or technical knowledge needs a home or has gone stale: \"document what this product is\", \"write down how the business works\", \"where is the source of truth for X?\", \"how is this codebase built?\", \"our docs are out of date\", starting a new product, joining an existing codebase with no docs, or after a feature converges and what it taught must outlive it. Not usage docs for one internal package (that's `explain`), not the decision history (that's `roadmap`)."
---

# MasterMind: Living docs

Three documents that describe the project **as it is today**, each fact written once
(`~/.mastermind/engineering/core/spec-driven.md`). Request: **$ARGUMENTS**.

| File | Answers | Typical sections |
| --- | --- | --- |
| `specs/product.md` | who it is for, what problem it solves, what it will never do | users, problem, value, scope and non-goals, key journeys |
| `specs/business.md` | how it sustains itself and what limits it | model and pricing, market, constraints, compliance, metrics that matter |
| `specs/tech.md` | how it is built and run | stack, architecture, data, integrations, environments, conventions |

Skeletons: `specs/.templates/<file>` if present, else [`templates.md`](templates.md) beside this file.
Create a file only when it has content. A library has no `business.md`.

## Write them

1. **Read before asking.** The code, configs, README, CI, `.mastermind/brief.md`, `specs/`, and the
   existing docs folder. Everything technical is a lookup, never a question.
2. **Ask for what only people know.** Who pays, who it is for, what it must never become. One question
   at a time, each with your recommended answer.
3. **Mark every unverified line.** A claim you inferred and nobody confirmed ends in `(unconfirmed)`.
   It loses the mark when the user confirms it or the code proves it.
4. **Point, never copy.** A section that would repeat a spec, the constitution or a config file becomes
   one line linking to it.
5. **Set the footer.** Each file ends with `Last verified: <YYYY-MM-DD> against <commit>`. With uncommitted
   changes, name the last commit plus "working tree".

## Keep them true

- **After `converge` reports converged**, promote what the feature taught that outlives it: a new
  user journey into `product.md`, a new service into `tech.md`. Then update the footer date.
- **When the code contradicts `tech.md`**, the code wins. Correct the doc in the same change.
- **Activity is not staleness.** Many commits since the footer date are a reason to re-read the doc,
  never proof it is wrong. Only a fact the code or the user contradicts makes it stale.
- **When something contradicts `product.md` or `business.md`**, the document wins until the user says
  otherwise. Ask them which one is wrong.
- **Rewrite in place.** These describe the present. The history of why lives in `.mastermind/MAP.md`
  (`roadmap`) and in the frozen feature folders.

## How they fit with what already exists

- **`.mastermind/brief.md`** stays the 40-line summary read on every task. When a living doc changes a
  fact the brief states, update the brief line too. The brief points into these files for depth.
- **The glossary** stays in the brief ("Words we use here"). Living docs use those exact words.
- **An existing `docs/` folder** stays where it is. Link to it from the matching living doc; never move
  or duplicate the team's files.

## Gotchas

- **A confident paragraph about the business, invented from the code, is the worst output here.** The
  code shows what was built, never why or for whom. Mark it `(unconfirmed)` or ask.
- **Docs grow until nobody reads them.** Near 200 lines, split by topic into `specs/tech/<topic>.md`
  and keep `tech.md` as the index.
- **Never put secrets, customer names or private numbers in a file that ships with the repo.** Those go
  in `lab/` (`quarantine`) and the doc says the fact exists and where it is kept.

## Report

Which files were created or updated, what was promoted from where, every line still `(unconfirmed)`,
and any doc that disagreed with the code.
