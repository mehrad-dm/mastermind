---
name: mastermind-learn
description: Get up to speed FAST on the stack, library, or field a task needs — before building. Detects the project's real stack, maps the field skill-tree (roadmap.sh), reads the primary docs for what the task touches, and returns a working understanding to current standards. Use for unfamiliar or fast-moving tech, or a new codebase. Distinct from mastermind-levelup (durable knowledge-base updates) — this is just-in-time, task-scoped learning.
---

# MasterMind — Learn

The invokable form of `core/agent-loop.md` → "Learn the stack before you build." Topic/task:
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
never rely on stale memory (`core/learning-sources.md`).

## 4. Ground it in this codebase
Grep for how the pattern is already used here and match it. Consistency beats novelty.

## Output & economy
Return a tight working brief: the stack + versions, the few APIs/patterns the task needs, the gotchas,
and links to the primary sources — not a tutorial. Delegate wide reading to a subagent to protect
context. If you learned something durable and reusable, capture it via `mastermind-levelup`.
