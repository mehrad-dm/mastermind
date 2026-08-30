#!/usr/bin/env bash

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="${MM_INSTALL_UNDER_TEST:-$REPO/install.sh}"
TMP="$(mktemp -d)"
TMP_REAL="$(cd "$TMP" && pwd -P)"

PASS=0; FAIL=0
g=$'\033[0;32m'; r=$'\033[0;31m'; x=$'\033[0m'
ok()   { printf '  %s✓%s %s\n' "$g" "$x" "$1"; PASS=$((PASS+1)); }
no()   { printf '  %s✖%s %s\n' "$r" "$x" "$1"; FAIL=$((FAIL+1)); }
is()   { if [ "$2" = "$3" ]; then ok "$1"; else no "$1 (got '$2', want '$3')"; fi; }
yes_() { if [ -n "$2" ]; then ok "$1"; else no "$1"; fi; }

proj() { local d="$TMP/$1"; rm -rf "$d"; mkdir -p "$d"; printf '%s' "$d"; }

SANDBOX_HOME="$TMP/home"; mkdir -p "$SANDBOX_HOME"
REAL_HOME_LINK="$(readlink "$HOME/.mastermind" 2>/dev/null || echo none)"
trap 'now="$(readlink "$HOME/.mastermind" 2>/dev/null || echo none)"
      if [ "$now" != "$REAL_HOME_LINK" ]; then
        printf "\n\033[0;31m✖ a test modified the real ~/.mastermind (%s → %s): restoring\033[0m\n" "$REAL_HOME_LINK" "$now" >&2
        [ "$REAL_HOME_LINK" = none ] || ln -sfn "$REAL_HOME_LINK" "$HOME/.mastermind"
      fi
      rm -rf "$TMP"' EXIT
CANARY="$TMP_REAL/canary"; mkdir -p "$CANARY"; CANARY_LOG="$TMP_REAL/canary.log"
canary_check() {
  local found; found="$(find "$CANARY" -mindepth 1 2>/dev/null | head -3 | tr '\n' ' ')"
  [ -z "$found" ] && return 0
  printf '%s\n' "$found" >> "$CANARY_LOG"
  rm -rf "${CANARY:?}"/* 2>/dev/null || true
}
count_in() { [ -f "$1" ] || { printf '0'; return; }; grep -c "$2" "$1" 2>/dev/null | head -1; }
run()  { local rc; (cd "$1" && shift && HOME="$SANDBOX_HOME" "$INSTALL" "$@" 2>&1); rc=$?; canary_check; return $rc; }

N_SKILLS="$(ls -d "$REPO"/skills/*/ | wc -l | tr -d ' ')"
N_AGENTS="$(ls "$REPO"/agents/*.md | wc -l | tr -d ' ')"

echo "── syntax"
bash -n "$INSTALL" && ok "install.sh parses" || no "install.sh parses"
bash -n "$REPO/hooks/session-start.sh" && ok "session-start.sh parses" || no "session-start.sh parses"

echo "── contradictory storage modes refuse before writing"
P=$(proj contradictory)
out=$(run "$P" --isolated --shared claude 2>&1); rc=$?
is "opposite modes exit 2" "$rc" "2"
is "opposite modes explain the conflict" "$(printf '%s' "$out" | grep -c 'opposite modes')" "1"
is "opposite modes create nothing" "$([ -z "$(ls -A "$P")" ] && echo yes || echo no)" "yes"

echo "── clean install"
P=$(proj clean); OUT=$(run "$P" claude)
is "all skills linked" "$(ls "$P/.claude/skills" | wc -l | tr -d ' ')" "$N_SKILLS"
is "all agents linked" "$(ls "$P/.claude/agents" | wc -l | tr -d ' ')" "$N_AGENTS"
yes_ "bootstrap registered" "$(grep -o session-start.sh "$P/.claude/settings.json" 2>/dev/null | head -1)"
is "fires on compact" "$(python3 -c "import json;print('compact' in json.load(open('$P/.claude/settings.json'))['hooks']['SessionStart'][0]['matcher'])")" "True"

echo "── name collision: BOTH survive (never displace the project's own)"
P=$(proj collide)
mkdir -p "$P/.claude/skills/build" "$P/.claude/agents"
echo MINE > "$P/.claude/skills/build/SKILL.md"
echo MINE > "$P/.claude/agents/code-reviewer.md"
run "$P" claude >/dev/null
is "their skill untouched"  "$(cat "$P/.claude/skills/build/SKILL.md")" "MINE"
is "their agent untouched"  "$(cat "$P/.claude/agents/code-reviewer.md")" "MINE"
yes_ "ours installed as mastermind-build" "$([ -L "$P/.claude/skills/mastermind-build" ] && echo y)"
yes_ "ours installed as mastermind-code-reviewer.md" "$([ -L "$P/.claude/agents/mastermind-code-reviewer.md" ] && echo y)"
is "no capability lost (all ours + 1 theirs)" "$(ls "$P/.claude/skills" | wc -l | tr -d ' ')" "$((N_SKILLS + 1))"
is "no .bak created" "$(ls "$P/.claude/skills/"*.bak-* 2>/dev/null | wc -l | tr -d ' ')" "0"

echo "── collision released: ours reclaims the plain name"
rm -rf "$P/.claude/skills/build"; run "$P" claude >/dev/null
yes_ "build is ours now" "$([ -L "$P/.claude/skills/build" ] && echo y)"
is "alias cleaned up" "$([ -e "$P/.claude/skills/mastermind-build" ] && echo present || echo gone)" "gone"

echo "── idempotency"
P=$(proj idem); run "$P" claude >/dev/null; run "$P" claude >/dev/null; run "$P" claude >/dev/null
is "still all skills" "$(ls "$P/.claude/skills" | wc -l | tr -d ' ')" "$N_SKILLS"
is "one bootstrap entry" "$(python3 -c "import json;d=json.load(open('$P/.claude/settings.json'));print(sum('session-start.sh' in json.dumps(e) for e in d['hooks']['SessionStart']))")" "1"

echo "── existing settings.json is merged, never clobbered"
P=$(proj merge); mkdir -p "$P/.claude"
cat > "$P/.claude/settings.json" <<'EOF'
{"model":"opus","hooks":{"SessionStart":[{"matcher":"startup","hooks":[{"type":"command","command":"echo MINE"}]}],"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo GUARD"}]}]}}
EOF
run "$P" claude >/dev/null
is "their model kept"       "$(python3 -c "import json;print(json.load(open('$P/.claude/settings.json')).get('model'))")" "opus"
is "their PreToolUse kept"  "$(python3 -c "import json;print('PreToolUse' in json.load(open('$P/.claude/settings.json'))['hooks'])")" "True"
is "their SessionStart kept" "$(python3 -c "import json;d=json.load(open('$P/.claude/settings.json'));print(any('MINE' in json.dumps(e) for e in d['hooks']['SessionStart']))")" "True"

echo "── unparseable settings.json is left strictly alone"
P=$(proj corrupt); mkdir -p "$P/.claude"; printf '{ not json' > "$P/.claude/settings.json"
run "$P" claude >/dev/null 2>&1
is "file preserved byte-for-byte" "$(cat "$P/.claude/settings.json")" "{ not json"

echo "── uninstall removes ours, keeps theirs"
P=$(proj uninst); mkdir -p "$P/.claude/skills/qa"; echo MINE > "$P/.claude/skills/qa/SKILL.md"
run "$P" claude >/dev/null; run "$P" --uninstall claude >/dev/null
is "their skill survives" "$(cat "$P/.claude/skills/qa/SKILL.md" 2>/dev/null)" "MINE"
is "our links gone" "$(find "$P/.claude/skills" -type l 2>/dev/null | wc -l | tr -d ' ')" "0"

echo "── invoking via the ~/.mastermind symlink must not self-link the brain"
H="$TMP/fakehome"; mkdir -p "$H"
ln -sfn "$REPO" "$H/.mastermind"
(cd "$H" && HOME="$H" "$H/.mastermind/install.sh" --global claude >/dev/null 2>&1) || true
is "brain link still points at the real clone" "$(readlink "$H/.mastermind")" "$REPO"
is "no literal-glob links created" "$(ls "$H/.claude/skills" 2>/dev/null | grep -c '^\*' | tr -d ' ')" "0"
is "all skills linked via the symlink path" "$(ls "$H/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')" "$N_SKILLS"

echo "── the npx path: the brain IS ~/.mastermind and install.sh runs from inside it"
H="$TMP_REAL/npxhome"; mkdir -p "$H/.mastermind"
tar -C "$REPO" --exclude=.git --exclude=node_modules -cf - . | tar -C "$H/.mastermind" -xf -
P=$(proj npxwired)
(cd "$P" && HOME="$H" "$H/.mastermind/install.sh" claude >/dev/null 2>&1); rc=$?
is "install from ~/.mastermind exits 0" "$rc" "0"
is "the project actually got wired" "$(ls "$P/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')" "$N_SKILLS"
is "~/.mastermind is still the real clone" "$([ -d "$H/.mastermind" ] && [ ! -L "$H/.mastermind" ] && echo dir)" "dir"
is "no link written inside the brain" "$([ -e "$H/.mastermind/mastermind" ] && echo present || echo gone)" "gone"

echo "── a route whose parent links out of the project is refused, not followed"
ESC="$TMP_REAL/escape"; mkdir -p "$ESC/outside"
P=$(proj routeescape); mkdir -p "$P/apps/web"
ln -s "$ESC/outside" "$P/apps/web/.cursor"
H5="$TMP_REAL/eschome"; mkdir -p "$H5"
(cd "$P" && HOME="$H5" "$INSTALL" cursor >/dev/null 2>&1) || true
F="$P/.mastermind/engineering/fields/web"; mkdir -p "$F"
for f in field.md audit-rules.md stack-defaults.md; do printf -- '---\nroute_when: web work\n---\n\n# x\n' > "$F/$f"; done
printf '# Active field\n\n## Current field: **web**\n- **Level:** 1.\n- **Field pack:** `engineering/fields/web/`\n' > "$P/.mastermind/engineering/active-field.md"
printf 'apps/web   web\n' > "$P/.mastermind/routes.map"
out=$( (cd "$P" && HOME="$H5" "$INSTALL" cursor 2>&1) || true )
is "nothing was written outside the project" "$(find "$ESC/outside" -type f 2>/dev/null | wc -l | tr -d ' ')" "0"
is "and it said why" "$(printf '%s' "$out" | grep -c 'resolves outside the project')" "1"

echo "── a DIFFERENT brain already at ~/.mastermind is refused, not written into"
H2="$TMP_REAL/otherbrain"; mkdir -p "$H2/.mastermind/skills"
P=$(proj otherwired)
out=$( (cd "$P" && HOME="$H2" "$INSTALL" claude 2>&1) || true )
is "refused with a clear reason" "$(printf '%s' "$out" | grep -c 'different brain')" "1"
is "nothing written inside their clone" "$([ -e "$H2/.mastermind/mastermind" ] && echo present || echo gone)" "gone"

echo "── a ~/.mastermind LINK to a different brain is refused too, not silently redirected"
H3="$TMP_REAL/linkedbrain"; mkdir -p "$H3" "$TMP_REAL/theirclone/skills"
ln -sfn "$TMP_REAL/theirclone" "$H3/.mastermind"
P=$(proj linkwired)
out=$( (cd "$P" && HOME="$H3" "$INSTALL" claude 2>&1) || true )
is "the link is refused" "$(printf '%s' "$out" | grep -c 'different brain')" "1"
is "and it still points where it did" "$(readlink "$H3/.mastermind")" "$TMP_REAL/theirclone"
is "the message says how to repoint it deliberately" "$(printf '%s' "$out" | grep -c 'ln -sfn')" "1"

