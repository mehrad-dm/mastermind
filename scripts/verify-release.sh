#!/usr/bin/env bash
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SITE_URL="https://mastermind.mehrad.me"
PKG="mastermind-brain"
cd "$REPO" || exit 1

g=$'\033[0;32m'; y=$'\033[0;33m'; r=$'\033[0;31m'; b=$'\033[1m'; x=$'\033[0m'
FAIL=0; SKIP=0
ok()   { printf '  %s✓%s %s\n' "$g" "$x" "$*"; }
bad()  { printf '  %s✖%s %s\n' "$r" "$x" "$*"; FAIL=$((FAIL + 1)); }
skip() { printf '  %s⚠%s %s\n' "$y" "$x" "$*"; SKIP=$((SKIP + 1)); }

V="${1:-$(cat VERSION)}"
V="${V#v}"
printf '%s── v%s: repository · npm · website%s\n\n' "$b" "$V" "$x"

# --- The repository -----------------------------------------------------------
if git rev-parse -q --verify "refs/tags/v$V" >/dev/null 2>&1; then
  TAG_SHA="$(git rev-list -n1 "v$V")"
  ok "tag v$V → ${TAG_SHA:0:12}"
else
  bad "no tag v$V in this clone"; TAG_SHA=""
fi

if grep -q "^## \[$V\]" CHANGELOG.md; then ok "CHANGELOG has an entry for $V"
else bad "CHANGELOG has no '## [$V]' section"; fi

for f in cli/package.json .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  if grep -q "\"$V\"" "$f"; then ok "$f says $V"; else bad "$f does not say $V"; fi
done
if grep -q "version-$V" README.md; then ok "README badge says $V"; else bad "README badge is not $V"; fi

# --- npm ----------------------------------------------------------------------
printf '\n'
NPM_JSON="$(curl -fsS "https://registry.npmjs.org/$PKG/latest" 2>/dev/null)"
if [ -z "$NPM_JSON" ]; then
  skip "the npm registry did not answer"
else
  NPM_V="$(printf '%s' "$NPM_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).version||"")}catch{console.log("")}})')"
  NPM_C="$(printf '%s' "$NPM_JSON" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const p=JSON.parse(s);console.log(p.commit||p.gitHead||"")}catch{console.log("")}})')"
  if [ "$NPM_V" = "$V" ]; then ok "npm latest is $NPM_V"
  else bad "npm latest is $NPM_V, not $V"; fi

  if [ -z "$NPM_C" ]; then
    bad "the published package carries no commit stamp"
  elif [ -z "$TAG_SHA" ]; then
    skip "cannot compare the commit stamp without the tag"
  elif [ "$NPM_C" = "$TAG_SHA" ]; then
    ok "the published package is stamped with ${NPM_C:0:12}, which is what v$V points at"
  else
    bad "the package is stamped ${NPM_C:0:12} but v$V points at ${TAG_SHA:0:12}"
  fi
fi

# --- The website --------------------------------------------------------------
printf '\n'
HTML="$(curl -fsS "$SITE_URL/" 2>/dev/null)"
if [ -z "$HTML" ]; then
  skip "$SITE_URL did not answer"
else
  SEEN="$(printf '%s' "$HTML" | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | sort -u | tr '\n' ' ')"
  case "$HTML" in
    *"v$V"*) ok "the site shows v$V" ;;
    *)       bad "the site does not show v$V (it contains: ${SEEN:-no version at all})" ;;
  esac
  CSP="$(curl -fsSI "$SITE_URL/architecture" 2>/dev/null | tr -d '\r' | grep -i '^content-security-policy:' || true)"
  if [ -z "$CSP" ]; then skip "no CSP header served for /architecture"
  elif case "$CSP" in *"frame-src https://www.foglamp.dev"*) true ;; *) false ;; esac; then ok "the CSP allows the canonical embedded-map origin"
  else bad "the CSP does not allow https://www.foglamp.dev, so the embedded map is blocked"; fi
fi

# --- What the Claude Code marketplace serves ----------------------------------
# It reads these two files straight off master, so pushing master IS the marketplace release.
printf '\n'
RAW="https://raw.githubusercontent.com/mehrad-dm/mastermind/master"
for f in .claude-plugin/marketplace.json .claude-plugin/plugin.json; do
  BODY="$(curl -fsSL "$RAW/$f" 2>/dev/null || true)"
  if [ -z "$BODY" ]; then skip "could not read $f from master"; continue; fi
  case "$BODY" in
    *"\"$V\""*) ok "the marketplace serves $V in $(basename "$f")" ;;
    *)          bad "$(basename "$f") on master does not say $V" ;;
  esac
done

# --- The Release object -------------------------------------------------------
printf '\n'
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  if gh release view "v$V" >/dev/null 2>&1; then ok "a GitHub Release exists for v$V"
  else bad "there is no GitHub Release for v$V (the tag alone is not a release)"; fi
  # Protection that lapses silently is protection nobody notices losing.
  RULES="$(gh api repos/mehrad-dm/mastermind/rulesets 2>/dev/null || true)"
  case "$RULES" in
    *'"target":"tag"'*) ok "release tags are protected by a ruleset" ;;
    *)                  bad "no tag ruleset is active, so v* tags can be moved or deleted" ;;
  esac
else
  skip "gh is not authenticated, so the Release object was not checked"
fi

# --- Verdict ------------------------------------------------------------------
printf '\n'
if [ "$FAIL" -gt 0 ]; then
  printf '%s✖ v%s is NOT consistent: %d problem(s)%s\n' "$r" "$V" "$FAIL" "$x"
  exit 1
fi
if [ "$SKIP" -gt 0 ]; then
  printf '%s✓ everything checked agrees on v%s, but %d check(s) could not run.%s\n' "$y" "$V" "$SKIP" "$x"
  exit 0
fi
printf '%s✓ repository, npm and website all agree on v%s.%s\n' "$g" "$V" "$x"
