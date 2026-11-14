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
# Codex starts a hook in the session's directory, which can be below the project root.
if [ "$SHAPE" = codex ]; then
  # A project's own brain carries the manifest of what was copied into it; a clone does not.
  if [ "${REPO##*/}" = .mastermind ] && [ ! -L "$REPO" ] && [ -f "$REPO/.manifest" ]; then proj="${REPO%/*}"
  else proj="$(git rev-parse --show-toplevel 2>/dev/null)"; [ -n "$proj" ] || proj="$PWD"; fi
fi
# Claude Code cuts hook context over 10,000 characters to a preview. Codex cuts at roughly
# 2,500 tokens and gives no character figure, so 9,000 characters is the limit used for it.
cap=10000; cap_words='10,000'
if [ "$SHAPE" = codex ]; then cap=9000; cap_words='about 9,000 (2,500 tokens)'; fi

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

# The five patterns below are the ones cli/bin/mastermind.mjs uses for `status` and `next`.
FIELD_NAME_RE='^[#*[:blank:]]*Current field:[*`[:blank:]]*([^*`]*)'
FIELD_PACK_RE='^[[:blank:]]*[-*][[:blank:]]*\*\*Field pack:\*\*[[:blank:]]*`([^`]*)`'
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
# A field is active when the file names it and its pack is on disk; an active field is at least level 1.
if first_match "$FIELD" "$FIELD_NAME_RE"; then
  name="${MATCH%"${MATCH##*[![:blank:]]}"}"
  case "$name" in [Nn][Oo][Nn][Ee]*|_*) name="" ;; esac
fi
if [ -z "$name" ] && first_match "$FIELD" "$FIELD_PACK_RE"; then
  name="${MATCH%/}"; name="${name##*/}"
  case "$name" in [Nn][Oo][Nn][Ee]*|_*) name="" ;; esac
fi
[ -n "$name" ] && [ ! -d "$(dirname "$FIELD")/fields/$name" ] && name=""
level=0
if [ -n "$name" ]; then
  first_match "$FIELD" "$FIELD_LEVEL_RE" && level=$((10#$MATCH))
  [ "$level" -ge 1 ] || level=1
fi

# Each nudge has a short form that states only the fact, for a payload that carries the kernel:
# the kernel already says what to do about it.
field_nudge=""; field_state=""
if [ -z "$name" ] || [ "$level" -eq 0 ]; then
  field_nudge="\nNo field pack yet: end your first announce line with \\\"no field pack yet: say init to build one\\\". Never run init unasked; carry on with the task on the universal core."
  field_state="\nState: no field pack here."
  case "$REPO/" in "$proj"/*) ;; *)
    field_nudge="$field_nudge This brain is shared or global: add \\\"(the pack goes in your home directory)\\\"."
    field_state="\nState: no field pack; the brain is shared, so a pack is written in the home directory." ;;
  esac
else
  field_nudge="\nState: field pack \\\"$(esc "$name")\\\" (level $level): load its files when a task touches its stack."
  field_state="$field_nudge"
fi

spec_nudge=""; spec_state=""
specs_dir=specs
if first_match "$proj/.mastermind/prefs.md" "$SPECS_DIR_RE"; then
  case "$MATCH" in /*) ;; *) case "/${MATCH//\\//}/" in */../*) ;; *) specs_dir="$MATCH" ;; esac ;; esac
fi
for d in "$proj/$specs_dir"/[0-9][0-9][0-9]*-*; do
  [ -d "$d" ] && [ ! -L "$d" ] && [[ ${d##*/} =~ $FEATURE_RE ]] || continue
  spec_nudge="\nThis project works spec-first: it has feature folders in $(esc "$specs_dir")/. Run mastermind next before choosing a spec-driven skill."
  spec_state="\nState: this project has feature folders in $(esc "$specs_dir")/."
  break
done
nudge="$field_nudge$spec_nudge"

