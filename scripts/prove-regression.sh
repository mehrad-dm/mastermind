#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$REPO"

g=$'\033[0;32m'; y=$'\033[0;33m'; r=$'\033[0;31m'; b=$'\033[1m'; x=$'\033[0m'

TAG="${1:-}"
FILTER="${2:-}"

if [ -z "$TAG" ]; then
  printf 'usage: %s <git-tag> [assertion-filter]\n\n' "$0" >&2
  printf 'recent tags:\n' >&2
  git tag --list 'v*' --sort=-v:refname | head -8 | sed 's/^/  /' >&2
  exit 2
fi

git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1 || {
  printf '%s✖ no such tag: %s%s\n' "$r" "$TAG" "$x" >&2; exit 2; }

# Refuse to run on a dirty install.sh: the restore below would overwrite uncommitted work.
if ! git diff --quiet -- install.sh 2>/dev/null; then
  STASHED=1
else
  STASHED=0
fi

BACKUP="$(mktemp)"
cp install.sh "$BACKUP"
# Restore on ANY exit, including a failing test run, a signal, or a syntax error in the old file.
restore() { cp "$BACKUP" "$REPO/install.sh"; rm -f "$BACKUP"; }
trap restore EXIT INT TERM

printf '%s── proving the suite against %s%s\n' "$b" "$TAG" "$x"
[ "$STASHED" = 1 ] && printf '  %s(install.sh has uncommitted changes; they are restored when this finishes)%s\n' "$y" "$x"

git show "$TAG:install.sh" > install.sh

OUT="$(mktemp)"
set +e
bash tests/install.test.sh > "$OUT" 2>&1
set -e

restore; trap - EXIT INT TERM

# A test name is what the reader recognises, so report by name rather than by count alone.
FAILED="$(grep -c '✖' "$OUT" || true)"
PASSED="$(grep -c '✓' "$OUT" || true)"

printf '\n%sassertions that FAIL against %s%s  (each one is a defect this suite now catches)\n' "$b" "$TAG" "$x"
if [ -n "$FILTER" ]; then
  grep '✖' "$OUT" | grep -i -- "$FILTER" | sed "s/^/  /" || printf '  %snone matching "%s"%s\n' "$y" "$FILTER" "$x"
else
  grep '✖' "$OUT" | sed 's/^/  /' || printf '  %snone%s\n' "$y" "$x"
fi

printf '\n  %s%s failing%s · %s passing\n' "$r" "$FAILED" "$x" "$PASSED"
rm -f "$OUT"

if [ "$FAILED" -eq 0 ]; then
  printf '\n%s⚠ nothing failed.%s Either %s already had every fix, or the assertions added since\n' "$y" "$x" "$TAG"
  printf '  then cannot detect what it shipped. Check which, before trusting the green.\n'
  exit 1
fi

printf '\n%s✓ the suite detects %s defects in %s.%s\n' "$g" "$FAILED" "$TAG" "$x"
