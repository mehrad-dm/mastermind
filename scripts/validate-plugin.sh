#!/usr/bin/env bash
# Runs Claude Code's own validator over the plugin manifests, with warnings as errors.
# Exit 2 when no claude binary here can do that; MM_REQUIRE_CLAUDE=1 turns that into a failure.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO" || exit 1

could_not_run() {
  printf 'could not run: %s\n' "$1"
  [ -n "${MM_REQUIRE_CLAUDE:-}" ] && exit 1
  exit 2
}

# Every candidate with its version, newest first; on a tie the one on PATH wins.
candidates="$(
  {
    command -v claude 2>/dev/null
    ls -d "$HOME"/.vscode/extensions/anthropic.claude-code-*/resources/native-binary/claude 2>/dev/null
  } | while IFS= read -r bin; do
    [ -x "$bin" ] || continue
    v="$("$bin" --version 2>/dev/null | sed -n 's/^\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | sed -n 1p)"
    [ -n "$v" ] && printf '%s %s\n' "$v" "$bin"
  done | sort -s -t. -k1,1nr -k2,2nr -k3,3nr
)"
[ -n "$candidates" ] || could_not_run "no claude binary on PATH or in the VS Code extension"

CLAUDE=""
while IFS= read -r line; do
  bin="${line#* }"
  help="$("$bin" plugin validate --help 2>&1 || true)"
  case "$help" in *--strict*) CLAUDE="$bin"; VERSION="${line%% *}"; break ;; esac
done <<<"$candidates"
[ -n "$CLAUDE" ] || could_not_run "no installed claude supports \`plugin validate --strict\`"

manifests=".claude-plugin/plugin.json"
[ -d mod ] && manifests="$manifests mod/.claude-plugin/plugin.json"

# The repo root is the plugin root, so the kernel file sits there by design: the session hook is
# what points a plugin session at it. Every other warning fails.
ACCEPTED='CLAUDE.md at the plugin root is not loaded|This folder also holds a marketplace manifest'
# The validator reads the folder on disk, so a stray system file fails it on a developer's machine
# though a clone would never hold it. That finding is accepted only while no such file is tracked.
OS_FILES='(^|/)(\.DS_Store|Thumbs\.db|desktop\.ini)$|(^|/)__MACOSX/'
tracked_os="$(git ls-files 2>/dev/null | grep -E "$OS_FILES" || true)"
[ -z "$tracked_os" ] && ACCEPTED="$ACCEPTED|ARCHIVE_OS_METADATA_FILE|System files: this command reads the folder on disk|Looked for macOS and Windows system files"

fail=0
for m in $manifests; do
  if [ ! -f "$m" ]; then printf '✖ %s is missing\n' "$m"; fail=1; continue; fi
  if out="$("$CLAUDE" plugin validate "$m" --strict 2>&1)"; then
    printf '✓ %s is valid (claude %s, --strict)\n' "$m" "$VERSION"
    continue
  fi
  loose=0; "$CLAUDE" plugin validate "$m" >/dev/null 2>&1 || loose=1
  left="$(grep '❯' <<<"$out" | grep -vE "$ACCEPTED" || true)"
  if [ "$loose" = 0 ] && [ -z "$left" ]; then
    printf '✓ %s is valid (claude %s, --strict; accepted: the kernel file at the plugin root)\n' "$m" "$VERSION"
  else
    printf '✖ %s fails validation (claude %s, --strict):\n' "$m" "$VERSION"
    grep -E '❯|✘|Validating' <<<"$out" | grep -vE "$ACCEPTED" | sed "s#$REPO/##; s/^/    /" | sed -n '1,24p'
    fail=1
  fi
done
exit "$fail"