if [ "$SHAPE" = auto ]; then
  if   [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then SHAPE=cursor
  elif [ -n "${COPILOT_CLI:-}" ]; then SHAPE=sdk
  elif [ -n "${CLAUDE_PLUGIN_ROOT:-}${CLAUDE_PROJECT_DIR:-}" ]; then SHAPE=claude
  else SHAPE=sdk
  fi
fi

# The file this session loads the kernel from natively, if any.
if [ "$SHAPE" = cursor ]; then
  # Cursor reads its always-on rule and AGENTS.md; it has no notion of .claude/CLAUDE.md.
  loaded=""
  for f in "$proj/.cursor/rules/mastermind.mdc" "$proj/AGENTS.md"; do
    if grep -qsE "^# $HEADING" "$f"; then loaded="$f"; break; fi
  done
elif [ "$SHAPE" = codex ]; then
  # Codex reads one file per directory, an override first, and has no import syntax.
  loaded=""
  for dir in "$proj" "${CODEX_HOME:-${HOME:-/nonexistent}/.codex}"; do
    for f in "$dir/AGENTS.override.md" "$dir/AGENTS.md"; do
      [ -s "$f" ] || continue
      if [ -z "$loaded" ] && grep -qsE "^# $HEADING" "$f"; then loaded="$f"; fi
      break
    done
  done
else
  loaded="$(grep -lsE "^# $HEADING|^@.*\.mastermind/CLAUDE\.md" \
    "$proj/CLAUDE.md" "$proj/.claude/CLAUDE.md" "$proj/AGENTS.md" "${HOME:-/nonexistent}/.claude/CLAUDE.md" 2>/dev/null || true)"
  loaded="${loaded%%$'\n'*}"
fi

if [ -n "$loaded" ] && [ "$SHAPE" = codex ]; then
  payload="<mastermind-brain>\nYou are running as MasterMind. Your operating contract is the MasterMind kernel, which Codex read\nfrom $(esc "$loaded") when this session started: it governs how you decide, build, verify, and report.\nFollow it. Codex does not read that file again after a compaction: if your context holds no heading\nthat reads $HEADING, read $(esc "$loaded") in full before doing anything else.$nudge\n</mastermind-brain>"
elif [ -n "$loaded" ]; then
  payload="<mastermind-brain>\nYou are running as MasterMind. Your operating contract is the MasterMind kernel, which this session\nloads from $(esc "$loaded"): it governs how you decide, build, verify, and report.\nFollow it. If your context holds no heading that reads $HEADING, the\nkernel did not load: read $(esc "$KERNEL") in full before doing anything else.$nudge\n</mastermind-brain>"
else
  tilde='~'
  root="Brain root: $(esc "$REPO") (a $tilde/.mastermind/... path in a skill means this folder)."
  intro="<mastermind-brain>\nYou are running as MasterMind. No CLAUDE.md or AGENTS.md here holds the kernel, so it is carried whole below: follow it."
  brief="<mastermind-brain>\nYou are running as MasterMind. Your kernel is carried whole below: follow it."
  tail="</mastermind-brain>"
  # The cap counts an astral character as two. The cheap count runs first so a kernel far over
  # never pays for the loop.
  body=""; clean=1; payload=""
  units=$(( $(tr -d '\200-\277' < "$KERNEL" | wc -c) ))
  if [ "$units" -le $((cap - 500)) ]; then
    units=0
    while IFS= read -r line || [ -n "$line" ]; do
      lead="${line//[$'\200'-$'\277']/}"; wide="${line//[!$'\360'-$'\367']/}"
      units=$((units + ${#lead} + ${#wide} + 1))
      case "$line" in *[$'\001'-$'\010'$'\013'$'\014'$'\016'-$'\037'$'\177']*) clean=0 ;; esac
      line="${line//\\/\\\\}"; line="${line//\"/\\\"}"; line="${line//$'\r'/\\r}"; line="${line//$'\t'/\\t}"
      body="$body$line\\n"
    done < "$KERNEL"
    # The kernel is never cut. What gives way beside it, in order: the framing shortens, the
    # brain-root line goes, and only then a state line, the spec one first.
    if [ "$clean" = 1 ] && [ "$units" -le $((cap - 500)) ]; then
      for head in "$intro\n$root$field_state$spec_state" "$brief\n$root$field_state$spec_state" \
                  "$brief$field_state$spec_state" "$brief$field_state" "$brief"; do
        [ $((units + ${#head} + 4 + ${#tail})) -lt "$cap" ] || continue
        payload="$head\n\n$body$tail"; break
      done
    fi
  fi
  if [ -z "$payload" ]; then
    payload="<mastermind-brain>\nYou are running as MasterMind. The MasterMind kernel is your operating contract, and it is NOT loaded:\nno CLAUDE.md or AGENTS.md in this session holds it, and at $units characters it does not fit in this\nmessage, which is capped at $cap_words. Read $(esc "$KERNEL") in full before doing anything else, then follow it.\n$root$nudge\n</mastermind-brain>"
  fi
fi

# printf (not a heredoc): bash 5.3+ can hang on heredocs in hook contexts.
case "$SHAPE" in
  cursor) printf '{\n  "additional_context": "%s"\n}\n' "$payload" ;;
  claude|codex) printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": "%s"\n  }\n}\n' "$payload" ;;
  *)      printf '{\n  "additionalContext": "%s"\n}\n' "$payload" ;;
esac

exit 0