echo "── but a link left dangling by a deleted clone is safe to reclaim"
H4="$TMP_REAL/danglinghome"; mkdir -p "$H4"
ln -sfn "$TMP_REAL/deleted-clone" "$H4/.mastermind"
P=$(proj danglewired)
(cd "$P" && HOME="$H4" "$INSTALL" claude >/dev/null 2>&1); rc=$?
is "a dangling link installs cleanly" "$rc" "0"
is "and now points at this clone" "$(readlink "$H4/.mastermind")" "$REPO"

echo "── the isolated brain can run the commands init tells the model to run"
P=$(proj isoscripts); run "$P" claude >/dev/null 2>&1
is "build-router ships"    "$([ -f "$P/.mastermind/scripts/build-router.mjs" ] && echo yes)" "yes"
is "check-integrity ships" "$([ -f "$P/.mastermind/scripts/check-integrity.mjs" ] && echo yes)" "yes"
is "build-library does NOT ship (it writes into the site repo)" \
   "$([ -f "$P/.mastermind/scripts/build-library.mjs" ] && echo present || echo gone)" "gone"
(cd "$P" && node .mastermind/scripts/build-router.mjs >/dev/null 2>&1)
is "build-router regenerates the PROJECT brain" "$?" "0"
(cd "$P" && node .mastermind/scripts/check-integrity.mjs >/dev/null 2>&1)
is "check-integrity passes on a fresh isolated brain" "$?" "0"

echo "── --check from ~ asks the global question, not a project one"
CH="$TMP_REAL/checkhome"; mkdir -p "$CH"
(cd "$CH" && HOME="$CH" "$INSTALL" --global claude >/dev/null 2>&1)
out=$(cd "$CH" && HOME="$CH" "$INSTALL" --check 2>&1)
is "says which scope it switched to" "$(printf '%s' "$out" | grep -c 'checking the global install')" "1"
is "and reports the global install healthy" "$(printf '%s' "$out" | grep -c 'healthy here')" "1"

