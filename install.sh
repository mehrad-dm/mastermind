#!/usr/bin/env bash
# MasterMind installer — safe, idempotent, self-healing.
#
# The repo is the single source of truth; this links it into your AI tools.
# Re-run it anytime — ESPECIALLY after `git pull` — to repair links when the
# repo changes: it prunes stale/dangling links and relinks the current skills
# and agents, so an upgrade can never leave your skills silently dead.
#
# It NEVER destroys your data: an existing real ~/.claude/CLAUDE.md is backed
# up before anything is linked.
#
# Usage:
#   ./install.sh                 # install / repair for auto-detected tools
#   ./install.sh claude codex    # only the named tools
#   ./install.sh --check         # doctor: verify everything resolves, change nothing
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE=install
if [ "${1:-}" = "--check" ]; then MODE=check; shift || true; fi

g=$'\033[0;32m'; y=$'\033[0;33m'; r=$'\033[0;31m'; x=$'\033[0m'
ok()   { printf '  %s✓%s %s\n' "$g" "$x" "$*"; }
warn() { printf '  %s⚠%s %s\n' "$y" "$x" "$*"; }
bad()  { printf '  %s✖%s %s\n' "$r" "$x" "$*"; }
ISSUES=0; LINKED_SKILLS=0; LINKED_AGENTS=0; PRUNED=0

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

# Tell the user if their clone is behind origin. Network-optional: any failure
# (offline, no upstream, detached HEAD) is silent — this never blocks or errors.
check_updates() {
  command -v git >/dev/null 2>&1 || return 0
  git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git -C "$REPO" fetch --quiet 2>/dev/null || return 0
  local here up base
  here="$(git -C "$REPO" rev-parse @ 2>/dev/null)"        || return 0
  up="$(git -C "$REPO" rev-parse '@{u}' 2>/dev/null)"     || return 0
  base="$(git -C "$REPO" merge-base @ '@{u}' 2>/dev/null)" || return 0
  if [ "$here" != "$up" ] && [ "$here" = "$base" ]; then
    printf '%s⬆ An update is available.%s  cd ~/.mastermind && git pull && ./install.sh\n' "$y" "$x"
  fi
}

# --- Canonical, tool-neutral location (always) -------------------------------
if [ "$MODE" != check ]; then
  ln -sfn "$REPO" "$HOME/.mastermind"
  printf 'MasterMind brain → ~/.mastermind\n'
fi

# --- Which tools? ------------------------------------------------------------
TOOLS=("$@")
if [ ${#TOOLS[@]} -eq 0 ]; then
  command -v claude >/dev/null 2>&1 && TOOLS+=("claude")
  [ -d "$HOME/.claude" ] && [[ ! " ${TOOLS[*]-} " == *" claude "* ]] && TOOLS+=("claude")
  { command -v codex >/dev/null 2>&1 || [ -d "$HOME/.codex" ]; } && TOOLS+=("codex")
fi
if [ ${#TOOLS[@]} -eq 0 ]; then
  warn "No supported tool detected (Claude Code / Codex)."
  echo "  The brain is at ~/.mastermind. For Cursor/Copilot, see the note below;"
  echo "  or install a tool and re-run this script."
fi

# --- Per tool ----------------------------------------------------------------
for tool in "${TOOLS[@]}"; do
  case "$tool" in
    claude)
      [ "$MODE" = check ] || mkdir -p "$HOME/.claude/agents" "$HOME/.claude/skills"
      printf '\nClaude Code:\n'
      safe_link "$REPO/CLAUDE.md"     "$HOME/.claude/CLAUDE.md"
      safe_link "$REPO/engineering"   "$HOME/.claude/engineering"
      # self-heal: drop stale links (renamed/removed skills), then link the current set
      prune_dead_links "$HOME/.claude/skills"
      prune_dead_links "$HOME/.claude/agents"
      for a in "$REPO"/agents/*.md; do
        safe_link "$a" "$HOME/.claude/agents/$(basename "$a")"; [ "$MODE" = check ] || LINKED_AGENTS=$((LINKED_AGENTS + 1))
      done
      for s in "$REPO"/skills/*/; do
        safe_link "${s%/}" "$HOME/.claude/skills/$(basename "$s")"; [ "$MODE" = check ] || LINKED_SKILLS=$((LINKED_SKILLS + 1))
      done
      [ "$MODE" = check ] || ok "$LINKED_SKILLS skills, $LINKED_AGENTS agents linked · $PRUNED stale removed"
      ;;
    codex)
      [ "$MODE" = check ] || mkdir -p "$HOME/.codex"
      printf '\nCodex:\n'
      safe_link "$REPO/AGENTS.md" "$HOME/.codex/AGENTS.md"
      ;;
    *) warn "skipping unknown tool: $tool";;
  esac
done

# --- Report ------------------------------------------------------------------
if [ "$MODE" = check ]; then
  echo
  if [ "$ISSUES" -eq 0 ]; then
    printf '%s✓ MasterMind is healthy — kernel, skills, and agents all resolve.%s\n' "$g" "$x"
    check_updates
    exit 0
  else printf '%s✖ %d issue(s). Run ./install.sh to repair.%s\n' "$r" "$ISSUES" "$x"; exit 1; fi
fi

cat <<'EOF'

Per-project tools (Cursor, Copilot) — add one line pointing at the brain:
  Cursor  : .cursor/rules/mastermind.mdc     → "Follow ~/.mastermind/CLAUDE.md."
  Copilot : .github/copilot-instructions.md  → "Follow ~/.mastermind/CLAUDE.md."

To UPDATE later:  cd ~/.mastermind && git pull && ./install.sh   (repairs links after any change)
To VERIFY:        ~/.mastermind/install.sh --check

Done — now RESTART your tool. (Until you restart, the brain isn't loaded yet.)
EOF
