#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
REPO="$PWD"
SITE="$REPO/../mastermind-site"

g=$'\033[0;32m'; r=$'\033[0;31m'; y=$'\033[0;33m'; x=$'\033[0m'
PASS=0; SKIPPED=0; FAIL=0; LOG="$(mktemp)"

step() {
  local name="$1"; shift
  if "$@" >"$LOG" 2>&1; then
    printf '  %s✓%s %s\n' "$g" "$x" "$name"; PASS=$((PASS + 1))
  else
    printf '  %s✗%s %s\n' "$r" "$x" "$name"; sed 's/^/        /' "$LOG" | tail -6; FAIL=$((FAIL + 1))
  fi
}

shell_parses() { local f; for f in "$@"; do bash -n "$f" || return 1; done; }

release_rejects_bad_versions() {
  local out
  out="$(bash "$REPO/scripts/release.sh" '1x.2y.3z' --dry-run 2>&1)" && return 1
  case "$out" in *"not a release version"*) return 0 ;; *) printf '%s\n' "$out"; return 1 ;; esac
}

step_live() {
  local name="$1"; shift
  "$@" >"$LOG" 2>&1
  case $? in
    0) printf '  %s✓%s %s\n' "$g" "$x" "$name"; PASS=$((PASS + 1)) ;;
    2) printf '  %s⚠%s %s: the environment could not run it (not a regression)\n' "$y" "$x" "$name"
       sed 's/^/        /' "$LOG" | tail -2; SKIPPED=$((SKIPPED + 1)) ;;
    *) printf '  %s✗%s %s\n' "$r" "$x" "$name"; sed 's/^/        /' "$LOG" | tail -6; FAIL=$((FAIL + 1)) ;;
  esac
}

versions_agree() {
  local want; want="$(cat "$REPO/VERSION")"
  local found
  found="$(grep -o 'version-[0-9.]*' "$REPO/README.md" | head -1 | cut -d- -f2)";      [ "$found" = "$want" ] || { echo "README badge $found ≠ $want"; return 1; }
  for f in "$REPO/.claude-plugin/plugin.json" "$REPO/.claude-plugin/marketplace.json" "$REPO/cli/package.json"; do
    grep -q "\"$want\"" "$f" || { echo "$f missing $want"; return 1; }
  done
  site_available || return $?
  for f in "$SITE/src/components/Footer.astro" "$SITE/src/pages/index.astro"; do
    [ -f "$f" ] || { echo "$(basename "$f") not found: the site cannot be checked"; return 1; }
    grep -q "v$want" "$f" || { echo "$(basename "$f") ≠ v$want"; return 1; }
  done
  return 0
}

scan_is_fresh() {
  local before; before="$(mktemp)"
  cp "$REPO/.foglamp/scan.json" "$before"
  node "$REPO/scripts/update-scan.mjs" >/dev/null 2>&1 || { rm -f "$before"; return 1; }
  diff -q "$before" "$REPO/.foglamp/scan.json" >/dev/null 2>&1 || { rm -f "$before"; echo "scan.json was stale: regenerated, commit it"; return 1; }
  rm -f "$before"
}

site_available() {
  [ -d "$SITE" ] && return 0
  if [ -n "${MM_SKIP_SITE:-}" ]; then
    echo "MM_SKIP_SITE set: the site is NOT verified for this release"
    return 0
  fi
  echo "../mastermind-site is not checked out, so the site cannot be verified."
  echo "  clone it beside this repo, or set MM_SKIP_SITE=1 to ship without it on the record."
  return 1
}

site_builds() {
  site_available || return $?
  ( cd "$SITE" && npm run build )
}

echo "Preflight: everything that must pass before release"
echo
echo "Code & tests"
step "installer regression suite"      bash "$REPO/tests/install.test.sh"
step "agent-callable surface"          bash "$REPO/tests/agent-surface.test.sh"
step "skill routing accuracy"          node "$REPO/evals/agent-surface-routing.mjs"
step_live "skills auto-invoke (live)"  node "$REPO/evals/auto-invoke.mjs"
step "shell scripts parse"             shell_parses "$REPO/scripts/release.sh" "$REPO/scripts/verify-release.sh" "$REPO/scripts/prove-regression.sh" "$REPO/install.sh" "$REPO/hooks/session-start.sh" "$REPO/scripts/preflight.sh" "$REPO/tests/install.test.sh" "$REPO/tests/agent-surface.test.sh" "$REPO/bin/mastermind" "$REPO/skills/quarantine/assets/pre-push" "$REPO/skills/quarantine/assets/pre-commit" "$REPO/.githooks/pre-push" "$REPO/.githooks/pre-commit"
step "release version grammar"         release_rejects_bad_versions

echo "Repo integrity"
step "router in sync"                  node "$REPO/scripts/build-router.mjs" --check
step_live "library pages in sync"      node "$REPO/scripts/build-library.mjs" --check
step "indexes/counts/references"       node "$REPO/scripts/check-integrity.mjs"
step "cited resources resolve"         node "$REPO/scripts/check-links.mjs"
step "brain has no structural drift"   node "$REPO/scripts/lint-brain.mjs" --strict
step_live "no em dashes (repo + site)" node "$REPO/scripts/check-prose.mjs"
step      "comments stay rare and short" node "$REPO/scripts/check-comments.mjs"
step      "no early-exit pipe under pipefail" node "$REPO/scripts/check-shell-patterns.mjs"

echo "Release consistency"
step "version strings agree (repo + site)"   versions_agree
step "architecture map is fresh"             scan_is_fresh
# Same gate as the other two site checks, so a missing site cannot make one of the three pass.
site_numbers() { site_available || return $?; node "$REPO/scripts/sync-evals.mjs" --check; }
step "site numbers match the results file" site_numbers
step "site builds"                           site_builds

echo
rm -f "$LOG"
if [ "$FAIL" -eq 0 ]; then
  if [ "${SKIPPED:-0}" -gt 0 ]; then
    printf '%s✓ preflight: %d checks passed, %d could not run here, releasable.%s\n' "$g" "$PASS" "$SKIPPED" "$x"
  else
    printf '%s✓ preflight: %d checks passed, releasable.%s\n' "$g" "$PASS" "$x"
  fi
  exit 0
else
  printf '%s✗ preflight: %d failed, %d passed, not releasable.%s\n' "$r" "$FAIL" "$PASS" "$x"; exit 1
fi
