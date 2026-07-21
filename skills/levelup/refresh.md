# `refresh` — track the moving ecosystem

Reference for `levelup` — read this only when running the `refresh` mode.

## Scope: one field, upstream only

**`refresh` is upstream maintenance — do it in the MasterMind repo, not on a user's install.** Refreshing
the curriculum, mentors, and agent-engineering best practices improves the *shared* brain; commit it
upstream so every user gets it on `git pull`. End users should not each re-run this research — that
fragments the knowledge base. (Per-install `capture` of a project-specific lesson is the exception, and it
stays local unless genericized.)

It refreshes **one field** — the one named in the argument, else the active field.

## Steps

1. Re-run the curriculum research for that field (the same multi-angle, verify-each-repo sweep that built
   `curriculum.md`): best repos/courses/people/docs, current, each GitHub repo checked against the API for
   existence + recent activity.
2. Diff against the current `curriculum.md`: add what's newly best-in-class, drop what's archived/dead,
   flag anything that changed. Update `learning-sources.md` and `mentors.md` if authorities shifted.
3. Note the refresh date in `curriculum.md`'s verification note.
4. **Listen to the source of truth for agent engineering** — Anthropic / Claude Code docs + changelog, the
   engineering blog, and **Claude Devs** (Anthropic's developer content) — on two axes:
   - **Evolving best practices** — prompting, model/effort, skills, context management.
   - **Newly shipped capabilities** — new tool types, skill/agent/hook mechanisms, slash-commands, MCP,
     subagents, and workflow primitives worth *adopting into MasterMind's architecture* to get better.

   **Stay tool-agnostic — this is a hard constraint, not a preference.** MasterMind runs on Codex, Cursor,
   Copilot, Gemini, and any AGENTS.md tool; the shared brain is portable Markdown that must load and work
   *everywhere*. So extract the **durable, portable principle**, never the vendor mechanism. A
   Claude-Code-only feature (hooks, native skills, slash-commands) may *sharpen the Claude path* as an
   additive enhancement, but must **never** become a hard dependency, or leave a rule that only makes sense
   inside Claude Code. If a capability can't be expressed portably, keep it out of `core/` and the kernel.
   Fold the durable ones into `engineering/core/`, `skills/levelup/authoring.md`, or the kernel; verify
   against the primary source, adopt the judgment (not the hype), and note the check date.

## The write allowlist — what makes "upstream only" checkable

"Upstream only" is worthless as a slogan; it is a rule about **which paths change**. A refresh may write
to these paths in the MasterMind repo, and **nothing else**:

| May write | Why |
| --- | --- |
| `engineering/fields/<field>/curriculum.md` | the sweep's own output |
| `engineering/fields/<field>/learning-sources.md` | authorities shifted |
| `engineering/fields/<field>/mentors.md` | authorities shifted |
| `engineering/core/*.md` | a durable, portable agent-engineering principle |
| `skills/levelup/authoring.md` | a durable skill/agent-authoring principle |
| `CLAUDE.md` | only if the principle must be always-on (kernel stays tiny) |
| `engineering/active-field.md` | the level bump + dated changelog line |

**Never touch:**

- `engineering/ROUTER.md` and the site's generated `library/` pages — **generated artifacts**. Never
  hand-edit; regenerate them with `scripts/build-router.mjs` / `scripts/build-library.mjs` at the end.
- `engineering/fields/<field>/lessons.md` — that file belongs to `capture`, not to a refresh.
- `engineering/fields/<field>/stack-defaults.md` — promoting a default is `capture`'s job; a refresh
  reports that an authority moved, it does not silently rewrite your defaults.
- Any **vendored** pack data — any directory carrying a `SOURCE.md` (e.g.
  `engineering/fields/frontend/ui-ux-pro-max/`). It is owned by its upstream; edits are lost on re-vendor.
- `engineering/fields/_template/**` — scaffolding; changing it is a deliberate decision, not a side effect.
- Any **other** field's pack — a refresh is scoped to one field.
- Any other skill's or agent's body (`skills/*/SKILL.md`, `agents/*.md`) — rewriting a workflow is an
  authoring change, done deliberately (see `authoring.md`), not smuggled in under a refresh.
- A user's install (`~/.mastermind/**`) — refresh edits the repo; installs get it on `git pull`.

**The check, before reporting done:** list what actually changed —

```
git status --porcelain && git diff --name-only
```

— and compare every path against the table above. A path that isn't on the "may write" list is a
violation: revert it, or stop and say so. Then regenerate and verify:

```
node scripts/build-router.mjs && node scripts/build-library.mjs && node scripts/check-integrity.mjs
```

Report the changed-file list in your summary. That list *is* the evidence the rule held — a refresh that
can't show it hasn't been verified.
