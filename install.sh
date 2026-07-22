#!/usr/bin/env bash
# MasterMind installer — safe, idempotent, self-healing.
#
# Two scopes:
#   (default) PER-PROJECT — wires MasterMind into the CURRENT project, for every AI
#             tool you have (Claude Code, Codex, Cursor, Gemini, Copilot). Active only
#             here. Run it in each project you want it in.
#   --global              — wires ~/.claude / ~/.codex, so Claude Code + Codex get it
#             in EVERY project. (Cursor/Copilot/Gemini config is per-project by design.)
#
# You install FROM the clone at ~/.mastermind. Re-run anytime — ESPECIALLY after `git pull`
# — to refresh. It NEVER destroys your data: a real CLAUDE.md is backed up, an existing
# AGENTS.md / GEMINI.md / copilot file is appended to (never overwritten), and a project's
# own lessons are kept across updates.
#
# Usage:
#   cd my-project && ~/.mastermind/install.sh          # this project, all your tools (isolated)
#   cd my-project && ~/.mastermind/install.sh --shared # opt into the one shared clone instead
#   ~/.mastermind/install.sh --global                  # Claude+Codex in every project (shared)
#   ~/.mastermind/install.sh --check                   # doctor (add --global to check global)
#   ~/.mastermind/install.sh --uninstall               # remove from this project (or --global)
#   cd my-project && ~/.mastermind/install.sh cursor   # only the named tool(s)
#
# Isolated (default) vs --shared:
#   Isolated  — the engine is COPIED into <project>/.mastermind/, committed to that repo, and
#               the project owns its field, lessons and stack. Nothing another project learns
#               can change it; it updates only when you re-run install here. A monorepo can
#               route a different field/context per app via `.mastermind/routes.map`.
#   Shared    — every project symlinks back to ~/.mastermind: ONE field, ONE lessons.md, ONE
#               stack-defaults for all of them, updated together by `git pull`. Right when your
#               projects genuinely share a stack.
set -euo pipefail

# `pwd -P` — resolve symlinks to the REAL repo path. Plain `pwd` returns the logical path,
# so running the documented `~/.mastermind/install.sh` gave REPO=~/.mastermind, and the
# `ln -sfn "$REPO" "$HOME/.mastermind"` below then pointed that symlink at ITSELF — an
# unreadable loop that silently unlinks the whole brain ("Too many levels of symbolic links",
# every glob stops matching, and skills link as a literal `*`). The documented update command
# was the one that broke it.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MODE=install; SCOPE=project; TOOLS=(); ISOLATED=0; SHARED=0
for a in "$@"; do
  case "$a" in
    --check)     MODE=check ;;
    --uninstall) MODE=uninstall ;;
    --global)    SCOPE=global ;;
    --isolated)  ISOLATED=1 ;;   # (now the default; kept so existing commands still work)
    --shared)    SHARED=1 ;;
    --*)         printf 'unknown flag: %s\n' "$a" >&2; exit 2 ;;
    *)           TOOLS+=("$a") ;;
  esac
done

g=$'\033[0;32m'; y=$'\033[0;33m'; r=$'\033[0;31m'; x=$'\033[0m'

[ "$ISOLATED" = 1 ] && [ "$SCOPE" = global ] && {
  printf '%s✖ --isolated is per-project by definition; drop --global.%s\n' "$r" "$x" >&2; exit 2
}
ok()   { printf '  %s✓%s %s\n' "$g" "$x" "$*"; }
warn() { printf '  %s⚠%s %s\n' "$y" "$x" "$*"; }
bad()  { printf '  %s✖%s %s\n' "$r" "$x" "$*"; }
ISSUES=0; LINKED_SKILLS=0; LINKED_AGENTS=0; PRUNED=0; RENAMED=0; SKIPPED=0
HINT='Follow ~/.mastermind/CLAUDE.md — the MasterMind brain (skills, agents, engineering rigor).'
# Anchor-block markers — matched as WHOLE lines so a project's own text that merely mentions
# them is never edited. Kept minimal and stable so old blocks stay recognizable across versions.
MM_START='<!-- MASTERMIND:START -->'
MM_END='<!-- MASTERMIND:END -->'

# One brain per repository, so a monorepo doesn't sprout a separate brain per subfolder.
# Walk up for an existing project brain, else the git root, else stay put (non-git dir).
# Two guards: STOP at $HOME (the shared clone is $HOME/.mastermind — ascending into it would
# make a project resolve its root to $HOME, no-op'ing install and deleting global wiring on
# uninstall), and require a REAL dir (the shared clone is a symlink; a project brain isn't).
find_project_root() {
  local d="$PWD"
  while [ "$d" != / ] && [ "$d" != "$HOME" ]; do
    [ -d "$d/.mastermind" ] && [ ! -L "$d/.mastermind" ] && { printf '%s' "$d"; return; }
    d="$(dirname "$d")"
  done
  git rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PWD"
}

if [ "$SCOPE" = global ]; then
  PROJECT="$HOME"
else
  PROJECT="$(find_project_root)"
fi

# Scope → where Claude/Codex get wired (project-local by default, home with --global).
if [ "$SCOPE" = global ]; then
  CLAUDE_DIR="$HOME/.claude"; CODEX_AGENTS="$HOME/.codex/AGENTS.md"
else
  CLAUDE_DIR="$PROJECT/.claude";  CODEX_AGENTS="$PROJECT/AGENTS.md"
fi

# Which brain does this project actually read? The shared clone, or its own copy.
# Resolved HERE, before anything that inspects links: `is_ours` and the uninstall block
# both need it, and both run earlier than the install path does.
# A project that already has .mastermind/VERSION stays isolated on later runs even
# without the flag — otherwise a plain `install.sh` would silently re-point it at the clone.
# Per-project installs are ISOLATED by default: the project gets its own field, lessons and
# stack, and updates only when you re-run install there. `--shared` opts back into the single
# clone every project reads — right when your projects genuinely share a stack.
if [ "$SCOPE" = project ] && [ "$SHARED" = 0 ] && [ "$MODE" != uninstall ]; then ISOLATED=1; fi
if [ "$SCOPE" = project ] && { [ "$ISOLATED" = 1 ] || { [ -f "$PROJECT/.mastermind/VERSION" ] && [ ! -L "$PROJECT/.mastermind" ]; }; }; then
  BRAIN="$PROJECT/.mastermind"; ISOLATED=1