# The switch must NOT leak into a real project: that would hide genuine project breakage.
P=$(proj checkproj); run "$P" claude >/dev/null 2>&1
out=$(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" --check 2>&1)
is "a real project is still checked as a project" "$(printf '%s' "$out" | grep -c 'checking the global install')" "0"
is "and that project reports healthy" "$(printf '%s' "$out" | grep -c 'healthy here')" "1"

echo "── a repo cannot redirect the installer outside itself via a symlinked integration dir"
for d in .claude .cursor; do
  V="$TMP_REAL/victim-${d#.}"; mkdir -p "$V"
  P=$(proj "escape-${d#.}"); (cd "$P" && ln -s "$V" "$d")
  (cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" claude cursor >/dev/null 2>&1); rc=$?
  is "$d escape refused (non-zero exit)" "$([ "$rc" -ne 0 ] && echo refused)" "refused"
  is "$d escape wrote nothing outside" "$(find "$V" -type f -o -type l 2>/dev/null | wc -l | tr -d ' ')" "0"
done
# The guard must not fire on an ordinary project.
P=$(proj noescape); run "$P" claude cursor >/dev/null 2>&1
is "an ordinary project still installs" "$(ls "$P/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')" "$N_SKILLS"

echo "── a project's own instructions keep applying (project wins)"
P=$(proj projwins); mkdir -p "$P/.claude"
printf '# Our rules\nNever deploy to prod on Friday.\n' > "$P/.claude/CLAUDE.md"
printf '# Team file\nUse pnpm.\n' > "$P/AGENTS.md"
run "$P" claude agents >/dev/null 2>&1
is "their rule still applies" "$(grep -c Friday "$P/.claude/CLAUDE.md")" "1"
is "and ours is wired in too" "$(grep -c 'mastermind/CLAUDE.md' "$P/.claude/CLAUDE.md")" "1"
is "their AGENTS.md content survives" "$(grep -c pnpm "$P/AGENTS.md")" "1"
is "AGENTS.md points at the project brain" "$(grep -c './.mastermind/CLAUDE.md' "$P/AGENTS.md")" "1"

echo "── the doctor knows what SHOULD be wired, not just what survived"
P=$(proj doctor); run "$P" claude cursor >/dev/null 2>&1
is "the install is recorded" "$(sed -n 's/^tools=//p' "$P/.mastermind/.installed" 2>/dev/null)" "claude cursor"
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" --check >/dev/null 2>&1); is "a healthy install passes" "$?" "0"
rm -f "$P/.cursor/rules/mastermind.mdc"
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" --check >/dev/null 2>&1); rc=$?
is "deleted wiring is reported, not ignored" "$([ "$rc" -ne 0 ] && echo caught)" "caught"

echo "── canary self-test: an escape must trip it even with no rule that names the path"
P=$(proj canaryprobe); (cd "$P" && ln -s "$CANARY" .claude)
run "$P" claude >/dev/null 2>&1 || true

echo "── a hostile repository cannot redirect a single write"
for victimpath in .claude .claude/skills .claude/agents .cursor .cursor/rules .github/hooks; do
  # NOTE: TMP_REAL resolves to TMP, so a victim named after the project IS the project.
  V="$TMP_REAL/victims/$(printf '%s' "$victimpath" | tr '/.' '__')"; mkdir -p "$V"
  P=$(proj "hostile-$(printf '%s' "$victimpath" | tr '/.' '__')")
  mkdir -p "$P/$(dirname "$victimpath")"
  ln -s "$V" "$P/$victimpath"
  run "$P" claude cursor >/dev/null 2>&1 || true
  is "$victimpath cannot be redirected" "$(find "$V" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')" "0"
done
echo "── a hostile repository cannot redirect a single FILE write either"
FV="$TMP_REAL/victims/files"; rm -rf "$FV"; mkdir -p "$FV"
P=$(proj hostile-files); mkdir -p "$P/.claude" "$P/.cursor/rules" "$P/.mastermind"
for pair in ".claude/settings.json:settings" ".cursor/hooks.json:hooks" \
            ".cursor/rules/mastermind.mdc:mdc" ".mastermind/VERSION:version" \
            ".mastermind/.manifest:manifest" ".mastermind/.installed:installed"; do
  rel="${pair%%:*}"; nm="${pair##*:}"
  printf 'ORIGINAL\n' > "$FV/$nm"; ln -s "$FV/$nm" "$P/$rel"
done
run "$P" claude cursor >/dev/null 2>&1 || true
is "no owned file was written through a symlink" \
   "$(grep -L ORIGINAL "$FV"/* 2>/dev/null | wc -l | tr -d ' ')" "0"

# Uninstall reads the same paths and DELETES through them, so it needs the same guarantee.
V="$TMP_REAL/victims/uninstall"; mkdir -p "$V"; echo keepme > "$V/precious.txt"
P=$(proj hostile-uninstall); run "$P" claude >/dev/null 2>&1
rm -rf "$P/.claude"; ln -s "$V" "$P/.claude"
run "$P" --uninstall claude >/dev/null 2>&1 || true
is "uninstall cannot delete through a redirected path" "$(cat "$V/precious.txt" 2>/dev/null)" "keepme"

echo "── a committed project survives being cloned elsewhere and the original vanishing"
P=$(proj portable); run "$P" claude cursor agents >/dev/null 2>&1
is "no link points outside the project" \
   "$(find "$P" -type l -exec readlink {} \; | grep -c '^/' | tr -d ' ')" "0"
is "no committed file carries this machine's path" \
   "$(grep -rl "$TMP_REAL" "$P/.claude" "$P/.cursor" 2>/dev/null | wc -l | tr -d ' ')" "0"
(cd "$P" && git init -q . 2>/dev/null; git add -A >/dev/null 2>&1
 git -c user.email=t@t -c user.name=t commit -qm wired >/dev/null 2>&1) || true
CLONE="$TMP_REAL/portable-clone"; rm -rf "$CLONE"
git clone -q "$P" "$CLONE" >/dev/null 2>&1
mv "$P" "$P-gone"                                   # the original is now unreachable
is "every link still resolves in the clone" \
   "$(cd "$CLONE" && find . -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')" "0"
is "a skill resolves for the teammate" "$([ -e "$CLONE/.claude/skills/build/SKILL.md" ] && echo yes)" "yes"
mv "$P-gone" "$P"

echo "── a user's own file keeps working wherever we write"
P=$(proj preserve); mkdir -p "$P/.claude" "$P/.cursor/rules"
printf '# mine\nCANARY-CLAUDE never deploy on Friday\n' > "$P/.claude/CLAUDE.md"
printf '# mine\nCANARY-AGENTS use pnpm\n' > "$P/AGENTS.md"
printf -- '---\nalwaysApply: true\n---\nCANARY-CURSOR house style\n' > "$P/.cursor/rules/team.mdc"
run "$P" claude cursor agents >/dev/null 2>&1
is "their CLAUDE.md still applies"  "$(grep -c CANARY-CLAUDE "$P/.claude/CLAUDE.md" 2>/dev/null)" "1"
is "their AGENTS.md still applies"  "$(grep -c CANARY-AGENTS "$P/AGENTS.md" 2>/dev/null)" "1"
is "their cursor rule is untouched" "$(grep -c CANARY-CURSOR "$P/.cursor/rules/team.mdc" 2>/dev/null)" "1"
is "and MasterMind is wired alongside" "$(ls "$P/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')" "$N_SKILLS"

echo "── the doctor notices every piece of wiring that goes missing"
for target in .claude/CLAUDE.md .claude/skills/build .claude/settings.json .cursor/rules/mastermind.mdc AGENTS.md; do
  P=$(proj "repair-$(printf '%s' "$target" | tr '/.' '__')")
  run "$P" claude cursor agents >/dev/null 2>&1
  rm -rf "${P:?}/$target"
  (cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" --check >/dev/null 2>&1); rc=$?
  is "deleting $target is reported" "$([ "$rc" -ne 0 ] && echo caught)" "caught"
done

echo "── the install record survives a partial repair, and shrinks on uninstall"
P=$(proj record); run "$P" claude cursor agents >/dev/null 2>&1
run "$P" claude >/dev/null 2>&1
rec="$(sed -n 's/^tools=//p' "$P/.mastermind/.installed")"
is "a partial repair keeps the other tools" "$(printf '%s' "$rec" | tr ' ' '\n' | grep -cx cursor)" "1"
rm -f "$P/.cursor/rules/mastermind.mdc"
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" --check >/dev/null 2>&1); rc=$?
is "so deleted wiring is still caught after a repair" "$([ "$rc" -ne 0 ] && echo caught)" "caught"
run "$P" --uninstall cursor >/dev/null 2>&1
is "uninstall drops that tool from the record" \
   "$(sed -n 's/^tools=//p' "$P/.mastermind/.installed" 2>/dev/null | tr ' ' '\n' | grep -cx cursor)" "0"
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" --check >"$TMP/check-after-targeted-uninstall" 2>&1); rc=$?
is "the doctor trusts a record rewritten by targeted uninstall" \
   "$(grep -c 'edited by hand' "$TMP/check-after-targeted-uninstall" || true)" "0"
is "the remaining integrations are healthy after targeted uninstall" "$rc" "0"

echo "── agents and codex aliases keep their shared AGENTS.md until both are removed"
P=$(proj agent-aliases); run "$P" agents codex >/dev/null 2>&1
run "$P" --uninstall codex >/dev/null 2>&1
is "uninstalling codex keeps AGENTS.md for agents" "$([ -e "$P/AGENTS.md" ] && echo kept || echo gone)" "kept"
is "agents remains healthy" "$(run "$P" --check 2>&1 | grep -c 'healthy here')" "1"
run "$P" codex >/dev/null 2>&1
run "$P" --uninstall agents >/dev/null 2>&1
is "uninstalling agents keeps AGENTS.md for codex" "$([ -e "$P/AGENTS.md" ] && echo kept || echo gone)" "kept"
is "codex remains healthy" "$(run "$P" --check 2>&1 | grep -c 'healthy here')" "1"

echo "── uninstall takes our pointer back out of the files it appended to"
P=$(proj pointer); mkdir -p "$P/.claude"
printf '# mine\nMY CLAUDE RULE\n' > "$P/.claude/CLAUDE.md"
printf '# mine\nMY AGENTS RULE\n' > "$P/AGENTS.md"
run "$P" claude agents >/dev/null 2>&1
run "$P" --uninstall claude agents >/dev/null 2>&1
is "no pointer left in .claude/CLAUDE.md" "$(count_in "$P/.claude/CLAUDE.md" 'mastermind/CLAUDE.md')" "0"
is "no pointer left in AGENTS.md"        "$(count_in "$P/AGENTS.md" 'mastermind/CLAUDE.md')" "0"
is "their CLAUDE.md content survived"    "$(count_in "$P/.claude/CLAUDE.md" 'MY CLAUDE RULE')" "1"
is "their AGENTS.md content survived"    "$(count_in "$P/AGENTS.md" 'MY AGENTS RULE')" "1"

echo "── an unbalanced nested marker still hands back every line"
P=$(proj nestedmarkers)
mkdir -p "$P/apps/web"
run "$P" claude cursor >/dev/null 2>&1
cp -R "$P/.mastermind/engineering/fields/_template" "$P/.mastermind/engineering/fields/frontend"
printf 'apps/web frontend\n' > "$P/.mastermind/routes.map"
run "$P" claude cursor >/dev/null 2>&1
is "the route anchor was generated" "$([ -f "$P/apps/web/CLAUDE.md" ] && echo yes || echo no)" "yes"
python3 - "$P/apps/web/CLAUDE.md" <<'EOF'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
p.write_text(p.read_text().replace("<!-- MASTERMIND:END -->",
                                   "<!-- MASTERMIND:START -->\nTHEIR PRECIOUS NOTE\n"))
EOF
run "$P" --uninstall >/dev/null 2>&1
is "their line survived the teardown" "$(count_in "$P/apps/web/CLAUDE.md" 'THEIR PRECIOUS NOTE')" "1"

echo "── the installed brain carries no ABOUT pages"
P=$(proj noabout)
run "$P" claude >/dev/null 2>&1
is "no ABOUT.md was installed" "$(find "$P/.mastermind" -name ABOUT.md 2>/dev/null | wc -l | tr -d ' ')" "0"
# Directories only: the skills folder also carries an index and a readme.
is "the skills themselves are there" "$(find "$P/.mastermind/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "$N_SKILLS"
is "and the shipped checks still pass there" \
   "$( (cd "$P/.mastermind" && node scripts/check-integrity.mjs >/dev/null 2>&1) && echo ok || echo fail)" "ok"

echo "── replacing a project's edit to an engine file is announced"
P=$(proj hashledger)
run "$P" claude >/dev/null 2>&1
is "a hash ledger was written" "$([ -s "$P/.mastermind/.manifest.hashes" ] && echo yes || echo no)" "yes"
is "a clean re-run says nothing" "$(run "$P" claude 2>&1 | grep -c 'replacing your edit')" "0"
printf 'PROJECT EDIT\n' >> "$P/.mastermind/engineering/core/mindset.md"
out=$(run "$P" claude 2>&1)
is "the edited file is named"     "$(printf '%s' "$out" | grep -c 'replacing your edit to engineering/core/mindset.md')" "1"
is "and only that one"            "$(printf '%s' "$out" | grep -c 'replacing your edit')" "1"
is "the refresh still happened"   "$(count_in "$P/.mastermind/engineering/core/mindset.md" 'PROJECT EDIT')" "0"

# ══ The record says whether it was edited ═════════════════════════════════════
echo "── a hand-edited install record is called out"
P=$(proj tamper)
run "$P" claude >/dev/null 2>&1
is "the record carries a digest" "$(count_in "$P/.mastermind/.installed" '^digest=')" "1"
is "an untouched record is quiet" "$(run "$P" --check 2>&1 | grep -c 'edited by hand')" "0"
python3 - "$P/.mastermind/.installed" <<'EOF'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
p.write_text(re.sub(r"^tools=.*$", "tools=claude cursor codex", p.read_text(), count=1, flags=re.M))
EOF
is "an edited record is reported" "$(run "$P" --check 2>&1 | grep -c 'edited by hand')" "1"

# ══ A new upstream file never lands on top of the project's own ═══════════════
# A manifest path with no hash entry is normal, not an error: it is every file a release adds.
# Reading it through `set -euo pipefail` without a guard aborted the installer with no message.
echo "── a gap in the hash ledger does not abort the install"
P=$(proj ledgergap)
run "$P" claude >/dev/null 2>&1
python3 - "$P/.mastermind/.manifest.hashes" <<'EOF'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
p.write_text("\n".join(l for l in p.read_text().split("\n") if "core/mindset.md" not in l))
EOF
run "$P" claude >/dev/null 2>&1; rc=$?
is "the install still succeeds"      "$rc" "0"
is "and it finished the refresh"     "$(count_in "$P/.mastermind/engineering/core/mindset.md" 'soul of MasterMind')" "1"
is "the ledger is rebuilt complete"  "$(count_in "$P/.mastermind/.manifest.hashes" 'core/mindset.md')" "1"

echo "── a colliding project file is kept, not overwritten"
P=$(proj collide)
run "$P" claude >/dev/null 2>&1
printf 'MY OWN VERSION\n' > "$P/.mastermind/engineering/core/mindset.md"
python3 - "$P/.mastermind/.manifest.hashes" <<'EOF'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
p.write_text("\n".join(l for l in p.read_text().split("\n") if not l.endswith("  engineering/core/mindset.md")))
EOF
# A longer sibling path must not be mistaken for ownership of mindset.md itself.
printf 'not-a-real-hash  engineering/core/mindset.md.extra\n' >> "$P/.mastermind/.manifest.hashes"
out=$(run "$P" claude 2>&1)
is "the collision is announced"  "$(printf '%s' "$out" | grep -c 'your project already had')" "1"
is "their content is preserved" "$(cat "$P"/.mastermind/engineering/core/*.yours-* 2>/dev/null | grep -c 'MY OWN VERSION')" "1"
is "and ours is installed"      "$(count_in "$P/.mastermind/engineering/core/mindset.md" 'MY OWN VERSION')" "0"

echo "── a colliding project directory is kept, not recursively deleted"
P=$(proj collide-dir)
run "$P" claude >/dev/null 2>&1
rm -f "$P/.mastermind/engineering/core/mindset.md" "$P/.mastermind/CLAUDE.md"
mkdir -p "$P/.mastermind/engineering/core/mindset.md" "$P/.mastermind/CLAUDE.md"
printf 'NESTED DIRECTORY\n' > "$P/.mastermind/engineering/core/mindset.md/user.txt"
printf 'ROOT DIRECTORY\n' > "$P/.mastermind/CLAUDE.md/user.txt"
out=$(run "$P" claude 2>&1)
is "both directory collisions are announced" "$(printf '%s' "$out" | grep -c 'where your project had a directory')" "2"
is "the nested directory survives" "$(cat "$P"/.mastermind/engineering/core/mindset.md.yours-*/user.txt 2>/dev/null)" "NESTED DIRECTORY"
is "the root directory survives"   "$(cat "$P"/.mastermind/CLAUDE.md.yours-*/user.txt 2>/dev/null)" "ROOT DIRECTORY"
is "the nested engine file is installed" "$([ -f "$P/.mastermind/engineering/core/mindset.md" ] && echo yes || echo no)" "yes"
is "the root engine file is installed"   "$([ -f "$P/.mastermind/CLAUDE.md" ] && echo yes || echo no)" "yes"

echo "── a first install preserves regular files in a pre-existing brain tree"
P=$(proj first-install-collide)
mkdir -p "$P/.mastermind/engineering/core"
printf 'FIRST NESTED FILE\n' > "$P/.mastermind/engineering/core/mindset.md"
printf 'FIRST ROOT FILE\n' > "$P/.mastermind/CLAUDE.md"
out=$(run "$P" claude 2>&1)
is "both first-install collisions are announced" "$(printf '%s' "$out" | grep -c 'which your project already had')" "2"
is "the first nested file survives" "$(cat "$P"/.mastermind/engineering/core/mindset.md.yours-* 2>/dev/null)" "FIRST NESTED FILE"
is "the first root file survives"   "$(cat "$P"/.mastermind/CLAUDE.md.yours-* 2>/dev/null)" "FIRST ROOT FILE"
is "the nested engine file replaces the collision" "$(count_in "$P/.mastermind/engineering/core/mindset.md" 'FIRST NESTED FILE')" "0"
is "the root engine file replaces the collision"   "$(count_in "$P/.mastermind/CLAUDE.md" 'FIRST ROOT FILE')" "0"

# ══ Every path the brain writes, not only the shipped engine files ═══════════
# The containment guard covered ISO_ENGINE and ISO_OWNED. It did not cover the state files or
# the context and field directories, so a dangling symlink at one of them made the write land
# outside the project while the install still exited 0.
echo "── a symlink at any brain path is refused, not written through"
for _p in routes.map .manifest .manifest.hashes .installed .routes.generated VERSION \
          engineering/contexts engineering/fields; do
  P=$(proj "esc$(printf '%s' "$_p" | tr -c 'a-z' 'x')")
  OUT="$TMP_REAL/victims/escape-$$"; rm -f "$OUT"
  mkdir -p "$P/.mastermind/$(dirname "$_p")"
  ln -s "$OUT" "$P/.mastermind/$_p"
  run "$P" claude >/dev/null 2>&1 || true
  is "$_p cannot escape the project" "$([ -e "$OUT" ] && echo escaped || echo contained)" "contained"
done

# The context directory is named by routes.map, so the repository chooses the path.
echo "── a context path named by routes.map is checked too"
P=$(proj ctxescape); mkdir -p "$P/apps/web"
run "$P" claude cursor >/dev/null 2>&1
cp -R "$P/.mastermind/engineering/fields/_template" "$P/.mastermind/engineering/fields/frontend"
printf 'apps/web webctx\n' > "$P/.mastermind/routes.map"
CTXOUT="$TMP_REAL/victims/ctx-$$"; rm -f "$CTXOUT"
mkdir -p "$P/.mastermind/engineering/contexts"
ln -s "$CTXOUT" "$P/.mastermind/engineering/contexts/webctx"
out=$(run "$P" claude cursor 2>&1) || true
is "the context symlink is refused"  "$(printf '%s' "$out" | grep -c 'points outside the brain')" "1"
is "and nothing was created outside" "$([ -e "$CTXOUT" ] && echo escaped || echo contained)" "contained"

# ══ A link of theirs that happens to point into the brain is still theirs ═════
# Ownership meant "resolves somewhere inside .mastermind", so a project pointing AGENTS.md at
# its own file in there had that link replaced with no backup and removed on uninstall.
echo "── a project's own link into the brain survives"
P=$(proj theirlink)
run "$P" claude >/dev/null 2>&1
printf 'MY PREFS\n' > "$P/.mastermind/prefs.md"
rm -f "$P/AGENTS.md"; ln -s .mastermind/prefs.md "$P/AGENTS.md"
run "$P" claude agents >/dev/null 2>&1
is "ours is wired"            "$(readlink "$P/AGENTS.md")" ".mastermind/AGENTS.md"
is "theirs was backed up"     "$(ls "$P"/AGENTS.md.bak-* 2>/dev/null | wc -l | tr -d ' ')" "1"
run "$P" --uninstall >/dev/null 2>&1
is "and theirs is handed back" "$(readlink "$P/AGENTS.md")" ".mastermind/prefs.md"

# ══ Two projects, two records ════════════════════════════════════════════════
# Sanitising the path made /a/b and /a_b the same filename, so each project inherited the
# other's expected tools.
echo "── project paths that sanitise alike keep separate records"
mkdir -p "$TMP/coll/a/b" "$TMP/coll/a_b"
(cd "$TMP/coll/a/b" && git init -q .); (cd "$TMP/coll/a_b" && git init -q .)
(cd "$TMP/coll/a/b" && HOME="$SANDBOX_HOME" "$INSTALL" --shared claude >/dev/null 2>&1)
(cd "$TMP/coll/a_b" && HOME="$SANDBOX_HOME" "$INSTALL" --shared claude cursor >/dev/null 2>&1)
is "the nested project kept its own tools" \
   "$(grep -rlxF "project=$TMP_REAL/coll/a/b" "$SANDBOX_HOME/.mastermind-state/projects" 2>/dev/null | head -1 | xargs -I{} grep -c '^tools=claude$' {} 2>/dev/null || echo 0)" "1"

# ══ Retired names are accepted, never recorded ═══════════════════════════════
echo "── a retired tool name does not become expected wiring"
P=$(proj retired)
run "$P" claude gemini >/dev/null 2>&1
is "gemini is not in the record" "$(count_in "$P/.mastermind/.installed" 'gemini')" "0"
is "claude still is"             "$(count_in "$P/.mastermind/.installed" 'tools=claude')" "1"

# ══ The pointer we wrote before today is still ours to remove ════════════════
# Releases up to 0.31.2 wrote the hint with an em dash. Cleanup matches whole lines, so the old
# form has to stay recognised or our text is stranded in every existing user's file.
echo "── a pointer written by an older release is still cleaned up"
P=$(proj legacyhint)
printf 'their notes\n\nFollow ./.mastermind/CLAUDE.md: the MasterMind brain for this project (skills, agents, engineering rigor).\n' > "$P/AGENTS.md"
run "$P" claude >/dev/null 2>&1
run "$P" --uninstall >/dev/null 2>&1
is "the legacy pointer is gone"  "$(count_in "$P/AGENTS.md" 'the MasterMind brain for this project')" "0"
is "their own text stayed"       "$(count_in "$P/AGENTS.md" 'their notes')" "1"

# ══ The install record is data, so the doctor must survive it being wrong ═════
echo "── a corrupted or hostile install record does not break the doctor"
P=$(proj badrecord)
run "$P" claude >/dev/null 2>&1
printf 'tools=claude\x00\ntools=cursor codex\ngarbage\n' > "$P/.mastermind/.installed"
out=$(run "$P" --check 2>&1) || true
is "it still produces a report"  "$(printf '%s' "$out" | grep -cE 'healthy|issue')" "1"
printf '' > "$P/.mastermind/.installed"
out=$(run "$P" --check 2>&1) || true
is "an empty record still reports" "$(printf '%s' "$out" | grep -cE 'healthy|issue')" "1"
printf 'digest=not-a-real-digest\n' > "$P/.mastermind/.installed"
out=$(run "$P" --check 2>&1) || true
is "a digest-only record still reports" "$(printf '%s' "$out" | grep -cE 'healthy|issue')" "1"
is "a digest-only record is identified as edited" "$(printf '%s' "$out" | grep -c 'edited by hand')" "1"
rm -f "$P/.mastermind/.installed"
out=$(run "$P" --check 2>&1) || true
is "a deleted record is announced"  "$(printf '%s' "$out" | grep -c 'no install record here')" "1"

# ══ A foreign hook that merely mentions us is not ours to remove ══════════════
echo "── hook cleanup matches on path, not on the word mastermind"
P=$(proj foreignhook)
run "$P" claude >/dev/null 2>&1
python3 - "$P/.claude/settings.json" <<'EOF'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1])
d = json.loads(p.read_text() or "{}")
d.setdefault("hooks", {}).setdefault("SessionStart", []).append(
    {"hooks": [{"type": "command", "command": "/opt/theirs/hooks/session-start.sh --mastermind"}]})
p.write_text(json.dumps(d, indent=2) + "\n")
EOF
run "$P" --uninstall >/dev/null 2>&1
is "their lookalike hook survives" "$(count_in "$P/.claude/settings.json" '/opt/theirs/hooks/session-start.sh')" "1"
is "ours is gone"                  "$(count_in "$P/.claude/settings.json" '.mastermind/hooks/session-start.sh')" "0"

# ══ Converting an isolated project to shared says so instead of half-doing it ═
echo "── --shared over a project brain refuses with the way out"
P=$(proj convrefuse)
run "$P" claude >/dev/null 2>&1
out=$(run "$P" --shared claude 2>&1) || true
is "it refuses"              "$(printf '%s' "$out" | grep -c 'cannot take effect')" "1"
is "and names the remedy"    "$(printf '%s' "$out" | grep -c 'rm -rf')" "1"
run "$P" --uninstall >/dev/null 2>&1; rm -rf "$P/.mastermind"
run "$P" --shared claude >/dev/null 2>&1
is "the documented route converts" "$(readlink "$P/.claude/skills/build" | grep -c "^$REPO/skills/build$")" "1"

# ══ Project paths people actually have ════════════════════════════════════════
echo "── a project path with a space and a # installs and uninstalls cleanly"
P="$TMP/od#d name"; mkdir -p "$P"; (cd "$P" && git init -q .)
run "$P" claude >/dev/null 2>&1
is "it installed there"    "$([ -f "$P/.mastermind/VERSION" ] && echo yes || echo no)" "yes"
is "skills are linked"     "$(ls "$P/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')" "$N_SKILLS"
run "$P" --uninstall >/dev/null 2>&1
is "and uninstalled clean" "$(ls "$P/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')" "0"

echo "── the route check covers every anchor, not just the first"
P=$(proj routecheck)
mkdir -p "$P/apps/web"
run "$P" claude cursor >/dev/null 2>&1
cp -R "$P/.mastermind/engineering/fields/_template" "$P/.mastermind/engineering/fields/frontend"
printf 'apps/web frontend\n' > "$P/.mastermind/routes.map"
run "$P" claude cursor >/dev/null 2>&1
is "a complete route reports ok" "$(run "$P" --check 2>&1 | grep -c 'route apps/web/ → frontend (frontend)')" "1"
rm -f "$P/apps/web/AGENTS.md"
is "an unrecorded AGENTS surface is not demanded" "$(run "$P" --check 2>&1 | grep -c 'route apps/web/ → frontend (frontend)')" "1"
run "$P" claude cursor >/dev/null 2>&1
rm -f "$P/apps/web/.cursor/rules/mastermind.mdc"
is "a missing Cursor rule is caught"      "$(run "$P" --check 2>&1 | grep -c 'Cursor rule is missing')" "1"

# ══ Symlink chains that cycle or dangle must refuse, not hang or write ════════
echo "── a cyclic or broken chain is refused"
P=$(proj cyclicchain); mkdir -p "$P/.cursor/rules"
ln -s "$P/.cursor/rules/b" "$P/.cursor/rules/mastermind.mdc"
ln -s "$P/.cursor/rules/mastermind.mdc" "$P/.cursor/rules/b"
run "$P" cursor >/dev/null 2>&1 || true
is "a cycle does not become a written file" "$([ -L "$P/.cursor/rules/mastermind.mdc" ] && echo link || echo other)" "link"

P=$(proj brokenchain); mkdir -p "$P/.cursor/rules"
ln -s "$TMP_REAL/victims/definitely-not-here" "$P/.cursor/rules/mastermind.mdc"
run "$P" cursor >/dev/null 2>&1 || true
is "a dangling target is not created outside" "$([ -e "$TMP_REAL/victims/definitely-not-here" ] && echo created || echo absent)" "absent"

echo "── an anchor is still cleaned up after its route is removed from the map"
P=$(proj strandedanchor)
mkdir -p "$P/apps/web"
run "$P" claude cursor >/dev/null 2>&1
cp -R "$P/.mastermind/engineering/fields/_template" "$P/.mastermind/engineering/fields/frontend"
printf 'apps/web frontend\n' > "$P/.mastermind/routes.map"
run "$P" claude cursor >/dev/null 2>&1
is "the anchor exists"        "$(count_in "$P/apps/web/CLAUDE.md" 'MASTERMIND:START')" "1"
printf '\n' > "$P/.mastermind/routes.map"
run "$P" --uninstall >/dev/null 2>&1
is "and is not left stranded" "$(count_in "$P/apps/web/CLAUDE.md" 'MASTERMIND:START')" "0"

echo "── a route anchor uses the field the project declares"
P=$(proj declaredfield)
mkdir -p "$P/apps/web"
run "$P" claude cursor >/dev/null 2>&1
cp -R "$P/.mastermind/engineering/fields/_template" "$P/.mastermind/engineering/fields/aaa-first"
cp -R "$P/.mastermind/engineering/fields/_template" "$P/.mastermind/engineering/fields/zzz-declared"
python3 - "$P/.mastermind/engineering/active-field.md" <<'EOF'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1])
p.write_text(re.sub(r"^## Current field: .*$", "## Current field: **zzz-declared**",
                    p.read_text(), count=1, flags=re.M))
