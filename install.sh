#!/usr/bin/env bash
# MasterMind installer — makes this repo usable by your AI coding tools.
#
# The repo is the single source of truth. This script creates a tool-neutral
# canonical location (~/.mastermind) plus the entry files each tool expects,
# all as symlinks — so editing the repo updates every tool instantly, and
# `git pull` upgrades them all. It never touches your personal data (Claude
# sessions/memory/settings, etc.).
#
# Usage:
#   ./install.sh                 # canonical + auto-detect installed tools
#   ./install.sh claude codex    # canonical + only the named tools
# Tools: claude | codex   (cursor/copilot are per-project — see README)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
link() { ln -sfn "$1" "$2"; echo "  linked $2"; }

# --- Canonical, tool-neutral location (always) -------------------------------
link "$REPO" "$HOME/.mastermind"
echo "MasterMind canonical brain -> ~/.mastermind"

TOOLS=("$@")
if [ ${#TOOLS[@]} -eq 0 ]; then
  # auto-detect
  command -v claude >/dev/null 2>&1 && TOOLS+=("claude")
  [ -d "$HOME/.claude" ] && [[ ! " ${TOOLS[*]} " == *" claude "* ]] && TOOLS+=("claude")
  { command -v codex >/dev/null 2>&1 || [ -d "$HOME/.codex" ]; } && TOOLS+=("codex")
fi

for tool in "${TOOLS[@]}"; do
  case "$tool" in
    claude)
      mkdir -p "$HOME/.claude/agents" "$HOME/.claude/skills"
      link "$REPO/CLAUDE.md"                    "$HOME/.claude/CLAUDE.md"
      link "$REPO/engineering"                  "$HOME/.claude/engineering"
      for a in "$REPO"/agents/*.md; do link "$a" "$HOME/.claude/agents/$(basename "$a")"; done
      for s in "$REPO"/skills/*/; do link "$s" "$HOME/.claude/skills/$(basename "$s")"; done
      echo "Claude Code: installed (agents + skills native)."
      ;;
    codex)
      mkdir -p "$HOME/.codex"
      link "$REPO/AGENTS.md" "$HOME/.codex/AGENTS.md"
      echo "Codex: installed (reads ~/.codex/AGENTS.md; brain at ~/.mastermind)."
      ;;
    *) echo "  (skipping unknown tool: $tool)";;
  esac
done

cat <<'EOF'

Per-project tools (Cursor, Copilot) — add one line pointing at the brain:
  Cursor  : .cursor/rules/mastermind.mdc  ->  "Follow ~/.mastermind/CLAUDE.md."
  Copilot : .github/copilot-instructions.md -> "Follow ~/.mastermind/CLAUDE.md."
Or drop an AGENTS.md in the project root:  ln -s ~/.mastermind/AGENTS.md AGENTS.md

Done. Restart your tool to pick up MasterMind.
EOF
