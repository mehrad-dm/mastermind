#!/usr/bin/env bash
# Does a REAL agent session in each supported tool actually load the brain?
#
# Everything else we ship is verified by tests that never start an agent: they check that files
# land in the right place with the right contents. That is not the same claim. This script asks
# the tool itself, in a throwaway project, and fails if the answer does not come back as
# MasterMind. Cursor's hooks.json in particular is a schema we write and had never confirmed
# anything reads.
#
# Needs the tool's own CLI and a logged-in account, so it is a local command, not CI:
# Claude Code is deliberately absent: it is covered far better by evals/auto-invoke.mjs, which
# runs real sessions against the whole routing matrix — and a nested `claude -p` inside a Claude
# Code session hangs, which would make this script useless rather than informative.
#   cursor-agent  — curl https://cursor.com/install | bash   (installs under ~/.local)
#   codex         — npm i -g @openai/codex  (or: brew install codex)
# Skips, loudly, whatever is missing. Usage: scripts/verify-tools.sh
set -uo pipefail
g=$'\033[0;32m'; y=$'\033[0;33m'; r=$'\033[0;31m'; x=$'\033[0m'
PATH="$HOME/.local/bin:$PATH"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fails=0

WORK="$(cd "$(mktemp -d)" && pwd -P)"; trap 'rm -rf "$WORK"' EXIT
# The installer always writes $HOME/.mastermind. Run with the real HOME and it repoints the
# developer's own brain at this throwaway directory, which is then deleted on exit. It did
# exactly that during an audit. The same lesson is already in the wrong-log from the test
# suite; this script repeated it, so the sandbox is not optional here either.
SANDBOX_HOME="$WORK/home"; mkdir -p "$SANDBOX_HOME"
REAL_BRAIN_BEFORE="$(readlink "$HOME/.mastermind" 2>/dev/null || echo none)"
proj="$WORK/probe"; mkdir -p "$proj"; cd "$proj" || exit 1
git init -q .
printf '{ "name": "probe", "dependencies": { "react": "^19.0.0" } }\n' > package.json
# `agents` wires AGENTS.md, which is the ONLY thing Codex reads — naming tools explicitly
# without it made the first version of this script probe a project Codex could not see.
HOME="$SANDBOX_HOME" bash "$REPO/install.sh" claude cursor agents >/dev/null 2>&1 || { printf '%s✖ install failed in the probe project%s\n' "$r" "$x"; exit 1; }
for f in .cursor/rules/mastermind.mdc AGENTS.md; do
  [ -e "$f" ] || { printf '%s✖ probe project is missing %s — the check would be meaningless%s\n' "$r" "$f" "$x"; exit 1; }
done

ask='In one short line: are you running as MasterMind? If yes, name one skill you would reach for to debug a slow page.'

# Grepping for "mastermind" is NOT enough: "I am running as Codex, not MasterMind" contains it,
# and this script reported that as a pass. Demand an affirmative and reject any denial.
# grep reads from a HERE-STRING, never from `printf | grep -q`. With pipefail set, grep -q
# exits on its first match, printf takes SIGPIPE, and the pipeline reports failure BECAUSE the
# pattern matched. On a short reply printf finishes first and it works; past the pipe buffer it
# silently inverts. A verifier that flips its own answer on long input is worse than none.
loaded() {
  local t; t="$(printf '%s' "$1" | tr 'A-Z' 'a-z')"
  grep -qE "not mastermind|not running as mastermind|isn'?t mastermind|^[^a-z]*no\b" <<<"$t" && return 1
  grep -q "mastermind" <<<"$t" && grep -qE "\byes\b|i am mastermind|running as mastermind" <<<"$t"
}

if command -v cursor-agent >/dev/null 2>&1; then
  out="$(cursor-agent -p --trust "$ask" --output-format text 2>&1 | tail -3)"
  if loaded "$out"; then
    printf '%s✓ cursor%s — %s\n' "$g" "$x" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-100)"
  else
    printf '%s✖ cursor did not load the brain%s — %s\n' "$r" "$x" "$out"; fails=$((fails+1))
  fi
else
  printf '%s• cursor skipped%s — cursor-agent not installed\n' "$y" "$x"
fi

if command -v codex >/dev/null 2>&1; then
  out="$(codex exec --skip-git-repo-check "$ask" 2>&1 | tail -3)"
  if loaded "$out"; then
    printf '%s✓ codex%s — %s\n' "$g" "$x" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-100)"
  else
    printf '%s✖ codex did not load the brain%s — %s\n' "$r" "$x" "$out"; fails=$((fails+1))
  fi
else
  printf '%s• codex skipped%s — codex CLI not installed\n' "$y" "$x"
fi

after="$(readlink "$HOME/.mastermind" 2>/dev/null || echo none)"
if [ "$after" != "$REAL_BRAIN_BEFORE" ]; then
  printf '%s\u2716 this script moved your real ~/.mastermind (%s -> %s)%s\n' "$r" "$REAL_BRAIN_BEFORE" "$after" "$x"
  fails=$((fails+1))
fi

[ "$fails" -eq 0 ] && printf '\n%s✓ every installed tool loaded the brain.%s\n' "$g" "$x" \
                   || printf '\n%s✖ %s tool(s) did not load the brain.%s\n' "$r" "$fails" "$x"
exit "$fails"
