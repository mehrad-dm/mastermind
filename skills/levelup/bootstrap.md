# `bootstrap <field>` — create a new field pack

Reference for `levelup` — read this only when creating a field pack.

The goal: the user names a field (or points at a project) and gets a strong, tailored pack — built to a
high bar for their real stack — from one command. MasterMind ships no field, only the scaffold at
`engineering/fields/_template/`; this is what turns that scaffold into a real pack.

1. **Detect the user's actual stack — tailor to what *they* use, not a generic field.** Read the project:
   `package.json`/lockfile, configs, framework + versions, DB, test runner, folder shape (per
   `core/agent-loop.md`). If there's no project or it's ambiguous, ask **one** question: *"What stack —
   language, framework, database, key libraries?"* The pack must reflect their real tools.
2. **Scaffold from the template.** `cp -r engineering/fields/_template engineering/fields/<field>`, then
   fill every file (the template carries the shape + inline guidance).
3. **Research + write it to a high bar.** Do the verified sweep (best repos/courses/people/docs, each
   checked) for `curriculum.md`/`mentors.md`/`learning-sources.md`, and write an **opinionated
   `stack-defaults.md`** for *their* stack — `Default → when to deviate → what to avoid`, only the
   *non-obvious* decisions (not what the model already knows), grounded in primary sources. Deep and dense
   enough to change behavior, lean enough to fit one real stack. Start `lessons.md` empty.
4. **Point the active field at it** (`active-field.md`) if the user wants it live, and **do NOT touch
   `engineering/core/*`** — it's field-agnostic and shared.
5. **Keep the pack routable.** Every pack file except `field.md` needs `route_when` frontmatter, and the
   pack needs `field.md` + `audit-rules.md`, or the router skips it silently. Verify with
   `node scripts/check-integrity.mjs`, then regenerate with `node scripts/build-router.mjs`.