EOF
printf 'apps/web webctx\n' > "$P/.mastermind/routes.map"
run "$P" claude cursor >/dev/null 2>&1
is "the anchor names the declared field" "$(count_in "$P/apps/web/CLAUDE.md" 'fields/zzz-declared/')" "1"
is "not the alphabetically first one"    "$(count_in "$P/apps/web/CLAUDE.md" 'fields/aaa-first/')" "0"

echo "── a pointer round trip changes nothing in the file"
P=$(proj exactbytes)
printf 'line one\nline two\n' > "$P/AGENTS.md"
cp "$P/AGENTS.md" "$P/.orig"
run "$P" claude agents >/dev/null 2>&1
run "$P" --uninstall >/dev/null 2>&1
is "AGENTS.md is byte-identical" "$(cmp -s "$P/AGENTS.md" "$P/.orig" && echo same || echo differs)" "same"

echo "── a project's own symlinked AGENTS.md survives install and uninstall"
P=$(proj symlinkedagents)
printf 'SHARED RULES\n' > "$P/RULES.md"
ln -s RULES.md "$P/AGENTS.md"
run "$P" claude agents >/dev/null 2>&1
run "$P" --uninstall >/dev/null 2>&1
is "AGENTS.md is a symlink again"  "$([ -L "$P/AGENTS.md" ] && echo yes || echo no)" "yes"
is "and it points where it did"    "$(readlink "$P/AGENTS.md")" "RULES.md"

echo "── a link aimed at the wrong target is reported"
P=$(proj wrongtarget)
run "$P" claude >/dev/null 2>&1
# A real brain skill, but not this name's: repair by adding the alias, not by taking theirs.
ln -sfn ../../.mastermind/skills/debug "$P/.claude/skills/build"
is "the doctor rejects it" "$(run "$P" --check 2>&1 | grep -c 'is not linked to MasterMind')" "1"
run "$P" claude >/dev/null 2>&1
is "and re-running repairs it" "$(run "$P" --check 2>&1 | grep -c 'healthy')" "1"
is "their link is left alone"  "$(readlink "$P/.claude/skills/build")" "../../.mastermind/skills/debug"
yes_ "ours arrives as the alias" "$(readlink "$P/.claude/skills/mastermind-build" 2>/dev/null)"

# Their own link, aimed at their own skill, must survive both halves of the lifecycle.
P=$(proj ownskilllink)
run "$P" claude >/dev/null 2>&1
mkdir -p "$P/.mastermind/skills/team-build"; printf 'OURS\n' > "$P/.mastermind/skills/team-build/SKILL.md"
rm -rf "$P/.claude/skills/build"
ln -s ../../.mastermind/skills/team-build "$P/.claude/skills/build"
run "$P" claude >/dev/null 2>&1
is "install keeps their aim"   "$(readlink "$P/.claude/skills/build")" "../../.mastermind/skills/team-build"
run "$P" --uninstall >/dev/null 2>&1
is "uninstall keeps their link" "$(readlink "$P/.claude/skills/build" 2>/dev/null)" "../../.mastermind/skills/team-build"
is "uninstall takes ours"       "$([ -L "$P/.claude/skills/mastermind-build" ] && echo kept || echo gone)" "gone"

