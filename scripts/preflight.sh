#!/usr/bin/env bash
#
# preflight — the one gate that must pass before a release. Runs every check across the repo,
# the docs, the version strings, and the site, reports each, and exits non-zero if any fail.
# Run from anywhere in the repo:  ./scripts/preflight.sh
#
# Add a check here the moment you find something a release should never ship without — this
# file is meant to be the single answer to "did I test everything?".

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$PWD"
SITE="$REPO/../mastermind-site"

g=$'\033[0;32m'; r=$'\033[0;31m'; y=$'\033[0;33m'; x=$'\033[0m'
PASS=0; FAIL=0; LOG="$(mktemp)"

step() {
  local name="$1"; shift
  if "$@" >"$LOG" 2>&1; then
    printf '  %s✓%s %s\n' "$g" "$x" "$name"; PASS=$((PASS + 1))
  else
    printf '  %s✗%s %s\n' "$r" "$x" "$name"; sed 's/^/        /' "$LOG" | tail -6; FAIL=$((FAIL + 1))
  fi
}

shell_parses() { local f; for f in "$@"; do bash -n "$f" || return 1; done; }

versions_agree() {
  local want; want="$(cat "$REPO/VERSION")"
  local found
  found="$(grep -o 'version-[0-9.]*' "$REPO/README.md" | head -1 | cut -d- -f2)";      [ "$found" = "$want" ] || { echo "README badge $found ≠ $want"; return 1; }
  for f in "$REPO/.claude-plugin/plugin.json" "$REPO/.claude-plugin/marketplace.json" "$REPO/gemini-extension.json" "$REPO/.foglamp/scan.json"; do
    grep -q "\"$want\"" "$f" || { echo "$f missing $want"; return 1; }
  done
  for f in "$SITE/src/components/Footer.astro" "$SITE/src/pages/index.astro"; do
    [ -f "$f" ] && { grep -q "v$want" "$f" || { echo "$(basename "$f") ≠ v$want"; return 1; }; }
  done
  return 0
}

scan_is_fresh() {
  # Freshness = the working scan.json already matches what regeneration produces,
  # independent of commit state — this is a pre-release gate, run before you commit,
  # so it must not conflate "stale" with "not yet committed".
  local before; before="$(mktemp)"
  cp "$REPO/.foglamp/scan.json" "$before"
  node "$REPO/scripts/update-scan.mjs" >/dev/null 2>&1 || { rm -f "$before"; return 1; }
  diff -q "$before" "$REPO/.foglamp/scan.json" >/dev/null 2>&1 || { rm -f "$before"; echo "scan.json was stale — regenerated, commit it"; return 1; }
  rm -f "$before"
}

site_builds() {
  [ -d "$SITE" ] || { echo "../mastermind-site not checked out — skipping"; return 0; }
  ( cd "$SITE" && npm run build )
}

echo "Preflight — everything that must pass before release"
echo
echo "Code & tests"
step "installer regression suite"      bash "$REPO/tests/install.test.sh"
step "shell scripts parse"             shell_parses "$REPO/install.sh" "$REPO/hooks/session-start.sh" "$REPO/scripts/preflight.sh" "$REPO/tests/install.test.sh" "$REPO/skills/lab/assets/pre-push" "$REPO/skills/lab/assets/pre-commit" "$REPO/.githooks/pre-push" "$REPO/.githooks/pre-commit"

echo "Repo integrity"
step "router in sync"                  node "$REPO/scripts/build-router.mjs" --check
step "library pages in sync"           node "$REPO/scripts/build-library.mjs" --check
step "indexes/counts/references"       node "$REPO/scripts/check-integrity.mjs"
step "cited resources resolve"         node "$REPO/scripts/check-links.mjs"

echo "Release consistency"
step "version strings agree (repo + site)"   versions_agree
step "architecture map is fresh"             scan_is_fresh
step "site builds"                           site_builds

echo
rm -f "$LOG"
if [ "$FAIL" -eq 0 ]; then
  printf '%s✓ preflight: %d checks passed — releasable.%s\n' "$g" "$PASS" "$x"; exit 0
else
  printf '%s✗ preflight: %d failed, %d passed — not releasable.%s\n' "$r" "$FAIL" "$PASS" "$x"; exit 1
fi
