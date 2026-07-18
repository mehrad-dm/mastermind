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
# The repo is the single source of truth (linked at ~/.mastermind); this just points a
# tool at it. Re-run anytime — ESPECIALLY after `git pull` — to repair links. It NEVER
# destroys your data: a real CLAUDE.md is backed up, and an existing AGENTS.md /
# GEMINI.md / copilot file is appended to (never overwritten).
#
# Usage:
#   cd my-project && ~/.mastermind/install.sh          # this project, all your tools
#   ~/.mastermind/install.sh --global                  # Claude+Codex in every project
#   ~/.mastermind/install.sh --check                   # doctor (add --global to check global)
#   ~/.mastermind/install.sh --uninstall               # remove from this project (or --global)
#   cd my-project && ~/.mastermind/install.sh cursor   # only the named tool(s)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE=install; SCOPE=project; TOOLS=()
for a in "$@"; do
  case "$a" in
    --check)     MODE=check ;;
    --uninstall) MODE=uninstall ;;
    --global)    SCOPE=global ;;
    --*)         printf 'unknown flag: %s\n' "$a" >&2; exit 2 ;;
    *)           TOOLS+=("$a") ;;
  esac
done

g=$'\033[0;32m'; y=$'\033[0;33m'; r=$'\033[0;31m'; x=$'\033[0m'
ok()   { printf '  %s✓%s %s\n' "$g" "$x" "$*"; }
warn() { printf '  %s⚠%s %s\n' "$y" "$x" "$*"; }
bad()  { printf '  %s✖%s %s\n' "$r" "$x" "$*"; }
ISSUES=0; LINKED_SKILLS=0; LINKED_AGENTS=0; PRUNED=0
HINT='Follow ~/.mastermind/CLAUDE.md — the MasterMind brain (skills, agents, engineering rigor).'

# Scope → where Claude/Codex get wired (project-local by default, home with --global).
if [ "$SCOPE" = global ]; then
  CLAUDE_DIR="$HOME/.claude"; CODEX_AGENTS="$HOME/.codex/AGENTS.md"
else
  CLAUDE_DIR="$PWD/.claude";  CODEX_AGENTS="$PWD/AGENTS.md"
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
  local dst="$PWD/.cursor/rules/mastermind.mdc"
  if [ "$MODE" = check ]; then
    if [ -f "$dst" ] && grep -q 'mastermind/CLAUDE.md' "$dst"; then ok ".cursor/rules/mastermind.mdc"
    else bad ".cursor rule not set"; ISSUES=$((ISSUES + 1)); fi
    return
  fi
  mkdir -p "$PWD/.cursor/rules"
  printf -- '---\nalwaysApply: true\n---\n%s\n' "$HINT" > "$dst"; ok ".cursor/rules/mastermind.mdc"
}