# ══ A file that mentions the pointer is not a file that carries it ════════════
echo "── an incidental mention does not count as wiring"
P=$(proj mentiononly)
printf 'See ~/.mastermind/CLAUDE.md for details.\n' > "$P/AGENTS.md"
is "a mention alone is not wired" "$(run "$P" --check 2>&1 | grep -c "isn't set up")" "1"

echo "── a shared install leaves an expected-integration record"
P=$(proj sharedrecord)
run "$P" --shared claude cursor >/dev/null 2>&1
_recf="$(grep -rlxF "project=$P" "$SANDBOX_HOME/.mastermind-state/projects" 2>/dev/null | head -1)"
is "the record lists both tools" "$(count_in "${_recf:-/nonexistent}" 'tools=claude cursor')" "1"
# The record has to track removals too, or the doctor keeps demanding wiring the user dropped.
run "$P" --uninstall cursor >/dev/null 2>&1
is "a targeted uninstall drops that tool" "$(count_in "${_recf:-/nonexistent}" 'cursor')" "0"
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" --check >"$TMP/check-shared-after-targeted-uninstall" 2>&1); rc=$?
is "the shared doctor trusts the rewritten record" \
   "$(grep -c 'edited by hand' "$TMP/check-shared-after-targeted-uninstall" || true)" "0"
is "the remaining shared integration is healthy" "$rc" "0"
run "$P" --uninstall >/dev/null 2>&1
_recf="$(grep -rlxF "project=$P" "$SANDBOX_HOME/.mastermind-state/projects" 2>/dev/null | head -1)"
is "a bare uninstall drops the record"    "$(grep -rlxF "project=$P" "$SANDBOX_HOME/.mastermind-state/projects" 2>/dev/null | wc -l | tr -d ' ')" "0"

echo "── files we did not generate are preserved, not destroyed"
P=$(proj ownedpaths)
mkdir -p "$P/.cursor/rules" "$P/.github/hooks"
printf 'MY OWN CURSOR RULE\n'  > "$P/.cursor/rules/mastermind.mdc"
printf '{"mine":true}\n'       > "$P/.github/hooks/mastermind.json"
run "$P" claude cursor >/dev/null 2>&1
is "our rule replaced theirs on install" "$(count_in "$P/.cursor/rules/mastermind.mdc" 'Prime directives')" "1"
run "$P" --uninstall >/dev/null 2>&1
is "their cursor rule is handed back"    "$(count_in "$P/.cursor/rules/mastermind.mdc" 'MY OWN CURSOR RULE')" "1"
is "their hook file is left alone"       "$(count_in "$P/.github/hooks/mastermind.json" 'mine')" "1"

echo "── unreadable settings.json is reported, not glossed over"
P=$(proj honestuninstall)
run "$P" claude >/dev/null 2>&1
mkdir -p "$P/.claude"
printf '{ this is not json\n' > "$P/.claude/settings.json"
out=$(run "$P" --uninstall 2>&1) || true
is "it says what it could not undo" "$(printf '%s' "$out" | grep -c 'could not edit settings.json')" "1"
is "and does not claim success"     "$(printf '%s' "$out" | grep -c 'left untouched')" "0"

echo "── a project uninstall does not edit the global Codex file"
P=$(proj codexscope)
mkdir -p "$SANDBOX_HOME/.codex"
{ printf 'MY CODEX GLOBAL\n\n'
  printf 'Follow ~/.mastermind/CLAUDE.md: the MasterMind brain (skills, agents, engineering rigor).\n'
} > "$SANDBOX_HOME/.codex/AGENTS.md"
run "$P" claude codex >/dev/null 2>&1
run "$P" --uninstall >/dev/null 2>&1
is "the global Codex pointer survives"  "$(count_in "$SANDBOX_HOME/.codex/AGENTS.md" 'the MasterMind brain (skills')" "1"
is "and their own content survives too" "$(count_in "$SANDBOX_HOME/.codex/AGENTS.md" 'MY CODEX GLOBAL')" "1"

echo "── uninstall will not act on a backup pointer it did not write"
SECRET="$TMP_REAL/victims/private"; rm -rf "$SECRET"; mkdir -p "$SECRET"
printf 'PRIVATE-KEY\n' > "$SECRET/id_rsa"
P=$(proj bakptr)
run "$P" claude >/dev/null 2>&1
mkdir -p "$P/.claude"
printf '%s\n' "$SECRET/id_rsa" > "$P/.claude/CLAUDE.md.mm-backup"
rm -f "$P/.claude/CLAUDE.md"
run "$P" --uninstall >/dev/null 2>&1 || true
is "a foreign file is not moved into the project" "$(count_in "$SECRET/id_rsa" 'PRIVATE-KEY')" "1"
is "and nothing was restored from it" "$(count_in "$P/.claude/CLAUDE.md" 'PRIVATE-KEY')" "0"

echo "── pruning leaves symlinks that were never ours"
P=$(proj prunemine)
run "$P" claude >/dev/null 2>&1
ln -s "$TMP_REAL/victims/nowhere-at-all" "$P/.claude/skills/my-own-skill"
run "$P" claude >/dev/null 2>&1
is "the user's own broken link survives a reinstall" "$([ -L "$P/.claude/skills/my-own-skill" ] && echo yes || echo no)" "yes"

echo "── containment resolves the whole chain and respects path boundaries"

# (a) a chain: the owned file -> a link inside the project -> a file outside it
CV="$TMP_REAL/victims/chain"; rm -rf "$CV"; mkdir -p "$CV"; printf 'SENTINEL\n' > "$CV/f"
P=$(proj chainlink); mkdir -p "$P/.cursor/rules" "$P/mid"
ln -s "$CV/f" "$P/mid/hop"; ln -s "$P/mid/hop" "$P/.cursor/rules/mastermind.mdc"
run "$P" cursor >/dev/null 2>&1 || true
is "a multi-hop chain cannot reach outside" "$(cat "$CV/f")" "SENTINEL"

# (b) a sibling whose name merely starts with the brain's path
SV="$TMP_REAL/victims/brainlike"; rm -rf "$SV"; mkdir -p "$SV"; printf 'SENTINEL\n' > "$SV/f"
P=$(proj prefixsib); mkdir -p "$P/.cursor/rules"
ln -s "$SV/f" "$P/.cursor/rules/mastermind.mdc"
run "$P" cursor >/dev/null 2>&1 || true
is "a prefix sibling is not 'inside'" "$(cat "$SV/f")" "SENTINEL"

P=$(proj braintarget); run "$P" cursor >/dev/null 2>&1
core="$P/.mastermind/engineering/core/mindset.md"; before="$(head -c 40 "$core")"
rm -f "$P/.cursor/rules/mastermind.mdc"; ln -s "$core" "$P/.cursor/rules/mastermind.mdc"
run "$P" cursor >/dev/null 2>&1 || true
is "an owned file cannot be aimed at the engine" "$(head -c 40 "$core")" "$before"

echo "── uninstalling one tool leaves the others wired"
P=$(proj targeted); run "$P" claude cursor >/dev/null 2>&1
run "$P" --uninstall cursor >/dev/null 2>&1
is "claude survives an --uninstall cursor" "$(ls "$P/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')" "$N_SKILLS"
is "and cursor is actually gone" "$([ -f "$P/.cursor/rules/mastermind.mdc" ] && echo left || echo gone)" "gone"
run "$P" --uninstall >/dev/null 2>&1
is "a bare --uninstall still removes everything" "$(ls "$P/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')" "0"

echo "── uninstall removes what it wired, and keeps what it didn't"
P=$(proj unwire); mkdir -p "$P/.claude"
printf '{"model":"opus","hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo MINE"}]}]}}' > "$P/.claude/settings.json"
run "$P" claude cursor >/dev/null 2>&1
# An earlier install left this behind; uninstall must still clean it up.
mkdir -p "$P/.github/hooks"; printf '{}\n' > "$P/.github/hooks/mastermind.json"
printf 'MY GEMINI RULE\n\nFollow ~/.mastermind/CLAUDE.md: the MasterMind brain (skills, agents, engineering rigor).\n' > "$P/GEMINI.md"
printf 'MY COPILOT RULE\n\nFollow ~/.mastermind/CLAUDE.md: the MasterMind brain (skills, agents, engineering rigor).\n' > "$P/.github/copilot-instructions.md"
run "$P" --uninstall claude cursor >/dev/null 2>&1
is "bootstrap hook unwired" "$(python3 -c "
import json;d=json.load(open('$P/.claude/settings.json'))
print(len([e for e in d.get('hooks',{}).get('SessionStart',[]) if 'session-start.sh' in json.dumps(e)]))")" "0"
is "their settings survive uninstall" "$(python3 -c "
import json;d=json.load(open('$P/.claude/settings.json'));print(d.get('model'),'PreToolUse' in d.get('hooks',{}))")" "opus True"
is "legacy copilot hook file removed" "$([ -f "$P/.github/hooks/mastermind.json" ] && echo present || echo gone)" "gone"
is "legacy Gemini pointer removed but user content kept" "$(count_in "$P/GEMINI.md" 'MY GEMINI RULE') $(count_in "$P/GEMINI.md" 'mastermind/CLAUDE.md')" "1 0"
is "legacy Copilot pointer removed but user content kept" "$(count_in "$P/.github/copilot-instructions.md" 'MY COPILOT RULE') $(count_in "$P/.github/copilot-instructions.md" 'mastermind/CLAUDE.md')" "1 0"

echo "── --global --uninstall must not delete project files"
P=$(proj gscope); GH="$TMP/globalhome"; mkdir -p "$GH"
(cd "$P" && HOME="$GH" "$INSTALL" agents >/dev/null 2>&1) || true
(cd "$P" && HOME="$GH" "$INSTALL" --global --uninstall >/dev/null 2>&1) || true
is "project AGENTS.md survives a global uninstall" "$([ -e "$P/AGENTS.md" ] && echo present || echo deleted)" "present"

echo "── hook emits the right JSON shape per host"
for pair in "cursor additional_context" "claude hookSpecificOutput" "sdk additionalContext"; do
  set -- $pair
  got=$("$REPO/hooks/session-start.sh" "$1" | python3 -c "import json,sys;print(list(json.load(sys.stdin))[0])" 2>/dev/null)
  is "shape '$1'" "$got" "$2"
done
yes_ "payload carries the kernel" "$("$REPO/hooks/session-start.sh" claude | grep -o 'Prime directives' | head -1)"

echo "── isolated: the project owns its brain, and keeps owning it"
P=$(proj iso); run "$P" --isolated claude >/dev/null 2>&1
is "brain copied into the project" "$([ -f "$P/.mastermind/VERSION" ] && echo y)" "y"
is "records the version it installed" "$(cat "$P/.mastermind/VERSION" 2>/dev/null)" "$(cat "$REPO/VERSION")"
yes_ "links point at the LOCAL brain" "$(readlink "$P/.claude/skills/build" | grep -o '\.mastermind/skills/build')"
yes_ "no ~/.mastermind left in the copied docs" "$([ "$(grep -rl '~/\.mastermind' "$P/.mastermind" 2>/dev/null | wc -l | tr -d ' ')" = 0 ] && echo y)"

run "$P" claude >/dev/null 2>&1
run "$P" claude >/dev/null 2>&1
is "idempotent: no duplicate aliases" "$(ls "$P/.claude/skills" | wc -l | tr -d ' ')" "$N_SKILLS"
yes_ "stays isolated without the flag" "$(readlink "$P/.claude/skills/build" | grep -o '\.mastermind/skills/build')"

