#!/usr/bin/env bash
set -uo pipefail
g=$'\033[0;32m'; y=$'\033[0;33m'; r=$'\033[0;31m'; x=$'\033[0m'
PATH="$HOME/.local/bin:$PATH"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fails=0; checked=0; skipped=0

WORK="$(cd "$(mktemp -d)" && pwd -P)"; trap 'rm -rf "$WORK"' EXIT
SANDBOX_HOME="$WORK/home"; mkdir -p "$SANDBOX_HOME"
REAL_BRAIN_BEFORE="$(readlink "$HOME/.mastermind" 2>/dev/null || echo none)"
proj="$WORK/probe"; mkdir -p "$proj"; cd "$proj" || exit 1
git init -q .
printf '{ "name": "probe", "dependencies": { "react": "^19.0.0" } }\n' > package.json
HOME="$SANDBOX_HOME" MM_NO_NETWORK=1 bash "$REPO/install.sh" claude cursor agents >/dev/null 2>&1 || { printf '%s✖ install failed in the probe project%s\n' "$r" "$x"; exit 1; }
for f in .claude/skills .cursor/rules/mastermind.mdc AGENTS.md; do
  [ -e "$f" ] || { printf '%s✖ probe project is missing %s: the check would be meaningless%s\n' "$r" "$f" "$x"; exit 1; }
done

ask='In one short line: are you running as MasterMind? If yes, name one skill you would reach for to debug a slow page.'

loaded() {
  local t head
  t="$(printf '%s' "$1" | tr 'A-Z' 'a-z')"
  # Only the first non-empty line answers the question: a bare "no" elsewhere is about something else.
  head="$(grep -m1 -v '^[[:space:]]*$' <<<"$t" || true)"
  grep -qE "not mastermind|not running as mastermind|isn'?t mastermind" <<<"$t" && return 1
  grep -qE "^[^a-z]*no\b" <<<"$head" && return 1
  grep -q "mastermind" <<<"$t" && grep -qE "\byes\b|i am mastermind|running as mastermind" <<<"$t"
}

report() {
  local tool="$1" out="$2"
  checked=$((checked + 1))
  if loaded "$out"; then
    printf '%s✓ %s%s: %s\n' "$g" "$tool" "$x" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-100)"
  else
    printf '%s✖ %s did not load the brain%s: %s\n' "$r" "$tool" "$x" "$out"; fails=$((fails + 1))
  fi
}
skip() { printf '%s• %s skipped%s: %s\n' "$y" "$1" "$x" "$2"; skipped=$((skipped + 1)); }

if command -v claude >/dev/null 2>&1; then
  out="$(claude -p "$ask" --setting-sources project,local 2>&1 | tail -3)"
  report "claude code" "$out"
else
  skip "claude code" "the claude CLI is not installed"
fi

# The Cursor CLI is `cursor-agent`, and since 2026.10 also `agent`: a name other tools use, so its help must say Cursor.
cursor_cli=""
for c in cursor-agent agent; do
  if command -v "$c" >/dev/null 2>&1 && help="$("$c" --help 2>&1)" && grep -qi cursor <<<"$help"; then cursor_cli="$c"; break; fi
done
if [ -n "$cursor_cli" ]; then
  out="$("$cursor_cli" -p --trust "$ask" --output-format text 2>&1 | tail -3)"
  report "cursor" "$out"
else
  skip "cursor" "no Cursor CLI (cursor-agent or agent) is installed"
fi

# MM_CODEX names the command when it is not `codex` on PATH, for example "npx -y @openai/codex".
read -r -a codex_cmd <<<"${MM_CODEX:-codex}"
if command -v "${codex_cmd[0]}" >/dev/null 2>&1; then
  # Codex 0.150 and later skips a project's AGENTS.md unless the project is trusted.
  out="$("${codex_cmd[@]}" exec --skip-git-repo-check --ephemeral -c "projects={ \"$proj\" = { trust_level = \"trusted\" } }" -C "$proj" "$ask" 2>&1 | tail -3)"
  report "codex" "$out"
else
  skip "codex" "the codex CLI is not installed (set MM_CODEX to the command)"
fi

after="$(readlink "$HOME/.mastermind" 2>/dev/null || echo none)"
if [ "$after" != "$REAL_BRAIN_BEFORE" ]; then
  printf '%s✖ this script moved your real ~/.mastermind (%s -> %s)%s\n' "$r" "$REAL_BRAIN_BEFORE" "$after" "$x"
  fails=$((fails + 1))
fi

if [ "$fails" -gt 0 ]; then
  printf '\n%s✖ %s check(s) failed.%s\n' "$r" "$fails" "$x"; exit 1
elif [ "$checked" -eq 0 ]; then
  printf '\n%s⚠ no tool is installed here, so nothing was checked.%s\n' "$y" "$x"; exit 2
fi
printf '\n%s✓ %s of 3 tools loaded the brain%s' "$g" "$checked" "$x"
[ "$skipped" -gt 0 ] && printf ' (%s not installed, not checked)' "$skipped"
printf '.\n'
