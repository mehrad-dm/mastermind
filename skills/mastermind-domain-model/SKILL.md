---
name: mastermind-domain-model
description: Build or sharpen a project's domain glossary — the canonical terms, their definitions, and resolved naming ambiguities — so code and conversation share one vocabulary. Use at the start of a non-trivial project or feature, or when naming feels muddled or two words mean the same thing.
---

# MasterMind — Domain Model

Names are the most-read documentation and the data model in disguise (`~/.mastermind/engineering/core/mindset.md`, `principles.md`).
A shared, precise vocabulary is what keeps a codebase coherent. Build one.

## Method

1. **Harvest the nouns.** Read the code, docs, and the user's words for the domain entities and concepts
   (e.g. Order, Customer, Invoice). List every term actually in use.
2. **Define each canonically** — one clear sentence per term, plus **what NOT to call it** (the synonyms
   to avoid). One concept, one name (SSOT for language).
3. **Resolve ambiguities** — where one word means two things, or two words mean one, pick the winner and
   record the resolution. A term that's overloaded is a bug waiting to happen.
4. **Map the relationships** — "an X holds many Y", "a Y carries one Z at a time." This is the data model.
5. **Write it down** — to `CONTEXT.md` (or `docs/glossary.md`). Then use these exact names in code, types,
   and conversation — rename drift on sight.

## Output
A tight glossary: each term, its definition, its avoid-list, the relationships, and any resolved
ambiguities. Short, authoritative, and kept honest as the domain evolves.