echo "── isolated: no field is shipped, the project builds its own, and keeps it"
is "scaffold shipped"        "$([ -d "$P/.mastermind/engineering/fields/_template" ] && echo y)" "y"
is "no default field shipped" "$([ -d "$P/.mastermind/engineering/fields/frontend" ] && echo present || echo absent)" "absent"
mkdir -p "$P/.mastermind/engineering/fields/myfield"
echo "- OUR LESSON"     > "$P/.mastermind/engineering/fields/myfield/lessons.md"
echo "- OUR STACK RULE" > "$P/.mastermind/engineering/fields/myfield/stack-defaults.md"
echo "OUR FIELD CHOICE" >> "$P/.mastermind/engineering/active-field.md"
echo "TAMPERED" >> "$P/.mastermind/engineering/core/mindset.md"
run "$P" claude >/dev/null 2>&1
is "project lessons preserved"     "$(count_in "$P/.mastermind/engineering/fields/myfield/lessons.md" 'OUR LESSON')" "1"
is "project stack rules preserved" "$(count_in "$P/.mastermind/engineering/fields/myfield/stack-defaults.md" 'OUR STACK RULE')" "1"
is "project field choice preserved" "$(grep -c 'OUR FIELD CHOICE' "$P/.mastermind/engineering/active-field.md")" "1"
is "engine refreshed, not preserved" "$(grep -c 'TAMPERED' "$P/.mastermind/engineering/core/mindset.md")" "0"

echo "── isolated: real isolation, one project cannot change another"
is "the shared clone is untouched" "$(grep -rc 'OUR LESSON\|TAMPERED\|OUR FIELD CHOICE' "$REPO/engineering/core" | grep -cv ':0$')" "0"
yes_ "--isolated --global is refused" "$( (cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" --isolated --global 2>&1 || true) | grep -o 'per-project by definition')"
is "uninstall keeps the project's own brain" "$([ -d "$P/.mastermind" ] && echo kept)" "kept"

echo "── isolated: never write through a symlinked .mastermind (data loss)"
P=$(proj symguard); PRECIOUS="$TMP/precious"; rm -rf "$PRECIOUS"; mkdir -p "$PRECIOUS"
echo IRREPLACEABLE > "$PRECIOUS/my-thing.md"
ln -s "$PRECIOUS" "$P/.mastermind"
run "$P" --isolated claude >/dev/null 2>&1 || true
is "user's files survive"        "$(cat "$PRECIOUS/my-thing.md" 2>/dev/null)" "IRREPLACEABLE"
is "nothing was written through" "$(ls "$PRECIOUS" | wc -l | tr -d ' ')" "1"
yes_ "and it refuses out loud"   "$(run "$P" --isolated claude 2>&1 | grep -oE 'is a symlink|resolves outside the project' | head -1)"
# A symlinked .mastermind must never flip a project into isolated mode either.
yes_ "no silent isolation via symlink" "$(run "$P" claude 2>&1 | grep -o 'is a symlink' || echo skipped)"

echo "── isolated: the copied brain has no dangling references"
P=$(proj isodeps); run "$P" --isolated claude agents >/dev/null 2>&1
is "ROUTER.md copied" "$([ -f "$P/.mastermind/engineering/ROUTER.md" ] && echo y)" "y"
is "AGENTS.md copied" "$([ -e "$P/.mastermind/AGENTS.md" ] && echo y)" "y"

echo "── isolated: --check works without naming a tool"
yes_ "doctor sees the isolated install" "$(run "$P" --check 2>&1 | grep -o 'healthy here')"
echo "0.0.1" > "$P/.mastermind/VERSION"
yes_ "and reports version drift" "$(run "$P" --check 2>&1 | grep -o 'this project is on v0.0.1')"

echo "── isolated: OWNED files survive at ANY depth"
P=$(proj isonest); run "$P" --isolated claude >/dev/null 2>&1
mkdir -p "$P/.mastermind/engineering/fields/frontend/ui-ux-pro-max"
echo NESTED > "$P/.mastermind/engineering/fields/frontend/ui-ux-pro-max/lessons.md"
run "$P" claude >/dev/null 2>&1
is "nested lessons.md preserved" "$(cat "$P/.mastermind/engineering/fields/frontend/ui-ux-pro-max/lessons.md" 2>/dev/null)" "NESTED"

echo "── isolated: a project's OWN skills/agents inside the brain survive an update"
P=$(proj isoadd); run "$P" --isolated claude >/dev/null 2>&1
mkdir -p "$P/.mastermind/skills/our-skill" "$P/.mastermind/agents"
printf 'OUR SKILL BODY\n'                 > "$P/.mastermind/skills/our-skill/SKILL.md"
printf 'OUR AGENT\n'                      > "$P/.mastermind/agents/our-agent.md"
printf 'OUR CORE NOTE\n'                  > "$P/.mastermind/engineering/core/our-note.md"
printf 'see ~/.mastermind for details\n'  > "$P/.mastermind/skills/our-skill/NOTES.md"
run "$P" claude >/dev/null 2>&1
is "project skill survives update" "$(count_in "$P/.mastermind/skills/our-skill/SKILL.md" 'OUR SKILL BODY')" "1"
is "project agent survives update" "$(count_in "$P/.mastermind/agents/our-agent.md" 'OUR AGENT')" "1"
is "project file in core survives" "$(count_in "$P/.mastermind/engineering/core/our-note.md" 'OUR CORE NOTE')" "1"
# the installer rewrites ~/.mastermind paths only in files IT shipped, never a project's prose
is "project notes not rewritten"   "$(count_in "$P/.mastermind/skills/our-skill/NOTES.md" '~/\.mastermind')" "1"
# …while the engine itself is still genuinely refreshed and intact
is "shipped skill still installed" "$([ -f "$P/.mastermind/skills/build/SKILL.md" ] && echo y)" "y"
yes_ "hook stays executable"       "$([ -x "$P/.mastermind/hooks/session-start.sh" ] && echo yes)"
yes_ "AGENTS.md stays a symlink"   "$([ -L "$P/.mastermind/AGENTS.md" ] && echo yes)"
# a retired upstream file is still removed (the manifest must keep doing its job)
printf 'x\n' > "$P/.mastermind/skills/ghost-skill.md"
printf 'skills/ghost-skill.md\n' >> "$P/.mastermind/.manifest"
run "$P" claude >/dev/null 2>&1
is "retired shipped file still removed" "$([ -e "$P/.mastermind/skills/ghost-skill.md" ] && echo present || echo gone)" "gone"

echo "── per-project installs are ISOLATED by default"
P=$(proj defiso); run "$P" agents claude >/dev/null 2>&1
is "plain install creates its own brain" "$([ -f "$P/.mastermind/VERSION" ] && echo y)" "y"
yes_ "and wires to it" "$(readlink "$P/AGENTS.md" | grep -o '\.mastermind/AGENTS\.md')"

echo "── --shared opts back into the single shared clone"
P=$(proj sharedreg); run "$P" --shared agents >/dev/null 2>&1
is "no engine copied into the project" \
   "$([ -e "$P/.mastermind/VERSION" ] || [ -d "$P/.mastermind/skills" ] && echo engine || echo none)" "none"
is "but project state is seeded" "$([ -f "$P/.mastermind/brief.md" ] && echo yes || echo no)" "yes"
is "AGENTS.md targets the clone" "$(readlink "$P/AGENTS.md")" "$REPO/AGENTS.md"
yes_ "--check calls it healthy"  "$(run "$P" --check --shared agents 2>&1 | grep -o 'healthy here')"
# `codex` was the old name for this exact target: the alias keeps old commands working.
P=$(proj alias); run "$P" --shared codex >/dev/null 2>&1
is "codex alias still wires AGENTS.md" "$(readlink "$P/AGENTS.md")" "$REPO/AGENTS.md"

echo "── monorepo: one brain per REPO, wherever you run install from"
P=$(proj mono); mkdir -p "$P/apps/web/src"; (cd "$P" && git init -q .)
(cd "$P/apps/web/src" && HOME="$SANDBOX_HOME" "$INSTALL" --isolated claude >/dev/null 2>&1)
is "brain created at the repo root" "$([ -f "$P/.mastermind/VERSION" ] && echo y)" "y"
is "no stray brain in the subdir"   "$([ -e "$P/apps/web/src/.mastermind" ] && echo stray || echo none)" "none"
is "tools wired at the repo root"   "$([ -d "$P/.claude" ] && echo y)" "y"
is "no stray .claude in the subdir" "$([ -e "$P/apps/web/src/.claude" ] && echo stray || echo none)" "none"
run "$P" claude >/dev/null 2>&1
is "running from the root is a no-op" "$(find "$P" -path '*/.mastermind/VERSION' | wc -l | tr -d ' ')" "1"

echo "── isolated update: retire what upstream dropped, keep what the project added"
CLONE="$TMP/clone"; rm -rf "$CLONE"; cp -R "$REPO/." "$CLONE/" 2>/dev/null
P=$(proj retire)
(cd "$P" && HOME="$SANDBOX_HOME" "$CLONE/install.sh" --isolated claude >/dev/null 2>&1)
# The project's own field: what `init` builds in real use.
mkdir -p "$P/.mastermind/engineering/fields/myfield"
echo "OURS" > "$P/.mastermind/engineering/fields/myfield/our-team-notes.md"
echo "OUR LESSON" >> "$P/.mastermind/engineering/fields/myfield/lessons.md"
rm -rf "$CLONE/skills/prototype"
(cd "$P" && HOME="$SANDBOX_HOME" "$CLONE/install.sh" claude >/dev/null 2>&1)
is "retired skill removed"     "$([ -d "$P/.mastermind/skills/prototype" ] && echo kept || echo gone)" "gone"
is "project's own doc kept"    "$(cat "$P/.mastermind/engineering/fields/myfield/our-team-notes.md" 2>/dev/null)" "OURS"
is "project's lesson kept"     "$(count_in "$P/.mastermind/engineering/fields/myfield/lessons.md" 'OUR LESSON')" "1"
(cd "$P" && HOME="$SANDBOX_HOME" "$CLONE/install.sh" claude >/dev/null 2>&1)
(cd "$P" && HOME="$SANDBOX_HOME" "$CLONE/install.sh" claude >/dev/null 2>&1)
is "still kept after repeat updates" "$(count_in "$P/.mastermind/engineering/fields/myfield/lessons.md" 'OUR LESSON')" "1"
mkdir -p "$P/.mastermind/engineering/fields/frontend"
echo "LEGACY" > "$P/.mastermind/engineering/fields/frontend/web-animations.md"
printf 'engineering/fields/frontend/web-animations.md\n' >> "$P/.mastermind/.manifest"
(cd "$P" && HOME="$SANDBOX_HOME" "$CLONE/install.sh" claude >/dev/null 2>&1)
is "a pre-0.27 pack is never gutted" "$(cat "$P/.mastermind/engineering/fields/frontend/web-animations.md" 2>/dev/null)" "LEGACY"

echo "── project under \$HOME with the shared clone present: must NOT resolve PROJECT=\$HOME"
AH="$TMP/anchorhome"; mkdir -p "$AH/Projects/proj/src"
ln -sfn "$REPO" "$AH/.mastermind"                       # the shared clone, as a symlink
(cd "$AH" && HOME="$AH" "$REPO/install.sh" --global claude >/dev/null 2>&1)  # global wiring exists
(cd "$AH/Projects/proj" && HOME="$AH" "$REPO/install.sh" claude >/dev/null 2>&1)
is "install wired the project, not \$HOME" "$([ -d "$AH/Projects/proj/.mastermind" ] && echo y)" "y"
(cd "$AH/Projects/proj/src" && HOME="$AH" "$REPO/install.sh" --uninstall claude >/dev/null 2>&1)
is "project uninstall left GLOBAL intact"  "$([ -e "$AH/.claude/CLAUDE.md" ] && echo y)" "y"

