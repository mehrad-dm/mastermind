---
name: learn
description: Use when a task depends on tech you don't actually know — an unfamiliar library, a fast-moving framework, a tricky API, an unfamiliar codebase — or whenever "I think it works like…" is load-bearing. Just-in-time and task-scoped; distinct from levelup, which updates the durable knowledge base.
---

# MasterMind — Learn

The invokable form of `~/.mastermind/engineering/core/agent-loop.md` → "Learn the stack before you build." Topic/task:
**$ARGUMENTS**. Goal: reach genuine, *current* understanding — enough to build to standard — fast, and
cheap on context.

## 1. Detect what's actually used
Read `package.json`/lockfile, configs, and representative source to see the exact stack (framework +
**versions**, styling, state, data, test runner) and the team's conventions. Installed versions matter —
APIs drift, so learn the version that's actually here.

## 2. Map the skill-tree
Use the relevant **roadmap.sh** role/topic map as the checklist of what matters and to spot your gaps.
Don't learn the whole tree — learn the branch the task touches.

## 3. Learn to current standards
Read the **primary docs** for the specific APIs the task needs (verify against the installed version)
and skim one battle-tested example (the field's `curriculum.md` lists them). Prefer primary sources;
never rely on stale memory (the field's `learning-sources.md`).

## 4. Ground it in this codebase
Grep for how the pattern is already used here and match it. Consistency beats novelty.

## 5. Grill your assumptions before you build
The costly bugs come from assumptions you never checked. Before committing code:

- **List what you believe** about the APIs you'll use (behavior, signatures, return values, limits,
  versions, edge cases) — specifically ("`getFile` streams any size" — true?).
- **Answer from the source yourself first** — verify each against the docs/types/actual source (for the
  *installed* version). Confirm ✓, correct ✗, or mark unknown ❓. Never ask the user what the code/docs answer.
- **For each remaining unknown, propose — don't just flag.** State a best-guess resolution **+ confidence**
  ("probably streams; ~70%") so a human can confirm or correct, not author it. Serve interdependent
  unknowns one at a time. Anything still unconfirmed becomes an explicit risk or a tiny `spike` — never a
  silent guess. **No load-bearing assumption ships unverified.**

## Output & economy
Return a tight working brief: the stack + versions, the few APIs/patterns the task needs, the gotchas
(and the grilled assumptions ledger: claim → verified/corrected/unknown → source · confidence),
and links to the primary sources — not a tutorial. Delegate wide reading to a subagent to protect
context. If you learned something durable and reusable, capture it via `levelup`.
