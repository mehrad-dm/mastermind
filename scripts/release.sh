#!/usr/bin/env bash
# Cut a release: move the version everywhere it lives, prove the gates, tag.
#
#   scripts/release.sh 0.31.0            # do it
#   scripts/release.sh 0.31.0 --dry-run  # show what would change, touch nothing
#
# The version lives in SIX places across TWO repositories. Every release that drifted did so
# because one of them was updated by hand and another was not, and "repo, npm and site are in
# sync" was a thing someone remembered rather than a thing something checked. This is that check.
#
# What it does NOT do: push, publish, or create the tag on the remote. Tagging is local; pushing
# the tag is what triggers the publish workflow, and that stays a separate, deliberate act.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SITE="$REPO/../mastermind-site"
cd "$REPO"

g=$'\033[0;32m'; y=$'\033[0;33m'; r=$'\033[0;31m'; b=$'\033[1m'; x=$'\033[0m'
say()  { printf '  %s\n' "$*"; }
ok()   { printf '  %s✓%s %s\n' "$g" "$x" "$*"; }
warn() { printf '  %s⚠%s %s\n' "$y" "$x" "$*"; }
die()  { printf '%s✖ %s%s\n' "$r" "$*" "$x" >&2; exit 1; }

NEW="${1:-}"
DRY=0
[ "${2:-}" = "--dry-run" ] && DRY=1

case "$NEW" in
  '' ) die "usage: scripts/release.sh <version> [--dry-run]   (current: $(cat VERSION))" ;;
  v* ) die "give the version without the leading v: ${NEW#v}" ;;
  [0-9]*.[0-9]*.[0-9]*) : ;;
  *  ) die "'$NEW' is not a semver version" ;;
esac

OLD="$(cat VERSION)"
[ "$NEW" = "$OLD" ] && die "already at $NEW"

printf '%s── releasing %s → %s%s%s\n' "$b" "$OLD" "$b" "$NEW" "$x"
[ "$DRY" = 1 ] && warn "dry run: nothing will be written"

# --- Preconditions ------------------------------------------------------------
# A release is a claim about a specific commit. An uncommitted tree means the tag will point at
# something other than what was tested, which is the moved-tag problem in a different costume.
[ -z "$(git status --porcelain)" ] || die "the working tree is dirty; commit or stash first"
[ -d "$SITE" ] || die "../mastermind-site is not checked out, so the site cannot be moved with the repo"
[ -z "$(git -C "$SITE" status --porcelain --untracked-files=no)" ] ||
  die "the site working tree is dirty; commit or stash it first"
git rev-parse -q --verify "refs/tags/v$NEW" >/dev/null 2>&1 && die "tag v$NEW already exists"
grep -q "^## \[$NEW\]" CHANGELOG.md || die "CHANGELOG.md has no '## [$NEW]' section; write it first"

# --- The six places -----------------------------------------------------------
# Each entry is: label | file | sed expression. Kept as data so the list is readable and so a
# seventh location is one line, not a new branch of logic.
edit() {
  local label="$1" file="$2" expr="$3"
  [ -f "$file" ] || die "$label: $file is missing"
  if [ "$DRY" = 1 ]; then
    local before after
    before="$(grep -c "$OLD" "$file" || true)"
    after="$(sed "$expr" "$file" | grep -c "$NEW" || true)"
    say "would update $label ($before → $after occurrences)"
    return 0
  fi
  local tmp; tmp="$(mktemp)"
  sed "$expr" "$file" > "$tmp"
  cmp -s "$tmp" "$file" && { rm -f "$tmp"; die "$label: nothing changed in $file — the pattern no longer matches"; }
  cat "$tmp" > "$file"; rm -f "$tmp"
  ok "$label"
}

edit "VERSION"            "VERSION"                          "s/^$OLD\$/$NEW/"
edit "cli/package.json"   "cli/package.json"                 "s/\"version\": \"$OLD\"/\"version\": \"$NEW\"/"
edit "plugin manifest"    ".claude-plugin/plugin.json"       "s/\"version\": \"$OLD\"/\"version\": \"$NEW\"/"
edit "marketplace"        ".claude-plugin/marketplace.json"  "s/\"$OLD\"/\"$NEW\"/"
edit "README badge"       "README.md"                        "s/version-$OLD/version-$NEW/"
edit "site footer"        "$SITE/src/components/Footer.astro" "s/v$OLD/v$NEW/"
edit "site homepage"      "$SITE/src/pages/index.astro"       "s/v$OLD/v$NEW/"

# --- Nothing left behind ------------------------------------------------------
if [ "$DRY" = 0 ]; then
  # A grep for the OLD version across the files that carry it. The changelog and the journal
  # keep history on purpose, so they are excluded; anything else still saying the old number is
  # a location this script does not know about, and it must be added above.
  STALE="$(grep -rl "\b$OLD\b" \
    --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=evals --exclude-dir=dist \
    --exclude=CHANGELOG.md --exclude=journal.md \
    "$REPO"/{README.md,VERSION,cli,.claude-plugin} "$SITE/src" 2>/dev/null || true)"
  if [ -n "$STALE" ]; then
    warn "these still mention $OLD; add them to this script if they are version locations:"
    printf '%s\n' "$STALE" | sed 's/^/      /'
  fi
fi

[ "$DRY" = 1 ] && { printf '\n%sdry run complete; nothing was written.%s\n' "$y" "$x"; exit 0; }

# --- Prove it -----------------------------------------------------------------
printf '\n%s── gates%s\n' "$b" "$x"
./scripts/preflight.sh || die "preflight failed; the release stops here"

# --- Tag ----------------------------------------------------------------------
SUBJECT="$(sed -n "/^## \[$NEW\]/,/^$/p" CHANGELOG.md | sed -n '3p' | cut -c1-72)"
printf '\n%s── tagging%s\n' "$b" "$x"
say "git add -A && git commit -m 'release: v$NEW'"
say "git tag -a v$NEW"
cat <<NEXT

${b}Not done automatically, because each one leaves this machine:${x}

  1. review the diff          git diff --stat HEAD
  2. commit both repos        git commit -am "release: v$NEW"
                              git -C "$SITE" commit -am "v$NEW"
  3. tag                      git tag -a "v$NEW" -m "v$NEW${SUBJECT:+ — $SUBJECT}"
  4. push the code            git push
  5. push the tag             git push origin "v$NEW"     ${y}# this publishes to npm${x}
  6. deploy the site          git -C "$SITE" push
  7. verify all three agree   scripts/verify-release.sh $NEW

NEXT