else
  BRAIN="$REPO"
fi

# Link src→dst. In check mode, only verify. Back up a real file before linking.
safe_link() {
  local src="$1" dst="$2"
  if [ "$MODE" = check ]; then
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ] && [ -e "$dst" ]; then ok "$(basename "$dst")"
    else bad "$(basename "$dst") is not linked to MasterMind"; ISSUES=$((ISSUES + 1)); fi
    return
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local bak="$dst.bak-$(date +%Y%m%d%H%M%S)"
    mv "$dst" "$bak"; warn "backed up your existing $(basename "$dst") → $bak"
  fi
  ln -sfn "$src" "$dst"
}

is_ours() {
  [ -L "$1" ] || return 1
  local t; t="$(readlink "$1")"
  case "$t" in "$REPO"*|"$BRAIN"*) return 0 ;; *) return 1 ;; esac
}
path_exists() { [ -e "$1" ] || [ -L "$1" ]; }

# Link a skill/agent so BOTH the project's and MasterMind's survive.
#
# The kernel's rule is "the project wins" — but winning must never mean MasterMind
# loses a capability. So on a name collision we leave the project's file exactly where
# it is and install ours ALONGSIDE it as `mastermind-<name>`. Nothing is displaced,
# nothing silently disappears, and the names say which is which.
link_skill() {
  local src="$1" base="$2" name="$3" kind="$4"
  local dst="$base/$name" alt="$base/mastermind-$name"
  local target="$dst" renamed=0   # separate `local`: same-statement $dst isn't set yet

  if path_exists "$dst" && ! is_ours "$dst"; then target="$alt"; renamed=1; fi

  if [ "$MODE" = check ]; then
    if is_ours "$target" && [ -e "$target" ]; then
      if [ "$renamed" = 1 ]; then ok "mastermind-$name (your own '$name' kept)"; else ok "$name"; fi
      return 0
    fi
    bad "$(basename "$target") is not linked to MasterMind"; ISSUES=$((ISSUES + 1)); return 1
  fi

  # The project owns BOTH names — refuse rather than clobber anything of theirs.
  if [ "$renamed" = 1 ] && path_exists "$alt" && ! is_ours "$alt"; then
    warn "you own both '$name' and 'mastermind-$name' — MasterMind's $kind skipped"
    SKIPPED=$((SKIPPED + 1)); return 1
  fi

  ln -sfn "$src" "$target"
  if [ "$renamed" = 1 ]; then
    warn "you already have a $kind '$name' — installed MasterMind's as 'mastermind-$name' (both work)"
    RENAMED=$((RENAMED + 1))
  elif is_ours "$alt"; then
    # Their colliding file is gone, so ours reclaimed the real name — drop the alias.
    rm -f "$alt"
  fi
  return 0
}

