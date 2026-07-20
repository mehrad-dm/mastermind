---
name: lab
description: Use before capturing anything confidential in a repo — a client's internal patterns, private project data, real names, proprietary code — or when the user says "this is sensitive", "don't commit this", "set up the lab". Also when a Lab already exists but its guards are missing or broken.
---

# Lab Init — a safe place for project data

The Lab is where MasterMind keeps **raw, project-specific material** — codebase notes, captured
patterns, `/character` profiles, anything with real names. It is **local and gitignored**; only the
**genericized, name-free output** ever graduates to a shareable field pack. This exists because raw
material sitting in a publishable tree is how confidential data leaks. Make it structural, not a habit.

> **Golden rule: patterns leave the Lab, identities never do.** Company/product/person/package names
> stay in `lab/`. Only the general rule — stripped of every name — goes into a field pack.

## What it sets up

```
lab/
├── .denylist        ← your sensitive terms (gitignored); feeds the guards
├── raw/             ← untouched captures from a codebase
├── analysis/        ← working notes, /character profiles
└── MANIFEST.md      ← what's here, what's distilled, what's pending
.githooks/
├── pre-commit       ← blocks staged lab/ paths, denylisted terms, and real secrets
└── pre-push         ← scans every commit being pushed (catches --no-verify + old history)
```

## Steps (idempotent — safe to re-run)

Run from the target repo root. The skill's files live in `assets/` next to this SKILL.md.

1. **Create the quarantine** (don't clobber existing content):
   - `mkdir -p lab/raw lab/analysis`
   - If `lab/.denylist` is missing, copy `assets/denylist.template` → `lab/.denylist`, then help the
     user fill it: company, product/app names, internal package scopes (`@acme/*`), colleague names,
     private domains/hosts. **Never commit this file.**
   - If `lab/MANIFEST.md` is missing, copy `assets/MANIFEST.template.md` → `lab/MANIFEST.md`.

2. **Gitignore the Lab** — if `lab/` isn't already ignored, append `assets/gitignore-snippet.txt` to the
   repo's `.gitignore`. Verify with `git check-ignore lab/`.

3. **Install the guards:**
   - `mkdir -p .githooks && cp assets/pre-commit assets/pre-push .githooks/ && chmod +x .githooks/pre-commit .githooks/pre-push`
   - `git config core.hooksPath .githooks`
   - If the repo already has a `core.hooksPath` or a hook manager (Husky, etc.), **don't overwrite it** —
     tell the user and offer to chain the guard into their existing pre-commit instead.

4. **Prove it works** (do this — a guard you haven't tested is a guard you don't have):
   - Stage a throwaway file containing a denylisted term and attempt a commit; confirm it's **blocked**,
     then unstage. Try staging a `lab/` file; confirm the quarantine **blocks** it.

5. **Report** what was created/changed, and remind: raw data → `lab/`; only genericized output ships.

## Guardrails

- **The guards are generic and safe to publish; the denylist is not** — terms live only in the gitignored
  `lab/.denylist`. Never bake a real name into a hook, `.gitignore`, or the manifest (use `*-glob` patterns).
- **Escape hatch:** `ALLOW_SENSITIVE=1 git commit …` bypasses the guard for a deliberate, reviewed case.
- **Not a substitute for review** — the guard catches known terms and obvious secrets, not everything.
  Read a diff before pushing to any public remote (`core/agent-loop.md`).
- Distilling `lab/` into a pack is a separate step (the `mastermind-levelup` capture flow) — this skill
  only stands up the safe container.
