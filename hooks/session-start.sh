#!/usr/bin/env bash

set -uo pipefail
SHAPE="${1:-auto}"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL="$REPO/CLAUDE.md"

[ -f "$KERNEL" ] || exit 0

kernel="$(cat "$KERNEL" 2>/dev/null)" || exit 0
[ -n "$kernel" ] || exit 0

# JSON string escaping via parameter substitution — one C-level pass each, no subshells.
esc() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

payload="<mastermind-brain>\nYou are running as MasterMind. The kernel below is your operating\ncontract for this session — it governs how you decide, build, verify, and report.\nFollow it. Re-read it here rather than relying on memory of an earlier turn.\n\n$(esc "$kernel")\n</mastermind-brain>"

if [ "$SHAPE" = auto ]; then
  if   [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then SHAPE=cursor
  elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -z "${COPILOT_CLI:-}" ]; then SHAPE=claude
  else SHAPE=sdk
  fi
fi

# printf (not a heredoc) — bash 5.3+ can hang on heredocs in hook contexts.
case "$SHAPE" in
  cursor) printf '{\n  "additional_context": "%s"\n}\n' "$payload" ;;
  claude) printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$payload" ;;
  *)      printf '{\n  "additionalContext": "%s"\n}\n' "$payload" ;;
esac

exit 0