# Wire an instruction file (AGENTS.md / GEMINI.md / copilot-instructions.md) to the
# brain WITHOUT clobbering: if absent, symlink to the full brain; if the project
# already has one, append a one-line pointer (idempotent).
wire_brain_file() {
  local dst="$1" src="$2"
  if [ "$MODE" = check ]; then
    if { [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; } || { [ -f "$dst" ] && grep -q 'mastermind/CLAUDE.md' "$dst"; }; then ok "$(basename "$dst")"
    else bad "$(basename "$dst") not wired to MasterMind"; ISSUES=$((ISSUES + 1)); fi
    return
  fi
  mkdir -p "$(dirname "$dst")"
  if [ ! -e "$dst" ] || [ -L "$dst" ]; then ln -sfn "$src" "$dst"; ok "$(basename "$dst") linked"
  elif grep -q 'mastermind/CLAUDE.md' "$dst"; then ok "$(basename "$dst") already wired"
  else printf '\n%s\n' "$HINT" >> "$dst"; ok "appended MasterMind pointer to your $(basename "$dst")"
  fi
}

# Cursor rule (its own file, always ours) — needs alwaysApply frontmatter to load.
wire_cursor() {
  local dst="$PROJECT/.cursor/rules/mastermind.mdc"
  if [ "$MODE" = check ]; then
    # Grep for kernel CONTENT: a pointer-only rule ("Follow ~/.mastermind/CLAUDE.md") is the
    # stale shape and must read as unwired, not healthy.
    if [ -f "$dst" ] && grep -q 'Prime directives' "$dst"; then ok ".cursor/rules/mastermind.mdc"
    elif [ -f "$dst" ]; then bad ".cursor rule is the old pointer-only shape — re-run install.sh"; ISSUES=$((ISSUES + 1))
    else bad ".cursor rule not set"; ISSUES=$((ISSUES + 1)); fi
    return
  fi
  mkdir -p "$PROJECT/.cursor/rules"
  # Other tools get the kernel by symlink; Cursor can't — an .mdc needs YAML frontmatter. So
  # compose frontmatter + the real kernel inline. A pointer to the file (instead of its content)
  # leaves loading to the model's discretion, which is why it often didn't. Generated, not
  # linked: re-run install.sh after a `git pull` to refresh it.
  { printf -- '---\nalwaysApply: true\n---\n'
    printf -- '<!-- Generated by ~/.mastermind/install.sh — do not edit. Re-run install.sh to refresh. -->\n\n'
    cat "$BRAIN/CLAUDE.md"
  } > "$dst"
  ok ".cursor/rules/mastermind.mdc — full kernel inlined"
  wire_cursor_hook
}

# Copilot CLI reads every .github/hooks/*.json, so we ship our OWN file — no merging into
# anyone's config and no clobber risk. Its sessionStart hook injects stdout's
# `additionalContext` as a prepended user message (the `sdk` shape).
#
# Copilot exposes no compaction event, so this is startup-only: the brain reloads per
# session but may still fade inside a long one. Reported as such by --check.
wire_copilot_hook() {
  local dst="$PROJECT/.github/hooks/mastermind.json"
  if [ "$MODE" = check ]; then
    if [ -f "$dst" ]; then ok ".github/hooks/mastermind.json (startup only)"; fi
    return 0
  fi
  mkdir -p "$PROJECT/.github/hooks"
  printf '{\n  "version": 1,\n  "hooks": {\n    "sessionStart": [\n      {\n        "type": "command",\n        "bash": "%s/hooks/session-start.sh sdk"\n      }\n    ]\n  }\n}\n' "$BRAIN" > "$dst"
  ok ".github/hooks/mastermind.json — reloads each session (no compaction event in Copilot)"
  return 0
}

# Cursor's own hook system (.cursor/hooks.json). sessionStart re-loads the kernel on a new
# conversation; preCompact fires before Cursor compacts, which is the event that matters.
#
# UNVERIFIED — see docs: Cursor has open bug reports where a sessionStart hook's
# additional_context is accepted but never reaches the model. We wire it because it costs
# nothing and starts working the moment that's fixed, but the .mdc rule above remains the
# load-bearing path for Cursor. Do not claim Cursor re-injection works until it's observed.
wire_cursor_hook() {
  local dst="$PROJECT/.cursor/hooks.json"
  if [ "$MODE" = check ]; then
    if [ -f "$dst" ] && grep -q 'session-start.sh' "$dst"; then ok ".cursor/hooks.json (unverified upstream)"; fi
    return 0
  fi
  command -v node >/dev/null 2>&1 || return 0
  mkdir -p "$PROJECT/.cursor"
  MM_DST="$dst" MM_CMD="$BRAIN/hooks/session-start.sh cursor" node -e '
    const fs=require("fs"); const p=process.env.MM_DST, cmd=process.env.MM_CMD;
    let s={version:1,hooks:{}};
    if (fs.existsSync(p)) { try { s=JSON.parse(fs.readFileSync(p,"utf8")||"{}"); } catch { process.exit(3); } }
    s.version ??= 1; s.hooks ||= {};
    for (const ev of ["sessionStart","preCompact"]) {
      const keep=(s.hooks[ev]||[]).filter(e=>!JSON.stringify(e).includes("session-start.sh"));
      keep.push({command: cmd});
      s.hooks[ev]=keep;
    }
    fs.writeFileSync(p, JSON.stringify(s,null,2)+"\n");
  ' 2>/dev/null \
    && ok ".cursor/hooks.json — sessionStart + preCompact (unverified upstream)" \
    || warn "left your .cursor/hooks.json alone (could not parse it)"
  return 0
}

# Wire Claude Code natively (skills + agents + kernel) into a base .claude dir.
wire_claude() {
  local base="$1"
  [ "$MODE" = check ] || mkdir -p "$base/agents" "$base/skills"
  printf '\nClaude Code:\n'
  safe_link "$BRAIN/CLAUDE.md" "$base/CLAUDE.md"
  # Global links engineering into ~/.claude; per-project reads it via ~/.mastermind.
  [ "$SCOPE" = global ] && safe_link "$REPO/engineering" "$base/engineering"
  prune_dead_links "$base/skills"; prune_dead_links "$base/agents"
  LINKED_SKILLS=0; LINKED_AGENTS=0; RENAMED=0; SKIPPED=0
  local a s
  for a in "$BRAIN"/agents/*.md; do
    if link_skill "$a" "$base/agents" "$(basename "$a")" agent; then
      [ "$MODE" = check ] || LINKED_AGENTS=$((LINKED_AGENTS + 1))
    fi
  done
  for s in "$BRAIN"/skills/*/; do
    if link_skill "${s%/}" "$base/skills" "$(basename "$s")" skill; then
      [ "$MODE" = check ] || LINKED_SKILLS=$((LINKED_SKILLS + 1))
    fi
  done
  if [ "$MODE" != check ]; then
    ok "$LINKED_SKILLS skills, $LINKED_AGENTS agents linked · $PRUNED stale removed"
    if [ "$RENAMED" -gt 0 ]; then
      warn "$RENAMED name(s) clashed with your own — yours kept, ours added as mastermind-*"
    fi
  fi
  wire_bootstrap "$base"
}

# Register the SessionStart bootstrap so the kernel is re-injected on startup AND after
# a compaction — otherwise the brain quietly fades out of a long session. Merges into an
# existing settings.json (never overwrites it) and is idempotent.
wire_bootstrap() {
  local base="$1" settings="$base/settings.json" hook="$BRAIN/hooks/session-start.sh"

  if [ "$MODE" = check ]; then
    if [ -f "$settings" ] && grep -q 'session-start.sh' "$settings"; then ok "bootstrap hook"
    else bad "bootstrap hook not registered (kernel will fade after a compaction)"; ISSUES=$((ISSUES + 1)); fi
    return 0
  fi

  if ! command -v node >/dev/null 2>&1; then
    warn "node not found — skipped the bootstrap hook (brain won't survive a compaction)"
    return 0
  fi

  MM_SETTINGS="$settings" MM_HOOK="$hook" node -e '
    const fs = require("fs");
    const p = process.env.MM_SETTINGS, cmd = JSON.stringify(process.env.MM_HOOK);
    let s = {};
    if (fs.existsSync(p)) {
      try { s = JSON.parse(fs.readFileSync(p, "utf8") || "{}"); }
      catch { console.error("KEEP"); process.exit(3); }   // unparseable: never clobber it
    }
    s.hooks ||= {};
    const list = (s.hooks.SessionStart ||= []);
    // Drop any previous MasterMind entry, then re-add — keeps other tools hooks intact.
    const clean = list.filter(e => !JSON.stringify(e).includes("session-start.sh"));
    clean.push({
      matcher: "startup|clear|compact",
      hooks: [{ type: "command", command: cmd, async: false }],
    });
    s.hooks.SessionStart = clean;
    fs.writeFileSync(p, JSON.stringify(s, null, 2) + "\n");
  ' 2>/dev/null \
    && ok "bootstrap hook — kernel re-injected on startup + compaction" \
    || warn "left your settings.json alone (could not parse it) — bootstrap hook not registered"
  return 0
}

# Remove every dangling symlink in a dir (target gone — e.g. a renamed skill).
prune_dead_links() {
  local dir="$1"; [ -d "$dir" ] || return 0
  shopt -s nullglob
  local l
  for l in "$dir"/*; do
    if [ -L "$l" ] && [ ! -e "$l" ]; then
      if [ "$MODE" = check ]; then bad "stale link $(basename "$l") → $(readlink "$l")"; ISSUES=$((ISSUES + 1))
      else rm -f "$l"; PRUNED=$((PRUNED + 1)); fi
    fi
  done
  shopt -u nullglob
}

# Remove a path only if it's a MasterMind symlink into this repo (never user files).
remove_link() {
  local f="$1"
  if is_ours "$f"; then rm -f "$f"; ok "removed $(basename "$f")"; return 0; fi
  return 1
}

# Tell the user if their clone is behind origin. Network-optional: any failure is silent.
check_updates() {
  command -v git >/dev/null 2>&1 || return 0
  git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git -C "$REPO" fetch --quiet 2>/dev/null || return 0
  local here up base
  here="$(git -C "$REPO" rev-parse @ 2>/dev/null)"        || return 0
  up="$(git -C "$REPO" rev-parse '@{u}' 2>/dev/null)"     || return 0
  base="$(git -C "$REPO" merge-base @ '@{u}' 2>/dev/null)" || return 0
  if [ "$here" != "$up" ] && [ "$here" = "$base" ]; then
    printf '%s⬆ An update is available.%s  cd ~/.mastermind && git pull && ~/.mastermind/install.sh\n' "$y" "$x"
  fi
}

# Strip our generated MASTERMIND block from a nested anchor, keeping the project's own
# content. Deletes the file only if nothing of theirs remains. Reverse of mm_write_block.
mm_strip_block() {
  local file="$1" tmp
  [ -f "$file" ] || return 0
  grep -qxF "$MM_START" "$file" || return 1     # exact full line, not a substring mention
  tmp="$(mktemp)"
  # Match START/END only as WHOLE lines (`$0==m`), so a user line that merely *mentions* the
  # marker text is never touched. Buffer the block body; on a matching END, drop it (our
  # block); at EOF still inside a block (a lone START, no END — a half-edited file), FLUSH the
  # buffer so nothing of theirs is lost. Deleting-to-EOF on an unbalanced marker was the bug.
  awk -v S="$MM_START" -v E="$MM_END" '
    $0==S { inb=1; buf=""; next }
    inb && $0==E { inb=0; next }
    inb { buf = buf $0 "\n"; next }
    { print }
    END { if (inb) printf "%s", buf }
  ' "$file" > "$tmp"
  if [ -s "$tmp" ] && grep -q '[^[:space:]]' "$tmp"; then mv "$tmp" "$file"
  else rm -f "$tmp" "$file"; fi
  return 0
}

# Remove every per-app anchor this project generated, reading the same routes.map that
# created them. Leaves the project's own CLAUDE.md/AGENTS.md content intact.
remove_context_anchors() {
  local map="$BRAIN/routes.map"
  [ -f "$map" ] || return 0
  local glob line adir abs
  while IFS= read -r line; do
    line="${line//$'\r'/}"; line="${line%%#*}"; line="$(printf '%s' "$line" | awk '{$1=$1};1')"
    [ -n "$line" ] || continue
    glob="${line%% *}"
    adir="${glob%/\*\*}"; adir="${adir%/\*}"; adir="${adir%/}"
    case "$adir" in ''|'*'|'.'|'**') continue ;; esac
    abs="$PROJECT/$adir"
    mm_strip_block "$abs/CLAUDE.md" && n=$((n + 1)) || true
    mm_strip_block "$abs/AGENTS.md" || true
    [ -f "$abs/.cursor/rules/mastermind.mdc" ] && { rm -f "$abs/.cursor/rules/mastermind.mdc"; n=$((n + 1)); }
  done < "$map"
}

# --- Uninstall (scoped): remove MasterMind links, leave your own files -------
if [ "$MODE" = uninstall ]; then
  printf 'Removing MasterMind from %s%s%s…\n' "$g" "$([ "$SCOPE" = global ] && echo "global (~/.claude, ~/.codex)" || echo "this project")" "$x"
  n=0
  remove_link "$CLAUDE_DIR/CLAUDE.md"   && n=$((n + 1))
  remove_link "$CLAUDE_DIR/engineering" && n=$((n + 1))
  shopt -s nullglob
  for l in "$CLAUDE_DIR"/skills/* "$CLAUDE_DIR"/agents/*; do remove_link "$l" && n=$((n + 1)); done
  shopt -u nullglob
  remove_link "$CODEX_AGENTS"                          && n=$((n + 1))
  # Project-scoped artifacts: only ever touch these when uninstalling THIS project.
  # They live under $PROJECT, so removing them during a --global uninstall would silently
  # de-wire whatever directory the user happened to run the command from.
  if [ "$SCOPE" = project ]; then
    remove_context_anchors    # keeps each app's own CLAUDE.md content
    remove_link "$PROJECT/GEMINI.md"                       && n=$((n + 1))
    remove_link "$PROJECT/.github/copilot-instructions.md" && n=$((n + 1))
    if [ -f "$PROJECT/.cursor/rules/mastermind.mdc" ]; then rm -f "$PROJECT/.cursor/rules/mastermind.mdc"; ok "removed .cursor/rules/mastermind.mdc"; n=$((n + 1)); fi
    # Copilot's hook file is wholly ours — no merge, so no filtering needed.
    if [ -f "$PROJECT/.github/hooks/mastermind.json" ]; then rm -f "$PROJECT/.github/hooks/mastermind.json"; ok "removed .github/hooks/mastermind.json"; n=$((n + 1)); fi
    # Cursor's hooks.json is shared: filter our entries out rather than deleting the file.
    if [ -f "$PROJECT/.cursor/hooks.json" ] && command -v node >/dev/null 2>&1; then
      MM_DST="$PROJECT/.cursor/hooks.json" node -e '
        const fs=require("fs"); const p=process.env.MM_DST;
        let s; try { s=JSON.parse(fs.readFileSync(p,"utf8")||"{}"); } catch { process.exit(3); }
        let hit=false;
        for (const ev of Object.keys(s.hooks||{})) {
          const keep=(s.hooks[ev]||[]).filter(e=>!JSON.stringify(e).includes("session-start.sh"));
          if (keep.length !== (s.hooks[ev]||[]).length) hit=true;
          if (keep.length) s.hooks[ev]=keep; else delete s.hooks[ev];
        }
        if (!hit) process.exit(1);
        fs.writeFileSync(p, JSON.stringify(s,null,2)+"\n");
      ' 2>/dev/null && { ok "unwired .cursor/hooks.json"; n=$((n + 1)); }
    fi
  fi
  # The bootstrap hook is merged into a settings.json we do not own — filter our entry
  # out and leave everything else exactly as it was. Without this, uninstalling and then
  # deleting the clone leaves every session firing a hook that points at a missing script.
  if [ -f "$CLAUDE_DIR/settings.json" ] && command -v node >/dev/null 2>&1; then
    MM_SETTINGS="$CLAUDE_DIR/settings.json" node -e '
      const fs=require("fs"); const p=process.env.MM_SETTINGS;
      let s; try { s=JSON.parse(fs.readFileSync(p,"utf8")||"{}"); } catch { process.exit(3); }
      const list=(s.hooks||{}).SessionStart||[];
      const keep=list.filter(e=>!JSON.stringify(e).includes("session-start.sh"));
      if (keep.length === list.length) process.exit(1);
      if (keep.length) s.hooks.SessionStart=keep; else delete s.hooks.SessionStart;
      if (s.hooks && !Object.keys(s.hooks).length) delete s.hooks;
      fs.writeFileSync(p, JSON.stringify(s,null,2)+"\n");
    ' 2>/dev/null && { ok "unwired the bootstrap hook from settings.json"; n=$((n + 1)); }
  fi
  for f in "$CODEX_AGENTS" "$PROJECT/GEMINI.md" "$PROJECT/.github/copilot-instructions.md"; do
    [ -f "$f" ] && grep -q 'mastermind/CLAUDE.md' "$f" && warn "left your $(basename "$f") in place — it still has a MasterMind pointer line you can remove by hand"
  done
  printf '\n%s✓ removed %d link(s).%s Your own files were left untouched. (~/.mastermind stays; delete the clone to remove the brain.)\n' "$g" "$n" "$x"
  exit 0
fi

# --- Brain source (always) ---------------------------------------------------
# Never point ~/.mastermind at itself — that loop makes the brain unreadable and every
# glob below silently stops matching. REPO is resolved with `pwd -P` above so this should
# be unreachable; it stays as a hard stop because the failure mode is catastrophic and
# completely silent (the installer still prints ✓ while linking a literal `*`).
if [ "$MODE" != check ]; then
  if [ "$REPO" = "$HOME/.mastermind" ]; then
    printf '%s✖ refusing to link ~/.mastermind to itself.%s Run install.sh from the real clone path.\n' "$r" "$x" >&2
    exit 1
  fi
  ln -sfn "$REPO" "$HOME/.mastermind"
fi

# --- Per-project sanity: need a real project dir, not the clone or ~ ----------
if [ "$SCOPE" = project ] && [ "$MODE" = install ] && { [ "$PROJECT" -ef "$REPO" ] || [ "$PROJECT" -ef "$HOME" ]; }; then
  printf 'MasterMind brain → ~/.mastermind  %s✓ ready%s\n\n' "$g" "$x"
  printf 'Now add it to a project:\n'
  printf '  cd your-project && ~/.mastermind/install.sh      (just that project — recommended)\n'
  printf '  ~/.mastermind/install.sh --global                (Claude + Codex, every project)\n'
  exit 0
fi

# --- Isolated mode: give this project its own brain --------------------------
# Copies the engine into <project>/.mastermind/ (committed) so the project owns its field,
# lessons and stack instead of sharing one clone. Paths are rewritten project-relative, never
# absolute, so a teammate who pulls the repo gets working paths, not this machine's home.
#
# ISO_ENGINE dirs are overwritten every run — that's how updates land. What survives: a pack's
# lessons.md / stack-defaults.md and ISO_OWNED (a project's own knowledge). A file dropped into
# an engine dir like core/ or skills/ is NOT kept — a project's own skills belong in .claude/.
ISO_ENGINE=(CLAUDE.md AGENTS.md engineering/ROUTER.md engineering/core skills agents hooks)
ISO_OWNED=(engineering/active-field.md)

sync_isolated_brain() {
  local dst="$PROJECT/.mastermind" d
  local SHIPPED; SHIPPED="$(mktemp)"
  # NEVER write through a symlink. Every rm -rf below would resolve through it and delete
  # someone else's directory — including the shared clone, which would break every other
  # project. Refuse loudly instead.
  if [ -L "$dst" ]; then
    printf '%s✖ .mastermind is a symlink (→ %s).%s Refusing to write through it — remove it first.\n' \
      "$r" "$(readlink "$dst")" "$x" >&2; exit 1
  fi
  if path_exists "$dst" && [ ! -d "$dst" ]; then
    printf '%s✖ .mastermind exists and is not a directory.%s Move it aside first.\n' "$r" "$x" >&2; exit 1
  fi
  mkdir -p "$dst"

  # Engine: always refreshed.
  for d in "${ISO_ENGINE[@]}"; do
    if [ -e "$REPO/$d" ]; then
      rm -rf "$dst/${d:?}"
      mkdir -p "$(dirname "$dst/$d")"
      cp -R "$REPO/$d" "$dst/$d"
      if [ -d "$dst/$d" ]; then ( cd "$dst" && find "$d" -type f ) >> "$SHIPPED"
      else printf '%s\n' "$d" >> "$SHIPPED"; fi
    fi
  done

  # Field packs: refresh each file, but never clobber lessons.md / stack-defaults.md — that's
  # where a project's own knowledge lives. Walk RECURSIVELY (find, so dotfiles too) and apply
  # the keep-test per file, so an owned file inside a pack subdir (ui-ux-pro-max/) survives too.
  local pack
  for pack in "$REPO"/engineering/fields/*/; do
    [ -d "$pack" ] || continue
    local name; name="$(basename "$pack")"
    local pdst="$dst/engineering/fields/$name"
    mkdir -p "$pdst"
    local f rel
    while IFS= read -r f; do
      rel="${f#"$pack"}"
      case "$(basename "$rel")" in
        lessons.md|stack-defaults.md)
          [ -e "$pdst/$rel" ] && { printf '%s\n' "engineering/fields/$name/$rel" >> "$SHIPPED"; continue; } ;;
      esac
      mkdir -p "$(dirname "$pdst/$rel")"
      cp "$f" "$pdst/$rel"
      printf '%s\n' "engineering/fields/$name/$rel" >> "$SHIPPED"
    done < <(find "$pack" -type f)
  done

  # Project-owned singletons: seed once, then leave alone.
  for d in "${ISO_OWNED[@]}"; do
    [ -e "$dst/$d" ] || { mkdir -p "$(dirname "$dst/$d")"; cp -R "$REPO/$d" "$dst/$d"; }
  done

  # Point the copied docs at THIS project's brain instead of the shared clone.
  # Portable and git-safe: `.mastermind/...` resolves from the project root on any machine.
  local file
  # -I skips binaries (GNU grep -rl lists them; piping those to perl -pi corrupts them)
  # and --include limits the rewrite to prose, never to vendored data or scripts.
  while IFS= read -r file; do
    perl -pi -e 's|~/\.mastermind|.mastermind|g' "$file"
  done < <(grep -rlI --include='*.md' '~/\.mastermind' "$dst" 2>/dev/null || true)

  # --- reconcile deletions, using the manifest of what WE installed -------------
  # Only paths that are BOTH in the previous manifest (we put them there) and absent from
  # the new one (upstream retired them) are removed. A file the project added was never in
  # a manifest, so it is invisible to this and survives untouched. OWNED files are excluded
  # outright — they belong to the project the moment they are seeded.
  local manifest="$dst/.manifest" newman; newman="$(mktemp)"
  sort -u "$SHIPPED" > "$newman"

  if [ -f "$manifest" ]; then
    local gone
    while IFS= read -r gone; do
      [ -n "$gone" ] || continue
      case "$(basename "$gone")" in lessons.md|stack-defaults.md|active-field.md|prefs.md) continue ;; esac
      # in the OLD manifest, still on disk, but no longer shipped → ours, and retired
      if [ -e "$dst/$gone" ] && ! grep -qxF "$gone" "$newman"; then
        rm -f "$dst/$gone"
      fi
    done < "$manifest"
    # prune directories the removals emptied, but never the root
    find "$dst" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  fi

  # The manifest records the state we just installed, minus the project's own files.
  cp "$newman" "$manifest"
  rm -f "$newman" "$SHIPPED"

  printf '%s\n' "$(cat "$REPO/VERSION")" > "$dst/VERSION"
}

