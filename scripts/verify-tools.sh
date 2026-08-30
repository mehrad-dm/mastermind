#!/usr/bin/env bash
set -uo pipefail
g=$'\033[0;32m'; y=$'\033[0;33m'; r=$'\033[0;31m'; x=$'\033[0m'
PATH="$HOME/.local/bin:$PATH"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fails=0

WORK="$(cd "$(mktemp -d)" && pwd -P)"; trap 'rm -rf "$WORK"' EXIT
SANDBOX_HOME="$WORK/home"; mkdir -p "$SANDBOX_HOME"
REAL_BRAIN_BEFORE="$(readlink "$HOME/.mastermind" 2>/dev/null || echo none)"
proj="$WORK/probe"; mkdir -p "$proj"; cd "$proj" || exit 1
git init -q .
printf '{ "name": "probe", "dependencies": { "react": "^19.0.0" } }\n' > package.json
HOME="$SANDBOX_HOME" bash "$REPO/install.sh" claude cursor agents >/dev/null 2>&1 || { printf '%s✖ install failed in the probe project%s\n' "$r" "$x"; exit 1; }
for f in .cursor/rules/mastermind.mdc AGENTS.md; do
  [ -e "$f" ] || { printf '%s✖ probe project is missing %s: the check would be meaningless%s\n' "$r" "$f" "$x"; exit 1; }
done

ask='In one short line: are you running as MasterMind? If yes, name one skill you would reach for to debug a slow page.'

loaded() {
  local t head
  t="$(printf '%s' "$1" | tr 'A-Z' 'a-z')"
  # Only the first non-empty line answers the question. A bare "no" anywhere else is the model talking
  # about something else, and it read a correct "Yes, MasterMind" as a failure the day one appeared.
  head="$(grep -m1 -v '^[[:space:]]*$' <<<"$t" || true)"
  grep -qE "not mastermind|not running as mastermind|isn'?t mastermind" <<<"$t" && return 1
  grep -qE "^[^a-z]*no\b" <<<"$head" && return 1
  grep -q "mastermind" <<<"$t" && grep -qE "\byes\b|i am mastermind|running as mastermind" <<<"$t"
}

if command -v cursor-agent >/dev/null 2>&1; then
  out="$(cursor-agent -p --trust "$ask" --output-format text 2>&1 | tail -3)"
  if loaded "$out"; then
    printf '%s✓ cursor%s: %s\n' "$g" "$x" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-100)"
  else
    printf '%s✖ cursor did not load the brain%s: %s\n' "$r" "$x" "$out"; fails=$((fails+1))
  fi
else
  printf '%s• cursor skipped%s: cursor-agent not installed\n' "$y" "$x"
fi

if command -v codex >/dev/null 2>&1; then
  out="$(codex exec --skip-git-repo-check "$ask" 2>&1 | tail -3)"
  if loaded "$out"; then
    printf '%s✓ codex%s: %s\n' "$g" "$x" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-100)"
  else
    printf '%s✖ codex did not load the brain%s: %s\n' "$r" "$x" "$out"; fails=$((fails+1))
  fi
else
  printf '%s• codex skipped%s: codex CLI not installed\n' "$y" "$x"
fi

after="$(readlink "$HOME/.mastermind" 2>/dev/null || echo none)"
if [ "$after" != "$REAL_BRAIN_BEFORE" ]; then
  printf '%s\u2716 this script moved your real ~/.mastermind (%s -> %s)%s\n' "$r" "$REAL_BRAIN_BEFORE" "$after" "$x"
  fails=$((fails+1))
fi

[ "$fails" -eq 0 ] && printf '\n%s✓ every installed tool loaded the brain.%s\n' "$g" "$x" \
                   || printf '\n%s✖ %s tool(s) did not load the brain.%s\n' "$r" "$fails" "$x"
exit "$fails"