# Wire Claude Code natively (skills + agents + kernel) into a base .claude dir.
wire_claude() {
  local base="$1"
  [ "$MODE" = check ] || mkdir -p "$base/agents" "$base/skills"
  printf '\nClaude Code:\n'
  safe_link "$REPO/CLAUDE.md" "$base/CLAUDE.md"
  # Global links engineering into ~/.claude; per-project reads it via ~/.mastermind.
  [ "$SCOPE" = global ] && safe_link "$REPO/engineering" "$base/engineering"
  prune_dead_links "$base/skills"; prune_dead_links "$base/agents"
  LINKED_SKILLS=0; LINKED_AGENTS=0
  local a s
  for a in "$REPO"/agents/*.md; do
    safe_link "$a" "$base/agents/$(basename "$a")"; [ "$MODE" = check ] || LINKED_AGENTS=$((LINKED_AGENTS + 1))
  done
  for s in "$REPO"/skills/*/; do
    safe_link "${s%/}" "$base/skills/$(basename "$s")"; [ "$MODE" = check ] || LINKED_SKILLS=$((LINKED_SKILLS + 1))
  done
  [ "$MODE" = check ] || ok "$LINKED_SKILLS skills, $LINKED_AGENTS agents linked · $PRUNED stale removed"
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
  if [ -L "$f" ] && readlink "$f" | grep -qF "$REPO"; then rm -f "$f"; ok "removed $(basename "$f")"; return 0; fi
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
  remove_link "$PWD/GEMINI.md"                         && n=$((n + 1))
  remove_link "$PWD/.github/copilot-instructions.md"   && n=$((n + 1))
  if [ -f "$PWD/.cursor/rules/mastermind.mdc" ]; then rm -f "$PWD/.cursor/rules/mastermind.mdc"; ok "removed .cursor/rules/mastermind.mdc"; n=$((n + 1)); fi
  for f in "$CODEX_AGENTS" "$PWD/GEMINI.md" "$PWD/.github/copilot-instructions.md"; do
    [ -f "$f" ] && grep -q 'mastermind/CLAUDE.md' "$f" && warn "left your $(basename "$f") in place — it still has a MasterMind pointer line you can remove by hand"
  done
  printf '\n%s✓ removed %d link(s).%s Your own files were left untouched. (~/.mastermind stays; delete the clone to remove the brain.)\n' "$g" "$n" "$x"
  exit 0
fi

# --- Brain source (always) ---------------------------------------------------
if [ "$MODE" != check ]; then ln -sfn "$REPO" "$HOME/.mastermind"; fi

# --- Per-project sanity: need a real project dir, not the clone or ~ ----------
if [ "$SCOPE" = project ] && [ "$MODE" = install ] && { [ "$PWD" -ef "$REPO" ] || [ "$PWD" -ef "$HOME" ]; }; then
  printf 'MasterMind brain → ~/.mastermind  %s✓ ready%s\n\n' "$g" "$x"
  printf 'Now add it to a project:\n'
  printf '  cd your-project && ~/.mastermind/install.sh      (just that project — recommended)\n'
  printf '  ~/.mastermind/install.sh --global                (Claude + Codex, every project)\n'
  exit 0
fi

if [ "$MODE" != check ]; then
  printf 'MasterMind → %s%s%s\n' "$g" "$([ "$SCOPE" = global ] && echo "global — every project" || echo "this project")" "$x"
fi

# True if a path is a MasterMind link (into this repo) or carries the pointer line.
is_wired() {
  local f="$1"
  { [ -L "$f" ] && readlink "$f" | grep -qF "$REPO"; } || { [ -f "$f" ] && grep -q 'mastermind/CLAUDE.md' "$f"; }
}

# --- Which tools? -------------------------------------------------------------
if [ ${#TOOLS[@]} -eq 0 ]; then
  if [ "$MODE" = check ]; then
    # verify only what's actually wired here (or globally with --global)
    is_wired "$CLAUDE_DIR/CLAUDE.md" && TOOLS+=("claude")
    is_wired "$CODEX_AGENTS" && TOOLS+=("codex")
    [ -f "$PWD/.cursor/rules/mastermind.mdc" ] && TOOLS+=("cursor")
    is_wired "$PWD/GEMINI.md" && TOOLS+=("gemini")
    is_wired "$PWD/.github/copilot-instructions.md" && TOOLS+=("copilot")
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
    codex)   printf '\nCodex:\n';  wire_brain_file "$CODEX_AGENTS" "$REPO/AGENTS.md" ;;
    gemini)
      printf '\nGemini:\n'
      if [ "$SCOPE" = global ]; then warn "global Gemini uses the extension:  gemini extensions install github.com/mehrad-dm/mastermind"
      else wire_brain_file "$PWD/GEMINI.md" "$REPO/CLAUDE.md"; fi ;;
    cursor)
      if [ "$SCOPE" = global ]; then printf '\nCursor:\n'; warn "Cursor rules are per-project — run this inside a project"
      else printf '\nCursor:\n'; wire_cursor; fi ;;
    copilot)
      if [ "$SCOPE" = global ]; then printf '\nCopilot:\n'; warn "Copilot instructions are per-project — run this inside a project"
      else printf '\nGitHub Copilot:\n'; wire_brain_file "$PWD/.github/copilot-instructions.md" "$REPO/CLAUDE.md"; fi ;;
    *) warn "skipping unknown tool: $tool";;
  esac
done

# --- Report ------------------------------------------------------------------
if [ "$MODE" = check ]; then
  echo
  if [ "$ISSUES" -eq 0 ]; then
    printf '%s✓ MasterMind is healthy here — every wired tool resolves.%s\n' "$g" "$x"; check_updates; exit 0
  else printf '%s✖ %d issue(s). Re-run the installer to repair.%s\n' "$r" "$ISSUES" "$x"; exit 1; fi
fi

if [ "$SCOPE" = project ]; then
  printf '\n%sActive in THIS project.%s  Add another: cd there && ~/.mastermind/install.sh   ·   Claude+Codex everywhere: --global\n' "$g" "$x"
  printf 'Using Copilot here? add it with:  ~/.mastermind/install.sh copilot\n'
fi
printf 'Update: cd ~/.mastermind && git pull && ~/.mastermind/install.sh   ·   Verify: ~/.mastermind/install.sh --check\n'
printf "\nDone — now RESTART your tool. (Until you restart, the brain isn't loaded yet.)\n"