# --- Field + context: per-app routing in a monorepo --------------------------
# `routes.map` maps `<path-glob> <context>` per line; the installer compiles each rule into
# that app dir's native anchor (nested CLAUDE.md / AGENTS.md + a glob-scoped Cursor rule). The
# AI never reads routes.map — the tool attaches the right context by file path, so selection is
# deterministic. No routes.map = single-field, and this block is a no-op.

# Relative prefix from an anchor dir back to the project root: "apps/web" → "../../".
mm_rel_prefix() {
  local dir="$1" pfx="" part
  IFS='/' read -ra part <<< "$dir"
  for _ in "${part[@]+"${part[@]}"}"; do pfx="../$pfx"; done
  printf '%s' "$pfx"
}

# Write a generated block into a file between MASTERMIND markers, preserving anything the
# project already has outside them. Idempotent: re-running replaces only our block. This is
# how we drop an anchor into an app dir that may already hold the project's own CLAUDE.md.
mm_write_block() {
  local file="$1" body="$2" tmp kept=""
  mkdir -p "$(dirname "$file")"
  tmp="$(mktemp)"
  if [ -f "$file" ]; then
    # Strip any prior block of OURS (whole-line marker match, buffer-flush on an unbalanced
    # one so a half-edited file never loses the project's content), keeping everything else.
    # Command substitution trims trailing newlines, so re-runs don't accumulate blank lines.
    kept="$(awk -v S="$MM_START" -v E="$MM_END" '
      $0==S { inb=1; buf=""; next }
      inb && $0==E { inb=0; next }
      inb { buf = buf $0 "\n"; next }
      { print }
      END { if (inb) printf "%s", buf }
    ' "$file")"
  fi
  # Kept content, then one blank line, then our block. A brand-new file has no kept content,
  # so it starts straight at the block — no leading blank.
  [ -n "$kept" ] && printf '%s\n\n' "$kept" >> "$tmp"
  {
    printf '%s\n' "$MM_START"
    printf '<!-- generated by install.sh — edit above or below, never inside -->\n'
    printf '%s\n' "$body"
    printf '%s\n' "$MM_END"
  } >> "$tmp"
  mv "$tmp" "$file"
}