echo "── anchor block editor must not touch the project's own marker-like content"
P=$(proj blk); mkdir -p "$P/apps/web"; (cd "$P" && git init -q .)
run "$P" claude >/dev/null 2>&1
printf '# ours\nwe mention <!-- MASTERMIND:START --> and <!-- MASTERMIND:END --> in prose\nkeep me\n' > "$P/apps/web/CLAUDE.md"
printf 'apps/web/**  web\n' > "$P/.mastermind/routes.map"
run "$P" claude >/dev/null 2>&1
is "their inline mention survives" "$(grep -c 'we mention' "$P/apps/web/CLAUDE.md")" "1"
is "their trailing line survives"  "$(grep -c 'keep me' "$P/apps/web/CLAUDE.md")" "1"
# a lone START (half-edited file) must not delete everything after it on uninstall
printf 'top\n<!-- MASTERMIND:START -->\nMUST SURVIVE\nbottom\n' > "$P/apps/web/CLAUDE.md"
run "$P" --uninstall claude >/dev/null 2>&1
is "lone-START content preserved" "$(grep -c 'MUST SURVIVE' "$P/apps/web/CLAUDE.md" 2>/dev/null)" "1"

echo "── CRLF routes.map must not create a carriage-return context"
P=$(proj crlf); mkdir -p "$P/apps/web"; (cd "$P" && git init -q .)
run "$P" claude >/dev/null 2>&1
printf 'apps/web/**  web\r\n' > "$P/.mastermind/routes.map"
run "$P" claude >/dev/null 2>&1
is "context name has no CR" "$(ls "$P/.mastermind/engineering/contexts" | grep -c "$(printf '\r')")" "0"
yes_ "CRLF map still validates in --check" "$(run "$P" --check claude 2>&1 | grep -o 'route apps/web/ → web')"

echo "── field+context: routes.map compiles into tool-enforced per-app anchors"
P=$(proj fc); mkdir -p "$P/apps/web/src" "$P/apps/api" "$P/packages/ui"; (cd "$P" && git init -q .)
run "$P" --isolated claude >/dev/null 2>&1
mkdir -p "$P/.mastermind/engineering/fields/webstack"
printf '# webstack field\n' > "$P/.mastermind/engineering/fields/webstack/field.md"
printf 'apps/web/**  web\napps/api/**  api\npackages/**  shared\n' > "$P/.mastermind/routes.map"
run "$P" claude >/dev/null 2>&1
is "context dir created per route" "$(ls "$P/.mastermind/engineering/contexts" | wc -l | tr -d ' ')" "3"
is "web anchor written"  "$([ -f "$P/apps/web/CLAUDE.md" ] && echo y)" "y"
is "web AGENTS.md written" "$([ -f "$P/apps/web/AGENTS.md" ] && echo y)" "y"
yes_ "cursor rule is glob-scoped" "$(grep -o 'globs: apps/web/\*\*' "$P/apps/web/.cursor/rules/mastermind.mdc")"
yes_ "relative import depth is right (../../)" "$(grep -o '@\.\./\.\./\.mastermind/CLAUDE.md' "$P/apps/web/CLAUDE.md")"
yes_ "shared at depth 1 uses ../" "$(grep -o '@\.\./\.mastermind/CLAUDE.md' "$P/packages/CLAUDE.md")"
# every @import must resolve from the anchor's own directory
BROKEN=0; for imp in $(grep -oE '@[^ ]+' "$P/apps/web/CLAUDE.md" | sed 's/@//'); do [ -f "$P/apps/web/$imp" ] || BROKEN=1; done
is "every web @import resolves" "$BROKEN" "0"

echo "── field+context: per-app lessons stay isolated"
echo "web-only" >> "$P/.mastermind/engineering/contexts/web/lessons.md"
is "lesson in web" "$(grep -c 'web-only' "$P/.mastermind/engineering/contexts/web/lessons.md")" "1"
is "NOT in api"     "$(grep -c 'web-only' "$P/.mastermind/engineering/contexts/api/lessons.md")" "0"

echo "── field+context: anchors are clobber-safe and idempotent"
printf '# my own web notes\nuse internal auth\n' > "$P/apps/web/CLAUDE.md"
run "$P" claude >/dev/null 2>&1; run "$P" claude >/dev/null 2>&1
is "the project's own content kept" "$(grep -c 'internal auth' "$P/apps/web/CLAUDE.md")" "1"
is "exactly one generated block"    "$(grep -c 'MASTERMIND:START' "$P/apps/web/CLAUDE.md")" "1"
is "imports not duplicated"          "$(grep -c '@\.\./\.\./\.mastermind/CLAUDE.md' "$P/apps/web/CLAUDE.md")" "1"

echo "── field+context: --check validates routes; a bad field is caught"
yes_ "healthy routes pass --check" "$(run "$P" --check claude 2>&1 | grep -o 'route apps/web/ → web')"
sed -i.bak 's/^field:.*/field: nope/' "$P/.mastermind/engineering/contexts/web/field.md"; rm -f "$P/.mastermind/engineering/contexts/web/field.md.bak"
yes_ "missing field fails --check"  "$(run "$P" --check claude 2>&1 | grep -o 'missing field')"

echo "── field+context: uninstall strips anchors, keeps the project's own content"
printf '# my own web notes\nuse internal auth\n' > "$P/apps/web/CLAUDE.md"
sed -i.bak 's/^field:.*/field: frontend/' "$P/.mastermind/engineering/contexts/web/field.md"; rm -f "$P/.mastermind/engineering/contexts/web/field.md.bak"
run "$P" claude >/dev/null 2>&1
run "$P" --uninstall claude >/dev/null 2>&1
is "generated block removed" "$(grep -c 'MASTERMIND:START' "$P/apps/web/CLAUDE.md" 2>/dev/null)" "0"
is "unneeded AGENTS anchor removed with the last tool" "$(count_in "$P/apps/web/AGENTS.md" 'MASTERMIND:START')" "0"
is "their content survives"  "$(count_in "$P/apps/web/CLAUDE.md" 'internal auth')" "1"
is "cursor rule removed"     "$([ -f "$P/apps/web/.cursor/rules/mastermind.mdc" ] && echo present || echo gone)" "gone"

echo "── single-project (no routes.map) is untouched: the common case stays simple"
P=$(proj single); (cd "$P" && git init -q .)
run "$P" --isolated claude >/dev/null 2>&1
is "no contexts dir created" "$([ -d "$P/.mastermind/engineering/contexts" ] && echo made || echo none)" "none"
is "no per-app anchors"      "$(find "$P" -name CLAUDE.md ! -path '*/.mastermind/*' ! -path '*/.claude/*' | wc -l | tr -d ' ')" "0"

echo "── field+context: a malformed routes.map line warns and skips, never aborts"
P=$(proj badroute); mkdir -p "$P/apps/a"; (cd "$P" && git init -q .)
run "$P" claude >/dev/null 2>&1
# a field must exist for a context to attach to (init's job; none ships as of 0.27.0)
mkdir -p "$P/.mastermind/engineering/fields/webstack"
printf '# webstack field\n' > "$P/.mastermind/engineering/fields/webstack/field.md"
printf 'apps/a/**\n' > "$P/.mastermind/routes.map"        # context name missing
run "$P" claude >/dev/null 2>&1
is "install still completes"     "$([ -d "$P/.claude/skills" ] && echo y)" "y"
is "no garbage '**' context dir" "$([ -d "$P/.mastermind/engineering/contexts/apps" ] && echo litter || echo clean)" "clean"
printf 'apps/a/**  foo/bar\n' > "$P/.mastermind/routes.map"   # slash in the name
run "$P" claude >/dev/null 2>&1
is "slash-name skipped, still completes" "$([ -d "$P/.claude/skills" ] && echo y)" "y"
printf 'apps/a/**  web\n' > "$P/.mastermind/routes.map"    # valid again
run "$P" claude >/dev/null 2>&1
yes_ "a valid rule still generates its anchor" "$(grep -o 'MASTERMIND:START' "$P/apps/a/CLAUDE.md" | head -1)"
is "new anchor starts at the marker, no leading blank" "$(sed -n '1p' "$P/apps/a/CLAUDE.md")" "$(printf '<!-- MASTERMIND:START -->')"

echo "── cursor gets the kernel itself, not a pointer to it"
P=$(proj curkernel); run "$P" cursor >/dev/null 2>&1
is "kernel inlined, not pointed at" "$(grep -c 'Prime directives' "$P/.cursor/rules/mastermind.mdc" 2>/dev/null | tr -d ' ')" "1"
is "alwaysApply frontmatter intact" "$(head -2 "$P/.cursor/rules/mastermind.mdc" 2>/dev/null | tail -1)" "alwaysApply: true"
KLINES=$(wc -l < "$REPO/CLAUDE.md" | tr -d ' ')
yes_ "rule is kernel-sized, not a stub" "$([ "$(wc -l < "$P/.cursor/rules/mastermind.mdc" | tr -d ' ')" -ge "$KLINES" ] && echo y)"
# A stale pointer-only rule must be reported as broken, not called healthy.
printf -- '---\nalwaysApply: true\n---\nFollow ~/.mastermind/CLAUDE.md\n' > "$P/.cursor/rules/mastermind.mdc"
yes_ "--check flags the old pointer-only rule" "$(run "$P" --check cursor 2>&1 | grep -o 'pointer-only' | head -1)"
run "$P" cursor >/dev/null 2>&1

echo "── cursor gets the FIELD PACK too, not just the kernel"
is "no field yet → no field rule" "$([ -f "$P/.cursor/rules/mastermind-field.mdc" ] && echo present || echo absent)" "absent"
mkdir -p "$P/.mastermind/engineering/fields/webstack"
printf 'DEFAULT-MARKER\n' > "$P/.mastermind/engineering/fields/webstack/stack-defaults.md"
printf 'LESSON-MARKER\n'  > "$P/.mastermind/engineering/fields/webstack/lessons.md"
printf '# Active Field\n\n- **Field pack:** `engineering/fields/webstack/`\n- **Level:** 1.\n' \
  > "$P/.mastermind/engineering/active-field.md"
run "$P" cursor >/dev/null 2>&1
is "field rule written"          "$([ -f "$P/.cursor/rules/mastermind-field.mdc" ] && echo y)" "y"
is "alwaysApply on the field rule" "$(head -2 "$P/.cursor/rules/mastermind-field.mdc" 2>/dev/null | tail -1)" "alwaysApply: true"
is "stack-defaults inlined"      "$(grep -c 'DEFAULT-MARKER' "$P/.cursor/rules/mastermind-field.mdc" | tr -d ' ')" "1"
is "lessons inlined"             "$(grep -c 'LESSON-MARKER' "$P/.cursor/rules/mastermind-field.mdc" | tr -d ' ')" "1"
# and it must retire itself when the field goes away, or Cursor keeps serving a dead pack
printf '# Active Field\n\n- **Field pack:** _none_\n- **Level:** 0.\n' > "$P/.mastermind/engineering/active-field.md"
run "$P" cursor >/dev/null 2>&1
is "field rule removed when field goes" "$([ -f "$P/.cursor/rules/mastermind-field.mdc" ] && echo present || echo gone)" "gone"
is "re-running install repairs it" "$(grep -c 'Prime directives' "$P/.cursor/rules/mastermind.mdc" | tr -d ' ')" "1"

echo "── cursor hooks.json"
P=$(proj cursor); run "$P" cursor >/dev/null
is "sessionStart + preCompact wired" "$(python3 -c "import json;d=json.load(open('$P/.cursor/hooks.json'));print(len(d['hooks']['sessionStart'])+len(d['hooks']['preCompact']))" 2>/dev/null)" "2"

