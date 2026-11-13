#!/usr/bin/env bash

set -uo pipefail
SHAPE="${1:-auto}"
# Bytes, not the caller's locale, so the counts and character classes mean the same everywhere.
export LC_ALL=C

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL="$REPO/CLAUDE.md"
HEADING='MasterMind: global operating system'

[ -s "$KERNEL" ] || exit 0

proj="${CLAUDE_PROJECT_DIR:-$PWD}"

# A project with its own install speaks for itself: a global or plugin copy stays silent there.
own="$proj/.mastermind/hooks/session-start.sh"
if [ -e "$own" ] && ! [ "$own" -ef "${BASH_SOURCE[0]}" ]; then exit 0; fi

# JSON string escaping via parameter substitution: one C-level pass each, no subshells.
esc() {
  local s="$1" c hex oct chr
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"
  case "$s" in *[$'\001'-$'\037'$'\177']*)
    for c in 1 2 3 4 5 6 7 8 11 12 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 127; do
      printf -v hex '%04x' "$c"; printf -v oct '\\%03o' "$c"; printf -v chr "$oct"
      s="${s//$chr/\\u$hex}"
    done ;;
  esac
  printf '%s' "$s"
}

# The four patterns below are the ones cli/bin/mastermind.mjs uses for `status` and `next`.
FIELD_NAME_RE='^[#*[:blank:]]*Current field:[*`[:blank:]]*([^*`]*)'
FIELD_LEVEL_RE='^[[:blank:]]*[-*][[:blank:]]*\*\*Level:\*\*[[:blank:]]*([0-9]{1,9})'
SPECS_DIR_RE='^-?[[:blank:]]*`?specs-dir:[[:blank:]]*([^`[:blank:]]+)'
FEATURE_RE='^[0-9]{3,}-[a-z0-9-]+$'

first_match() {                     # $1 file, $2 pattern: sets MATCH, fails when no line matches
  local line
  MATCH=""
  [ -f "$1" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    if [[ $line =~ $2 ]]; then MATCH="${BASH_REMATCH[1]}"; return 0; fi
  done < "$1"
  return 1
}

FIELD="$proj/.mastermind/engineering/active-field.md"
[ -f "$FIELD" ] || FIELD="$REPO/engineering/active-field.md"
name=""; level=""
if first_match "$FIELD" "$FIELD_NAME_RE"; then
  name="${MATCH%"${MATCH##*[![:blank:]]}"}"
  case "$name" in [Nn][Oo][Nn][Ee]*|_*) name="" ;; esac
fi
if first_match "$FIELD" "$FIELD_LEVEL_RE"; then level=$((10#$MATCH)); elif [ -n "$name" ]; then level=1; else level=0; fi

field_nudge=""
if [ -z "$name" ] || [ "$level" -eq 0 ]; then
  field_nudge="\nNo field pack yet: tell the user in one line and offer the init skill, do not run it unasked, and carry on with the task on the universal core."
  case "$REPO/" in "$proj"/*) ;; *) field_nudge="$field_nudge This brain is shared or global: say in that offer that the pack will be written in the home directory." ;; esac
fi

spec_nudge=""
specs_dir=specs
if first_match "$proj/.mastermind/prefs.md" "$SPECS_DIR_RE"; then
  case "$MATCH" in /*) ;; *) case "/${MATCH//\\//}/" in */../*) ;; *) specs_dir="$MATCH" ;; esac ;; esac
fi
for d in "$proj/$specs_dir"/[0-9][0-9][0-9]*-*; do
  [ -d "$d" ] && [ ! -L "$d" ] && [[ ${d##*/} =~ $FEATURE_RE ]] || continue
  spec_nudge="\nThis project works spec-first: it has feature folders in $(esc "$specs_dir")/. Run mastermind next before choosing a spec-driven skill."
  break
done
nudge="$field_nudge$spec_nudge"

# The file this session loads the kernel from natively, if any.
loaded="$(grep -lsE "^# $HEADING|^@.*\.mastermind/CLAUDE\.md" \
  "$proj/CLAUDE.md" "$proj/.claude/CLAUDE.md" "$proj/AGENTS.md" "${HOME:-/nonexistent}/.claude/CLAUDE.md" 2>/dev/null || true)"
loaded="${loaded%%$'\n'*}"

if [ -n "$loaded" ]; then
  payload="<mastermind-brain>\nYou are running as MasterMind. Your operating contract is the MasterMind kernel, which this session\nloads from $(esc "$loaded"): it governs how you decide, build, verify, and report.\nFollow it. If your context holds no heading that reads $HEADING, the\nkernel did not load: read $(esc "$KERNEL") in full before doing anything else.$nudge\n</mastermind-brain>"
else
  tilde='~'
  root="Brain root: $(esc "$REPO") (a $tilde/.mastermind/... path in a skill means this folder)."
  head="<mastermind-brain>\nYou are running as MasterMind. No CLAUDE.md or AGENTS.md here holds the kernel, so it is carried whole below: follow it.\n$root"
  tail="</mastermind-brain>"
  # Claude Code cuts hook context over 10,000 characters to a preview, counting an astral
  # character as two. The cheap count runs first so a kernel far over never pays for the loop.
  body=""; clean=1; payload=""
  units=$(( $(tr -d '\200-\277' < "$KERNEL" | wc -c) ))
  if [ "$units" -le 9500 ]; then
    units=0
    while IFS= read -r line || [ -n "$line" ]; do
      lead="${line//[$'\200'-$'\277']/}"; wide="${line//[!$'\360'-$'\367']/}"
      units=$((units + ${#lead} + ${#wide} + 1))
      case "$line" in *[$'\001'-$'\010'$'\013'$'\014'$'\016'-$'\037'$'\177']*) clean=0 ;; esac
      line="${line//\\/\\\\}"; line="${line//\"/\\\"}"; line="${line//$'\r'/\\r}"; line="${line//$'\t'/\\t}"
      body="$body$line\\n"
    done < "$KERNEL"
    # The kernel is never cut: a nudge that does not fit beside it is dropped, the spec one first.
    if [ "$clean" = 1 ] && [ "$units" -le 9500 ]; then
      for extra in "$nudge" "$field_nudge" ""; do
        [ $((units + ${#head} + ${#extra} + 4 + ${#tail})) -lt 10000 ] || continue
        payload="$head$extra\n\n$body$tail"; break
      done
    fi
  fi
  if [ -z "$payload" ]; then
    payload="<mastermind-brain>\nYou are running as MasterMind. The MasterMind kernel is your operating contract, and it is NOT loaded:\nno CLAUDE.md or AGENTS.md in this session holds it, and at $units characters it does not fit in this\nmessage, which is capped at 10,000. Read $(esc "$KERNEL") in full before doing anything else, then follow it.\n$root$nudge\n</mastermind-brain>"
  fi
fi

if [ "$SHAPE" = auto ]; then
  if   [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then SHAPE=cursor
  elif [ -n "${COPILOT_CLI:-}" ]; then SHAPE=sdk
  elif [ -n "${CLAUDE_PLUGIN_ROOT:-}${CLAUDE_PROJECT_DIR:-}" ]; then SHAPE=claude
  else SHAPE=sdk
  fi
fi

# printf (not a heredoc): bash 5.3+ can hang on heredocs in hook contexts.
case "$SHAPE" in
  cursor) printf '{\n  "additional_context": "%s"\n}\n' "$payload" ;;
  claude) printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$payload" ;;
  *)      printf '{\n  "additionalContext": "%s"\n}\n' "$payload" ;;
esac

exit 0