# Compile routes.map → per-app anchors. Reads from the ACTIVE brain ($BRAIN).
generate_context_anchors() {
  local map="$BRAIN/routes.map"
  [ -f "$map" ] || return 0
  local default_field="frontend"
  [ -d "$BRAIN/engineering/fields/frontend" ] || default_field="$(basename "$(find "$BRAIN/engineering/fields" -maxdepth 1 -mindepth 1 -type d ! -name '_*' | head -1)")"

  local glob ctx line
  while IFS= read -r line; do
    line="${line//$'\r'/}"; line="${line%%#*}"; line="$(printf '%s' "$line" | awk '{$1=$1};1')"
    [ -n "$line" ] || continue
    # A rule must be exactly `<glob> <context>`, and the context a plain slug. A one-token
    # line (context omitted) or a name with `/` or another metachar would break the sed
    # templating below and, under set -e, abort the whole install — so reject it here.
    if [ "$(printf '%s' "$line" | wc -w | tr -d ' ')" != 2 ]; then
      warn "routes.map: '$line' is not '<glob> <context>' — skipped"; ISSUES=$((ISSUES + 1)); continue
    fi
    glob="${line%% *}"; ctx="${line##* }"
    case "$ctx" in *[!A-Za-z0-9_-]*)
      warn "routes.map: context '$ctx' has invalid characters (use letters, digits, - or _) — skipped"
      ISSUES=$((ISSUES + 1)); continue ;;
    esac

    # Anchor dir = the glob without its trailing /** or /*. A root/wildcard glob is handled by
    # the top-level wiring. Do this first: if the app dir isn't there, skip before creating a
    # context for it, so a stale route leaves no orphan contexts/ dir behind.
    local adir="${glob%/\*\*}"; adir="${adir%/\*}"; adir="${adir%/}"
    case "$adir" in ''|'*'|'.'|'**') continue ;; esac
    local abs="$PROJECT/$adir"
    if [ ! -d "$abs" ]; then warn "routes.map: '$glob' → no directory $adir/ — skipped"; continue; fi

    # Seed the context from the template on first use, then read the field it names.
    local cdir="$BRAIN/engineering/contexts/$ctx"
    if [ ! -d "$cdir" ]; then
      local tpl="$BRAIN/engineering/_context_template"; [ -d "$tpl" ] || tpl="$REPO/engineering/_context_template"
      mkdir -p "$cdir"
      sed "s/<field>/$default_field/g; s/<name>/$ctx/g" "$tpl/field.md" > "$cdir/field.md"
      sed "s/<name>/$ctx/g" "$tpl/lessons.md" > "$cdir/lessons.md"
    fi
    local field; field="$(sed -n 's/^field:[[:space:]]*//p' "$cdir/field.md" | head -1)"; field="${field:-$default_field}"
    if [ ! -d "$BRAIN/engineering/fields/$field" ]; then
      warn "context '$ctx' names field '$field', which isn't in this brain — skipped. Add the pack, or fix $cdir/field.md."
      ISSUES=$((ISSUES + 1)); continue
    fi

    local pfx; pfx="$(mm_rel_prefix "$adir")"
    local imports="@${pfx}.mastermind/CLAUDE.md