echo "── codex: per-project reads the repo's own AGENTS.md"
P=$(proj codexproj); CH="$TMP/codexhome"; mkdir -p "$CH"
(cd "$P" && HOME="$SANDBOX_HOME" CODEX_HOME="$CH" "$INSTALL" codex >/dev/null 2>&1) || true
yes_ "AGENTS.md wired by name 'codex'" "$([ -L "$P/AGENTS.md" ] && echo yes)"
is   "and CODEX_HOME untouched in project scope" "$([ -e "$CH/AGENTS.md" ] && echo present || echo none)" "none"

echo "── codex: --global wires CODEX_HOME/AGENTS.md, honouring CODEX_HOME"
P=$(proj codexglob); GH2="$TMP/cghome"; CH2="$TMP/cgcodex"; mkdir -p "$GH2" "$CH2"
(cd "$P" && HOME="$GH2" CODEX_HOME="$CH2" "$INSTALL" --global codex >/dev/null 2>&1) || true
yes_ "CODEX_HOME/AGENTS.md linked to the brain" "$([ -L "$CH2/AGENTS.md" ] && echo yes)"
P=$(proj codexempty); CH3="$TMP/cgempty"; GH3="$TMP/cgemptyhome"; mkdir -p "$CH3" "$GH3"; : > "$CH3/AGENTS.md"
(cd "$P" && HOME="$GH3" CODEX_HOME="$CH3" "$INSTALL" --global codex >/dev/null 2>&1) || true
yes_ "an empty AGENTS.md is replaced by the link, not appended to" "$([ -L "$CH3/AGENTS.md" ] && echo yes)"
# A real file the user wrote is still never clobbered.
P=$(proj codexown); CH4="$TMP/cgown"; GH4="$TMP/cgownhome"; mkdir -p "$CH4" "$GH4"; printf 'MY OWN RULES\n' > "$CH4/AGENTS.md"
(cd "$P" && HOME="$GH4" CODEX_HOME="$CH4" "$INSTALL" --global codex >/dev/null 2>&1) || true
yes_ "their own global AGENTS.md content survives" "$(grep -c 'MY OWN RULES' "$CH4/AGENTS.md")"
yes_ "and gets a MasterMind pointer appended"     "$(grep -c 'mastermind/CLAUDE.md' "$CH4/AGENTS.md")"
# AGENTS.override.md wins in Codex, so a green ✓ there would be a lie.
P=$(proj codexovr); CH5="$TMP/cgovr"; GH5="$TMP/cgovrhome"; mkdir -p "$CH5" "$GH5"; printf 'OVERRIDE\n' > "$CH5/AGENTS.override.md"
OUT5=$( (cd "$P" && HOME="$GH5" CODEX_HOME="$CH5" "$INSTALL" --global codex 2>&1) || true )
yes_ "warns that AGENTS.override.md takes priority" "$(printf '%s' "$OUT5" | grep -o 'AGENTS.override.md')"
yes_ "discloses the global-merge bug"               "$(printf '%s' "$OUT5" | grep -o 'openai/codex#27705')"

echo "── codex: --global --uninstall removes only our link"
(cd "$P" && HOME="$GH2" CODEX_HOME="$CH2" "$INSTALL" --global --uninstall >/dev/null 2>&1) || true
is "our global codex link removed" "$([ -e "$CH2/AGENTS.md" ] && echo present || echo gone)" "gone"
(cd "$P" && HOME="$GH4" CODEX_HOME="$CH4" "$INSTALL" --global --uninstall >/dev/null 2>&1) || true
yes_ "their own file left in place" "$(grep -c 'MY OWN RULES' "$CH4/AGENTS.md")"

echo "── retired tools are declined cleanly, never half-wired"
P=$(proj retired)
yes_ "gemini explains itself"  "$(run "$P" gemini 2>&1 | grep -o 'no longer wired automatically')"
is   "and writes no GEMINI.md" "$([ -e "$P/GEMINI.md" ] && echo present || echo none)" "none"
yes_ "copilot explains itself" "$(run "$P" copilot 2>&1 | grep -o 'no longer wired automatically')"
is   "and writes no copilot file" "$([ -e "$P/.github/copilot-instructions.md" ] && echo present || echo none)" "none"

# The message printed and then the run died, so assert the status, not just the output.
for retired in gemini copilot; do
  P=$(proj "only$retired")
  run "$P" "$retired" >/dev/null 2>&1
  is "$retired alone still finishes"     "$?" "0"
  is "$retired alone records the install" "$([ -f "$P/.mastermind/.installed" ] && echo yes || echo NO)" "yes"
  is "$retired alone records no tools"    "$(sed -n 's/^tools=//p' "$P/.mastermind/.installed" 2>/dev/null)" ""
done
P=$(proj onlyretiredboth)
run "$P" gemini copilot >/dev/null 2>&1
is "both retired together still finishes" "$?" "0"

echo "── AGENTS.md is wired even with no tool installed"
# The brain is plain Markdown; AGENTS.md is how every tool we don't wire natively reads it.
P=$(proj noagent); mkdir -p "$TMP/emptyhome"
(cd "$P" && HOME="$TMP/emptyhome" "$INSTALL" >/dev/null 2>&1) || true
is "AGENTS.md wired anyway" "$([ -e "$P/AGENTS.md" ] && echo y || echo n)" "y"

echo "── routes.map may not escape the project"
P=$(proj traversal); mkdir -p "$TMP/outside-victim"
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" >/dev/null 2>&1) || true
printf '../outside-victim/**   escape\n' > "$P/.mastermind/routes.map"
out="$(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" 2>&1)" || true
yes_ "traversal rule is refused" "$(printf '%s' "$out" | grep -o "may not contain")"
is   "nothing written outside the project" "$(ls -A "$TMP/outside-victim" | wc -l | tr -d ' ')" "0"
printf '/etc/**   absolute\n' > "$P/.mastermind/routes.map"
out="$(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" 2>&1)" || true
yes_ "absolute route is refused" "$(printf '%s' "$out" | grep -o "must be a relative path")"

echo "── a symlinked path inside the brain is never written through"
P=$(proj symlinked); mkdir -p "$TMP/brain-victim"
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" >/dev/null 2>&1) || true
touch "$TMP/brain-victim/precious.txt"
rm -rf "$P/.mastermind/skills" && ln -s "$TMP/brain-victim" "$P/.mastermind/skills"
out="$(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" 2>&1)" || true
yes_ "escaping symlink is refused" "$(printf '%s' "$out" | grep -o "points outside the brain")"
is   "the symlink target is untouched" "$([ -f "$TMP/brain-victim/precious.txt" ] && echo kept || echo GONE)" "kept"
P=$(proj ownlink)
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" >/dev/null 2>&1) || true
out="$(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" 2>&1)" || true
is "re-install still succeeds with our own symlinks" "$(printf '%s' "$out" | grep -c 'Refusing to write through')" "0"

# `a -> b` has no ".." in it, and `b` can be the link that leaves.
echo "── a chain of symlinks cannot walk out of the brain one innocent hop at a time"
P=$(proj chain2); mkdir -p "$TMP/out2"; printf 'ORIGINAL' > "$TMP/out2/sentinel"
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" >/dev/null 2>&1) || true
rm -f "$P/.mastermind/.manifest.hashes"
ln -s hop "$P/.mastermind/.manifest.hashes"; ln -s "$TMP/out2/sentinel" "$P/.mastermind/hop"
out="$(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" 2>&1)" || true
yes_ "two-hop chain is refused"      "$(printf '%s' "$out" | grep -o 'points outside the brain')"
is   "its target is untouched"       "$(cat "$TMP/out2/sentinel")" "ORIGINAL"

P=$(proj chain3); mkdir -p "$TMP/out3"; printf 'ORIGINAL' > "$TMP/out3/sentinel"
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" >/dev/null 2>&1) || true
rm -f "$P/.mastermind/routes.map"
ln -s h1 "$P/.mastermind/routes.map"; ln -s h2 "$P/.mastermind/h1"; ln -s "$TMP/out3/sentinel" "$P/.mastermind/h2"
out="$(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" 2>&1)" || true
yes_ "three-hop chain is refused"    "$(printf '%s' "$out" | grep -o 'points outside the brain')"
is   "its target is untouched"       "$(cat "$TMP/out3/sentinel")" "ORIGINAL"

# A cycle resolves to nothing at all, which must refuse rather than loop or fall through.
P=$(proj chaincycle)
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" >/dev/null 2>&1) || true
rm -f "$P/.mastermind/routes.map"
ln -s cyb "$P/.mastermind/routes.map"; ln -s cya "$P/.mastermind/cyb"; ln -s cyb "$P/.mastermind/cya"
out="$(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" 2>&1)" || true
yes_ "a cyclic chain is refused"     "$(printf '%s' "$out" | grep -o 'broken or cyclic symlink chain')"

# The mirror image: a link that does not exist yet is normal, since the installer creates it.
P=$(proj chaindangling)
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" >/dev/null 2>&1) || true
rm -f "$P/.mastermind/routes.map"; ln -s notyet "$P/.mastermind/routes.map"
out="$(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" 2>&1)"; rc=$?
is "a dangling link inside the brain still installs" "$rc" "0"

echo "── uninstall gives back what install displaced"
H="$TMP/restore-home"; mkdir -p "$H/.claude"
printf '# global notes\nprecious\n' > "$H/.claude/CLAUDE.md"
(HOME="$H" "$INSTALL" --global >/dev/null 2>&1) || true
(HOME="$H" "$INSTALL" --global --uninstall >/dev/null 2>&1) || true
is "a displaced file is restored" "$(grep -c 'precious' "$H/.claude/CLAUDE.md" 2>/dev/null || echo 0)" "1"
is "no backup left orphaned" "$(ls -1 "$H/.claude/"CLAUDE.md.bak-* 2>/dev/null | wc -l | tr -d ' ')" "0"

echo "── another tool's session hook is never deleted"
P=$(proj foreignhook); mkdir -p "$P/.claude"
printf '{"hooks":{"SessionStart":[{"matcher":"startup","hooks":[{"type":"command","command":"/their/tool/session-start.sh"}]}]}}\n' > "$P/.claude/settings.json"
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" >/dev/null 2>&1) || true
is "theirs survives install" "$(grep -c '/their/tool/session-start.sh' "$P/.claude/settings.json")" "1"
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" --uninstall >/dev/null 2>&1) || true
is "theirs survives uninstall" "$(grep -c '/their/tool/session-start.sh' "$P/.claude/settings.json")" "1"

echo "── uninstall works when the project path crosses a symlink"
LINKDIR="$TMP/real-proj"; mkdir -p "$LINKDIR"
ln -sfn "$LINKDIR" "$TMP/via-link"
(cd "$TMP/via-link" && git init -q . && HOME="$SANDBOX_HOME" "$INSTALL" >/dev/null 2>&1) || true
is "installed through the symlinked path" "$([ -e "$TMP/via-link/AGENTS.md" ] && echo y || echo n)" "y"
out="$(cd "$TMP/via-link" && HOME="$SANDBOX_HOME" "$INSTALL" --uninstall 2>&1)" || true
is "uninstall removed the links"  "$([ -e "$TMP/via-link/AGENTS.md" ] && echo left || echo gone)" "gone"
case "$out" in *"removed 0 link"*) bad "uninstall claimed success while removing nothing";; *) ok "uninstall reported real removals";; esac

if [ -s "$CANARY_LOG" ]; then
  while IFS= read -r line; do no "a run wrote OUTSIDE every fixture: $line"; done < "$CANARY_LOG"
fi

echo
if [ "$FAIL" -eq 0 ]; then printf '%s✓ %d passed%s\n' "$g" "$PASS" "$x"; exit 0
else printf '%s✖ %d failed, %d passed%s\n' "$r" "$FAIL" "$PASS" "$x"; exit 1; fi
