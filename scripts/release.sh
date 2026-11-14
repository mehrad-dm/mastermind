#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SITE="${MASTERMIND_SITE:-$REPO/../mastermind-site}"
export MASTERMIND_SITE="$SITE"
cd "$REPO"

g=$'\033[0;32m'; y=$'\033[0;33m'; r=$'\033[0;31m'; b=$'\033[1m'; x=$'\033[0m'
say()  { printf '  %s\n' "$*"; }
ok()   { printf '  %s✓%s %s\n' "$g" "$x" "$*"; }
warn() { printf '  %s⚠%s %s\n' "$y" "$x" "$*"; }
die()  { printf '%s✖ %s%s\n' "$r" "$*" "$x" >&2; exit 1; }

NEW="${1:-}"
DRY=0
RESUME=0
for flag in "${@:2}"; do
  case "$flag" in
    --dry-run) DRY=1 ;;
    --resume) RESUME=1 ;;
    *) die "unknown option $flag (expected --dry-run or --resume)" ;;
  esac
done

case "$NEW" in
  '' ) die "usage: scripts/release.sh <version> [--dry-run | --resume]   (current: $(cat VERSION))" ;;
  v* ) die "give the version without the leading v: ${NEW#v}" ;;
esac
if [[ ! "$NEW" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  die "'$NEW' is not a release version (expected: major.minor.patch)"
fi

# The committed version, so a resumed run still knows what it is moving from.
OLD="$(git show HEAD:VERSION 2>/dev/null || cat VERSION)"
[ "$NEW" = "$OLD" ] && die "already at $NEW"

# master takes pull requests only, so a release commit made here could never be pushed.
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = master ] &&
  die "you are on master, which only takes pull requests: git checkout -b release/v$NEW, then run this again"

printf '%s── releasing %s → %s%s%s\n' "$b" "$OLD" "$b" "$NEW" "$x"
[ "$DRY" = 1 ] && warn "dry run: nothing will be written"

[ -d "$SITE" ] || die "../mastermind-site is not checked out, so the site cannot be moved with the repo"
git -C "$SITE" rev-parse --git-dir >/dev/null 2>&1 || die "$SITE is not a git checkout, so its changes could not be reviewed or undone"
# Only the paths this script writes may be dirty on a resume; anything else is someone's work.
REPO_PATHS='^(VERSION|cli/package\.json|\.claude-plugin/plugin\.json|\.claude-plugin/marketplace\.json|README\.md|mod/\.claude-plugin/plugin\.json|architecture\.json)$'
SITE_PATHS='^(src|public)/'
dirty_repo="$(git status --porcelain | cut -c4-)"
dirty_site="$(git -C "$SITE" status --porcelain --untracked-files=no | cut -c4-)"
if [ "$RESUME" = 0 ]; then
  [ -z "$dirty_repo" ] || die "the working tree is dirty; commit the CHANGELOG section first (git add CHANGELOG.md && git commit), or pass --resume after a run that stopped"
  [ -z "$dirty_site" ] || die "the site working tree is dirty; commit or stash it first"
else
  stray="$(grep -vE "$REPO_PATHS" <<<"$dirty_repo" || true)"
  [ -z "$stray" ] || die "--resume found changes this script never makes, so it will not touch them: $(tr '\n' ' ' <<<"$stray")"
  stray="$(grep -vE "$SITE_PATHS" <<<"$dirty_site" || true)"
  [ -z "$stray" ] || die "--resume found site changes outside src/ and public/: $(tr '\n' ' ' <<<"$stray")"
  warn "resuming: the version edits already made are kept, the rest are made again"
fi
git rev-parse -q --verify "refs/tags/v$NEW" >/dev/null 2>&1 && die "tag v$NEW already exists"
grep -q "^## \[$NEW\]" CHANGELOG.md || die "CHANGELOG.md has no '## [$NEW]' section; write it first"

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
  if cmp -s "$tmp" "$file"; then
    rm -f "$tmp"
    if [ "$RESUME" = 1 ] && grep -F "$NEW" "$file" >/dev/null; then ok "$label (already $NEW)"; return 0; fi
    die "$label: nothing changed in $file, so the pattern no longer matches"
  fi
  cat "$tmp" > "$file"; rm -f "$tmp"
  ok "$label"
}

STARTED=0
# A run that stops after its first edit leaves both trees half moved: say how to finish or undo it.
recover() {
  local code=$?
  [ "$code" = 0 ] || [ "$STARTED" = 0 ] || [ "$DRY" = 1 ] || cat >&2 <<HOW

${b}The release stopped after it had started editing.${x} Fix the cause, then either:
   finish it    scripts/release.sh $NEW --resume
   or undo it   git checkout -- . && git -C "$SITE" checkout -- .
                git -C "$SITE" status --short    ${y}# a new library page is untracked: remove it by name${x}
HOW
}
trap recover EXIT
[ "$DRY" = 1 ] || STARTED=1