@${pfx}.mastermind/engineering/fields/${field}/field.md
@${pfx}.mastermind/engineering/contexts/${ctx}/field.md
@${pfx}.mastermind/engineering/contexts/${ctx}/lessons.md"

    # Claude Code + Codex read these nested files by path (tool-enforced).
    mm_write_block "$abs/CLAUDE.md" "$imports"
    mm_write_block "$abs/AGENTS.md" "$imports"
    # Cursor: a SMALL glob-scoped rule (not the full kernel — the root rule carries that; a
    # full copy per app would feed Cursor's known monorepo over-load bug).
    mkdir -p "$abs/.cursor/rules"
    { printf -- '---\nglobs: %s\ndescription: MasterMind context for %s\n---\n' "$glob" "$ctx"
      printf 'This app uses the MasterMind **%s** field and the **%s** context.\n' "$field" "$ctx"
      printf 'Its knowledge is in `%s.mastermind/engineering/fields/%s/` and `.../contexts/%s/`.\n' "$pfx" "$field" "$ctx"
      printf 'The repo-root `.cursor/rules/mastermind.mdc` carries the full kernel; this only routes.\n'
    } > "$abs/.cursor/rules/mastermind.mdc"

    ok "context '$ctx' ($field) → $adir/"
  done < "$map"
}

