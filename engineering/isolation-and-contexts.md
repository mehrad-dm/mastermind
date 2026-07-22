# Per-project isolation & field/context routing — how it works

Shipped in v0.26.0. This is the reference for how a project owns its brain and how a monorepo
routes a different field to each app. It documents what the installer actually does, so the next
change doesn't have to re-derive it.

## Two layouts, one mechanism

**Shared** (`--shared`): the project symlinks `~/.mastermind`. One field, one `lessons.md`, one
`stack-defaults` for every project on the machine. `git pull` updates them all at once.

**Isolated** (the default): the installer **copies** the engine into `<project>/.mastermind/` and
commits it. The project owns its field, lessons and stack, and updates only when you re-run
`install.sh` there. A teammate cloning the repo gets the same brain.

`$BRAIN` in `install.sh` is whichever is active — the shared clone or the project copy. `$REPO` is
always the source to copy *from*. The wiring reads `$BRAIN`; the sync reads `$REPO`.

## What's copied, what's preserved (isolated)

`sync_isolated_brain()`:
- **Engine — refreshed every run:** `CLAUDE.md`, `AGENTS.md`, `engineering/core`,
  `engineering/ROUTER.md`, `skills`, `agents`, `hooks`.
- **Field packs — refreshed, except the project's own knowledge:** every file under
  `engineering/fields/*/`, but `lessons.md` and `stack-defaults.md` are seeded once and then never
  overwritten. That's where a project's learning accumulates.
- **Owned singletons — seeded once:** `engineering/active-field.md`.

Deletion reconciliation uses a **manifest** (`.mastermind/.manifest`): it records every path we
shipped. On update, a file that was in the old manifest and is gone from the new one (upstream
retired it) is removed; a file the project added was never in a manifest, so it is invisible to the
reconcile and survives. `lessons.md` / `stack-defaults.md` / `active-field.md` are excluded outright.

Hard safety: the sync **refuses to write through a symlinked `.mastermind`** (every `rm -rf` would
resolve through it), and a symlinked `.mastermind` never auto-enables isolated mode.

## The project root is the git root

`find_project_root()` walks up from `$PWD`: an existing `.mastermind` wins, else the git top-level,
else `$PWD`. So a monorepo gets **one** brain at the repo root no matter which subfolder you run from —
never a second brain in `apps/web/`. All project artifacts hang off `$PROJECT`, not `$PWD`.

## Field vs context

- **Field** = stack knowledge (frontend, backend…). Held **once**, shared by every app on that stack:
  defaults, mentors, audit rules, the design DB. Two React apps don't get *different* a11y rules.
- **Context** = one app/package's overlay: which field it uses (`field.md`) + its own `lessons.md`.
  This is where two React apps diverge. Contexts live in `engineering/contexts/<name>/` inside the
  project's brain, seeded from `engineering/_context_template/`.

A lesson stays in its context; when it's true for the whole stack, promote it up into the field's
`stack-defaults.md` (via `levelup`), where every app benefits.

## Routing — `routes.map` → tool-enforced anchors

`routes.map` in the project's brain, one rule per line: `<path-glob>  <context>`. It is **build-time
input only — the AI never reads it.** `generate_context_anchors()` compiles each rule into that app
directory's native, tool-enforced file:

- **Claude Code / Codex:** a nested `CLAUDE.md` / `AGENTS.md` holding `@`-imports of the kernel + the
  context's field + the context's own files. Claude Code loads nested memory by path automatically.
- **Cursor:** a small `.cursor/rules/mastermind.mdc` with `globs: <the app glob>` — Cursor's docs call
  glob-scoped rules *"deterministically attached."* Deliberately small (a pointer, not the full
  kernel) so it doesn't feed Cursor's known monorepo over-load bug; the repo-root rule carries the
  kernel.

The anchor directory is the glob with its trailing `/**` or `/*` stripped. `mm_rel_prefix` computes
the `../..` depth so the `@`-imports resolve from the app dir. Anchors are written with
`mm_write_block` between `MASTERMIND:START/END` markers — **clobber-safe**: a project's own
`CLAUDE.md` content outside the markers is preserved, and re-running replaces only our block.

**Why this is reliable across every model:** selection is a pure function of the file path, computed
by the tool before the model sees anything — the same pattern ESLint/EditorConfig/Cursor/Copilot all
converged on. The model never chooses which context applies; it only consumes what the tool attached.
What still varies between models is how faithfully each *follows* the (correctly-selected) context —
that's the models themselves, and no layer erases it.

## Uninstall & check

- `remove_context_anchors()` + `mm_strip_block()` strip our block from every anchor, keeping the
  project's own content; delete the file only if nothing of theirs remains; remove the Cursor rule.
  `.mastermind/` itself stays — it's the project's committed knowledge.
- `check_routes()` (in `--check`, isolated only) verifies every context exists, names a field that
  ships, and has its anchor present. A bad map is an issue, because it means an app would silently
  load the wrong knowledge.

## Known limits (honest)

- Only the `frontend` field ships today, so per-app routing gives you **context** isolation now
  (web vs api lessons); **field**-switching (frontend vs backend) needs a second pack authored.
- Cursor's own monorepo rule over-loading and Cline's multi-root nesting gap are documented **tool**
  bugs we can't fix; the small-rule design mitigates the first.
- Plain chat (no rules files) has no path mechanism — there, routing degrades to the model reading
  instructions. Every tool with a path mechanism gets deterministic selection.
- Lesson **promotion** (context → field) is a `levelup`/manual step, not automated.