edit "VERSION"            "VERSION"                          "s/^$OLD\$/$NEW/"
edit "cli/package.json"   "cli/package.json"                 "s/\"version\": \"$OLD\"/\"version\": \"$NEW\"/"
edit "plugin manifest"    ".claude-plugin/plugin.json"       "s/$OLD/$NEW/g"
edit "marketplace"        ".claude-plugin/marketplace.json"  "s/$OLD/$NEW/g"
edit "README"             "README.md"                        "s/$OLD/$NEW/g"
# The Mod is a second plugin in the same marketplace and ships at the brain's version, whatever
# its manifest said before.
if [ -f mod/.claude-plugin/plugin.json ]; then
  node -e '
    const fs = require("fs")
    const [version, dry] = process.argv.slice(1)
    const modPath = "mod/.claude-plugin/plugin.json", listPath = ".claude-plugin/marketplace.json"
    const mod = JSON.parse(fs.readFileSync(modPath, "utf8"))
    const list = JSON.parse(fs.readFileSync(listPath, "utf8"))
    const entry = (list.plugins || []).find((p) => p.name === mod.name)
    if (!entry) { console.error(`the Mod (${mod.name}) has no entry in ${listPath}, so nobody could install it`); process.exit(1) }
    const save = (path, value) => { if (dry !== "1") fs.writeFileSync(path, JSON.stringify(value, null, 2) + "\n") }
    if (mod.version !== version) { mod.version = version; save(modPath, mod) }
    if (entry.version !== version) { entry.version = version; save(listPath, list) }
  ' "$NEW" "$DRY" || die "the Mod could not be moved to $NEW"
  if [ "$DRY" = 1 ]; then say "would set the Mod manifest and its marketplace entry to $NEW"
  else ok "Mod manifest and marketplace entry"; fi
fi
edit "site version"       "$SITE/src/site.config.ts"          "s/v$OLD/v$NEW/g"
edit "llms.txt"           "$SITE/public/llms.txt"             "s/Current release: v[0-9.]*/Current release: v$NEW/"
if [ "$DRY" = 0 ]; then
  MASTERMIND_SITE="$SITE" node "$REPO/scripts/build-library.mjs" >/dev/null || die "library pages could not be regenerated"
  ok "library pages (a release date starts each New badge's 60 days)"
  MASTERMIND_SITE="$SITE" node "$REPO/scripts/build-architecture.mjs" >/dev/null || die "the architecture data could not be regenerated"
  ok "architecture.json and the site's copy of it"
  # The committed generator, never a work-in-progress copy, draws the link card and the banners.
  GEN="$SITE/scripts/.release-social.mjs"
  git -C "$SITE" show HEAD:scripts/generate-social.mjs > "$GEN" || die "the site has no committed scripts/generate-social.mjs"
  ( cd "$SITE" && node "$GEN" >/dev/null ) || { rm -f "$GEN"; die "the link card and banners could not be regenerated"; }
  rm -f "$GEN"
  ok "link card and banners carry v$NEW"
fi

# --- Nothing left behind ------------------------------------------------------
if [ "$DRY" = 0 ]; then
  STALE="$(grep -rl "\b$OLD\b" \
    --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=evals --exclude-dir=dist \
    --exclude=CHANGELOG.md --exclude=journal.md \
    "$REPO"/{README.md,VERSION,cli,.claude-plugin,mod/.claude-plugin} "$SITE/src" "$SITE/public/llms.txt" 2>/dev/null || true)"
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
SUBJECT="$(awk -v v="[$NEW]" '
  index($0, "## " v) == 1 { f = 1; next }
  f && /^## \[/ { exit }
  f && /^- / { sub(/^- /, ""); gsub(/[*`]/, ""); print; exit }
' CHANGELOG.md | cut -c1-72)"
# The bug this replaced was an empty result substituted away in silence, so an
# empty one fails here rather than shipping a tag with no subject.
[ -n "$SUBJECT" ] || die "CHANGELOG.md [$NEW] has no leading '- ' bullet to take a tag subject from"
TAGMSG="v$NEW${SUBJECT:+: $SUBJECT}"
cat <<NEXT

${b}Not done automatically, because each one leaves this machine:${x}

   1. review the diff           git diff --stat HEAD && git -C "$SITE" diff --stat
   2. commit both repos         git add -A && git commit -m "release: v$NEW"
                                git -C "$SITE" add -A && git -C "$SITE" commit -m "v$NEW"
                                (-a stages tracked files only: an ADDED file would miss the release)
   3. open the pull request     git push -u origin "$BRANCH" && gh pr create --fill
                                PR="\$(gh pr view --json number --jq .number)"
   4. wait until it is MERGED   gh pr merge "\$PR" --squash --auto
                                gh pr checks "\$PR" --watch
                                while s="\$(gh pr view "\$PR" --json state --jq .state)" && [ "\$s" = OPEN ]; do sleep 15; done
                                gh pr view "\$PR" --json state,mergeCommit     ${y}# must say MERGED; CLOSED means stop here${x}
                                ${y}# auto-merge can lag the checks: nothing below runs before state is MERGED${x}
   5. take the merge commit     git fetch origin && git checkout master && git reset --hard origin/master
                                test "\$(git rev-parse HEAD)" = "\$(gh pr view "\$PR" --json mergeCommit --jq .mergeCommit.oid)"
   6. push the site's branch    git -C "$SITE" push -u origin HEAD     ${y}# a branch, not main: the live site does not change${x}
   7. rehearse the release      gh workflow run pre-tag.yml --ref master -f site-ref="\$(git -C "$SITE" rev-parse --abbrev-ref HEAD)"
                                sleep 5; gh run watch "\$(gh run list --workflow pre-tag.yml --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
                                ${y}# red: fix it through another pull request and start again at step 3${x}
   8. deploy the site           git -C "$SITE" push origin HEAD:main   ${y}# only after step 7 is green${x}
   9. tag the merge commit      git tag -a "v$NEW" -m "$TAGMSG" "\$(git rev-parse HEAD)"
  10. push the tag              git push origin "v$NEW"      ${y}# this publishes to npm and cannot be undone${x}
  11. verify all three agree    scripts/verify-release.sh $NEW

NEXT