# Seed a commented example routes.map so the feature is discoverable, without routing anything.
seed_routes_example() {
  local map="$BRAIN/routes.map"
  [ -f "$map" ] && return 0
  cat > "$map" <<'RMAP'
# routes.map — per-app field/context routing (monorepos). One rule per line:
#   <path-glob>   <context-name>
# The installer compiles each rule into that directory's native, tool-enforced anchor
# (nested CLAUDE.md / AGENTS.md + a glob-scoped Cursor rule). A missing context is created
# from the template, using the default field. Delete this file to go back to single-field.
#
# Example (uncomment and adapt):
#   apps/web/**    web
#   apps/api/**     api
#   packages/**       shared
RMAP
}

if [ "$ISOLATED" = 1 ] && [ "$MODE" = install ]; then
  sync_isolated_brain
  ok "isolated brain → .mastermind/ (v$(cat "$BRAIN/VERSION")) — this project's own field, lessons and stack"
  seed_routes_example
  generate_context_anchors
fi

if [ "$MODE" != check ]; then
  printf 'MasterMind → %s%s%s\n' "$g" "$([ "$SCOPE" = global ] && echo "global — every project" || echo "this project")" "$x"
fi

# True if a path is a MasterMind link (into this repo) or carries the pointer line.
is_wired() {
  local f="$1"
  is_ours "$f" || { [ -f "$f" ] && grep -q 'mastermind/CLAUDE.md' "$f"; }
}

