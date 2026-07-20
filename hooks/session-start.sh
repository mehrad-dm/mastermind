#!/usr/bin/env bash
#
# MasterMind bootstrap — re-hands the model its own brain.
#
# WHY THIS EXISTS
#   A kernel read once at startup fades as the context window fills, and is dropped
#   outright when the session compacts. From that moment the skills are inert: present
#   on disk, never invoked. The user still sees confident answers — just without the
#   discipline. Silent, total, and exactly when stakes are highest (long sessions).
#
#   So we re-inject on startup AND on compaction. That second one is the whole point.
#
# WHAT IT INJECTS
#   The kernel (CLAUDE.md) — nothing else. Skills stay on-demand; this only guarantees
#   the routing layer that reaches for them is present.
#
# PORTABILITY
#   Emits whichever field the host reads: Cursor wants additional_context, Claude Code
#   wants hookSpecificOutput.additionalContext, others take the SDK-standard top-level
#   additionalContext. We emit exactly one, because a host reading both would double it.
#
#   Shape is chosen by an explicit first argument (cursor|claude|sdk) when given, and
#   only falls back to env sniffing otherwise. Env detection alone is not enough: a
#   PROJECT-level Cursor hook gets no CURSOR_PLUGIN_ROOT, so it would silently emit the
#   wrong field and inject nothing. Callers that know the host must say so.
#
# Failure is always silent: a broken hook must never block a session.

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
