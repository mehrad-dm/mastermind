#!/usr/bin/env bash
# What the mod is allowed to do, checked against what Claude Code reads from its source.
# usage: validate.sh [mod-dir]     CLAUDE_BIN=<claude 2.1.287 or newer> overrides the binary.
set -uo pipefail

MOD="$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")/..}" && pwd -P)"
REPO="$(cd "$MOD/.." && pwd -P)"
FAILS=0
ok() { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; FAILS=$((FAILS + 1)); }

BIN="${CLAUDE_BIN:-}"
if [ -z "$BIN" ]; then
  for candidate in "$HOME"/.vscode/extensions/anthropic.claude-code-*/resources/native-binary/claude; do
    [ -x "$candidate" ] && BIN="$candidate"
  done
fi
[ -n "$BIN" ] || BIN="$(command -v claude || true)"
# Exit 2 is "not checked"; MM_REQUIRE_CLAUDE=1 (CI) makes it a failure.
not_checked() { echo "NOT CHECKED: $1"; [ -n "${MM_REQUIRE_CLAUDE:-}" ] && exit 1; exit 2; }
[ -n "$BIN" ] || not_checked "no claude binary found. Set CLAUDE_BIN to Claude Code 2.1.287 or newer."
VERSION_LINE="$("$BIN" --version 2>/dev/null || true)"
IFS=. read -r MAJ MIN PAT <<<"$(printf '%s' "$VERSION_LINE" | sed -n 's/^\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')"
if [ -z "${PAT:-}" ] || [ $((MAJ * 1000000 + MIN * 1000 + PAT)) -lt 2001287 ]; then
  not_checked "$BIN is '$VERSION_LINE', which does not read hooks modules. Set CLAUDE_BIN to 2.1.287 or newer."
fi
echo "validating $MOD with $VERSION_LINE"

OUT="$(mktemp)"
trap 'rm -f "$OUT"' EXIT
"$BIN" plugin validate "$MOD/.claude-plugin/plugin.json" --strict > "$OUT" 2>&1
STATUS=$?
[ "$STATUS" -eq 0 ] && ok "plugin validate --strict passes" || bad "plugin validate --strict exited $STATUS"

HOOKS="$(grep -F 'mod.mjs hooks:' "$OUT" || true)"
CALLS="$(grep -F 'mod.mjs calls:' "$OUT" || true)"
ENVW="$(grep -F 'mod.mjs env writes:' "$OUT" || true)"
printf '%s\n%s\n%s\n' "$HOOKS" "$CALLS" "$ENVW"
[ -n "$HOOKS" ] && ok "the validator reports the hooks line" || bad "no hooks: line in the validator output"
[ -n "$CALLS" ] && ok "the validator reports the calls line" || bad "no calls: line in the validator output"

for banned in '$.http' '$.fs.write' '$.model.' '$.prompt.submit' '$.env.set' '$.session.append' '$.tool.call' '$.agent.spawn' '$.store.'; do
  case "$CALLS" in
    *"$banned"*) bad "calls: names $banned" ;;
    *) ok "calls: has no $banned" ;;
  esac
done
case "$ENVW" in
  *"env writes: nothing"*) ok "the mod writes no environment variable" ;;
  *) bad "env writes is not 'nothing': $ENVW" ;;
esac
for needed in 'tool.check{tool=Bash}' 'tool.check{tool=Edit|Write|MultiEdit|NotebookEdit}' 'command.run{command=mm-status|mm-wrong-log|mm-next|mm-check|mm-evidence}' 'ui.render{component=AbovePrompt}'; do
  case "$HOOKS" in
    *"$needed"*) ok "hooks: has $needed" ;;
    *) bad "hooks: lacks $needed" ;;
  esac
done
for unwanted in 'prompt.submit' 'prompt.compose' 'prompt.section' 'classic.' 'engine.create' 'turn.step' 'settings.read'; do
  case "$HOOKS" in
    *"$unwanted"*) bad "hooks: names $unwanted" ;;
    *) ok "hooks: has no $unwanted" ;;
  esac
done
if grep -F 'gating hook with .catch: tool.check{tool=Bash}' "$OUT" > /dev/null; then ok "the Bash hold has a .catch"; else bad "the Bash hold has no .catch"; fi

if grep -n "'allow'" "$MOD"/hooks/*.mjs > /dev/null; then bad "a hooks file spells the verdict 'allow'"; else ok "no hooks file spells the verdict 'allow'"; fi
if grep -n -E 'import\(|require\(|node:|process\.env|setTimeout|fetch\(' "$MOD"/hooks/*.mjs > /dev/null; then bad "a hooks file reaches for Node, a timer or the network"; else ok "no Node API, timer or network call in the hooks files"; fi

FLAT="$(tr -s ' \n' '  ' < "$MOD/hooks/hooks.json")"
case "$FLAT" in
  *'"hooks": {}'*) ok "hooks.json ships no settings hook" ;;
  *) bad "hooks.json carries a settings hook: the mod must not run one" ;;
esac
[ ! -e "$MOD/hooks/session-start.sh" ] && ok "no session hook script in the mod" || bad "the mod ships a session hook script"

WANT="$(cat "$REPO/VERSION" 2>/dev/null || true)"
GOT="$(sed -n 's/^  "version": "\([^"]*\)".*/\1/p' "$MOD/.claude-plugin/plugin.json")"
[ -n "$WANT" ] && [ "$GOT" = "$WANT" ] && ok "manifest version $GOT equals VERSION" || bad "manifest version '$GOT' is not VERSION '$WANT'"
MARKET="$(tr -s ' \n' '  ' < "$REPO/.claude-plugin/marketplace.json" 2>/dev/null || true)"
case "$MARKET" in
  *'"name": "mastermind-mod", "source": "./mod"'*) ok "the marketplace lists mastermind-mod from ./mod" ;;
  *) bad "the marketplace does not list mastermind-mod with source ./mod" ;;
esac

KERNEL="$(cat "$REPO/CLAUDE.md" "$REPO/engineering/core/rigor.md" 2>/dev/null | tr -s ' \n' '  ' | tr 'A-Z' 'a-z')"
for words in 'approval once is not approval again' 'push, publish' 'deleting or overwriting what you did not create' 'outside the project'; do
  case "$KERNEL" in
    *"$words"*) ok "the kernel says \"$words\"" ;;
    *) bad "the hold quotes \"$words\", which the kernel and rigor.md no longer say" ;;
  esac
  if grep -i -F "$words" "$MOD/hooks/irreversible.mjs" > /dev/null; then ok "the hold says \"$words\""; else bad "the hold no longer says \"$words\""; fi
done
if grep -E '^#[[:space:]]*MasterMind:' "$REPO/CLAUDE.md" > /dev/null; then ok "the kernel opens with the heading the mod looks for"; else bad "CLAUDE.md has no '# MasterMind:' heading: kernel presence would always read as not loaded"; fi
[ -f "$REPO/skills/handoff/SKILL.md" ] && ok "the handoff skill the hint names exists" || bad "skills/handoff/SKILL.md is missing"
[ -f "$REPO/agents/code-reviewer.md" ] && ok "the code-reviewer agent the fork notice names exists" || bad "agents/code-reviewer.md is missing"
for sub in next wrong-log; do
  if grep -E "READ_CMDS = .*'$sub'" "$REPO/cli/bin/mastermind.mjs" > /dev/null; then ok "the CLI has the read-only command '$sub'"; else bad "the CLI has no read-only command '$sub'"; fi
done

echo
if [ "$FAILS" -eq 0 ]; then echo "mod contract holds"; else echo "$FAILS check(s) failed"; exit 1; fi