# --- Which tools? -------------------------------------------------------------
if [ ${#TOOLS[@]} -eq 0 ]; then
  if [ "$MODE" = check ]; then
    # verify only what's actually wired here (or globally with --global)
    is_wired "$CLAUDE_DIR/CLAUDE.md" && TOOLS+=("claude")
    is_wired "$CODEX_AGENTS" && TOOLS+=("codex")
    [ -f "$PROJECT/.cursor/rules/mastermind.mdc" ] && TOOLS+=("cursor")
    is_wired "$PROJECT/GEMINI.md" && TOOLS+=("gemini")
    is_wired "$PROJECT/.github/copilot-instructions.md" && TOOLS+=("copilot")
    if [ ${#TOOLS[@]} -eq 0 ]; then
      bad "MasterMind isn't set up $([ "$SCOPE" = global ] && echo globally || echo 'in this project') yet."
      echo "  Run:  ~/.mastermind/install.sh$([ "$SCOPE" = global ] && echo ' --global')"
      exit 1
    fi
  else
    # install: wire the tools you have
    { command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; } && TOOLS+=("claude")
    { command -v codex  >/dev/null 2>&1 || [ -d "$HOME/.codex" ]; }  && TOOLS+=("codex")
    if [ "$SCOPE" = project ]; then
      { command -v cursor >/dev/null 2>&1 || [ -d "$HOME/.cursor" ]; } && TOOLS+=("cursor")
      { command -v gemini >/dev/null 2>&1 || [ -d "$HOME/.gemini" ]; } && TOOLS+=("gemini")
    fi
    if [ ${#TOOLS[@]} -eq 0 ]; then
      warn "No supported tool detected."
      echo "  You need an AI coding tool first — e.g. Claude Code: https://claude.com/claude-code"
    fi
  fi
fi

# --- Per tool ----------------------------------------------------------------
# ${TOOLS[@]+…} guard: on macOS bash 3.2, an empty array under `set -u` is treated
# as unbound — so a tool-less machine would crash here instead of exiting gracefully.
for tool in ${TOOLS[@]+"${TOOLS[@]}"}; do
  case "$tool" in
    claude)  wire_claude "$CLAUDE_DIR" ;;
    codex)   printf '\nCodex:\n';  wire_brain_file "$CODEX_AGENTS" "$BRAIN/AGENTS.md" ;;
    gemini)
      printf '\nGemini:\n'
      if [ "$SCOPE" = global ]; then warn "global Gemini uses the extension:  gemini extensions install github.com/mehrad-dm/mastermind"
      else wire_brain_file "$PROJECT/GEMINI.md" "$BRAIN/CLAUDE.md"; fi ;;
    cursor)
      if [ "$SCOPE" = global ]; then printf '\nCursor:\n'; warn "Cursor rules are per-project — run this inside a project"
      else printf '\nCursor:\n'; wire_cursor; fi ;;
    copilot)
      if [ "$SCOPE" = global ]; then printf '\nCopilot:\n'; warn "Copilot instructions are per-project — run this inside a project"
      else printf '\nGitHub Copilot:\n'; wire_brain_file "$PROJECT/.github/copilot-instructions.md" "$BRAIN/CLAUDE.md"; wire_copilot_hook; fi ;;
    *) warn "skipping unknown tool: $tool";;
  esac
done

# In an isolated project, verify routes.map resolves: every context exists, names a field
# that ships, and its anchor is present. A bad map means an app silently loads the wrong
# knowledge — exactly what this feature exists to prevent — so it counts as an issue.
check_routes() {
  local map="$BRAIN/routes.map"
  [ -f "$map" ] || return 0
  local glob ctx line adir field
  while IFS= read -r line; do
    line="${line//$'\r'/}"; line="${line%%#*}"; line="$(printf '%s' "$line" | awk '{$1=$1};1')"
    [ -n "$line" ] || continue
    if [ "$(printf '%s' "$line" | wc -w | tr -d ' ')" != 2 ]; then
      bad "routes.map: '$line' is not '<glob> <context>'"; ISSUES=$((ISSUES + 1)); continue
    fi
    glob="${line%% *}"; ctx="${line##* }"
    if [ ! -d "$BRAIN/engineering/contexts/$ctx" ]; then
      bad "routes.map: context '$ctx' has no dir — re-run install.sh"; ISSUES=$((ISSUES + 1)); continue
    fi
    field="$(sed -n 's/^field:[[:space:]]*//p' "$BRAIN/engineering/contexts/$ctx/field.md" 2>/dev/null | head -1)"
    [ -d "$BRAIN/engineering/fields/$field" ] || { bad "routes.map: context '$ctx' names missing field '$field'"; ISSUES=$((ISSUES + 1)); continue; }
    adir="${glob%/\*\*}"; adir="${adir%/\*}"; adir="${adir%/}"
    case "$adir" in ''|'*'|'.'|'**') continue ;; esac
    [ -d "$PROJECT/$adir" ] || continue
    if [ -f "$PROJECT/$adir/CLAUDE.md" ] && grep -q 'MASTERMIND:START' "$PROJECT/$adir/CLAUDE.md"; then
      ok "route $adir/ → $ctx ($field)"
    else bad "route $adir/ → $ctx: anchor missing — re-run install.sh"; ISSUES=$((ISSUES + 1)); fi
  done < "$map"
}
[ "$MODE" = check ] && [ "$ISOLATED" = 1 ] && { printf '\nRoutes:\n'; check_routes; }

# --- Report ------------------------------------------------------------------
if [ "$MODE" = check ]; then
  echo
  if [ "$ISSUES" -eq 0 ]; then
    printf '%s✓ MasterMind is healthy here — every wired tool resolves.%s\n' "$g" "$x"
    # An isolated project pins its own copy, so it can drift behind the clone silently.
    # Surface it: the whole point of isolation is that updates are the user's choice, which
    # only works if they can see there is one to make.
    if [ "$ISOLATED" = 1 ] && [ -f "$BRAIN/VERSION" ]; then
      pv="$(cat "$BRAIN/VERSION")"; cv="$(cat "$REPO/VERSION" 2>/dev/null || echo "$pv")"
      if [ "$pv" != "$cv" ]; then
        printf '  %s⬆ this project is on v%s; the clone has v%s.%s  Refresh:  ~/.mastermind/install.sh\n' "$y" "$pv" "$cv" "$x"
      else
        printf '  isolated brain v%s — up to date with the clone.\n' "$pv"
      fi
    fi
    check_updates; exit 0
  else printf '%s✖ %d issue(s). Re-run the installer to repair.%s\n' "$r" "$ISSUES" "$x"; exit 1; fi
fi

if [ "$SCOPE" = project ]; then
  printf '\n%sActive in THIS project.%s  Add another: cd there && ~/.mastermind/install.sh   ·   Claude+Codex everywhere: --global\n' "$g" "$x"
  printf 'Using Copilot here? add it with:  ~/.mastermind/install.sh copilot\n'
fi
printf 'Update: cd ~/.mastermind && git pull && ~/.mastermind/install.sh   ·   Verify: ~/.mastermind/install.sh --check\n'
printf "\nDone — now RESTART your tool. (Until you restart, the brain isn't loaded yet.)\n"
