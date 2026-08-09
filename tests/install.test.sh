#!/usr/bin/env bash
#
# Regression tests for install.sh — the highest-risk file we ship.
#
# Every scenario here is one that has actually broken, or that guards a promise we make:
# never destroy a user's files, never lose a MasterMind capability, always be idempotent.
#
#   ./tests/install.test.sh
#
# Runs entirely in a temp dir. Touches nothing in $HOME.
#
# TWO harness disciplines, each learned from a critical bug this suite once MISSED:
#  1. For path-resolution, nest the project INSIDE the sandbox HOME with a $HOME/.mastermind
#     symlink present. Sandboxing HOME as a *sibling* of the project can't catch a walk-up
#     that ascends into HOME (which no-op'd install and destroyed global wiring on uninstall).
#  2. For any in-place file editor, fuzz it with the project's own content that CONTAINS our
#     markers, a lone/unbalanced marker, and a file with no trailing newline — that's where a
#     block editor silently deleted user data.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Overridable so a new assertion can be pointed at an older installer to prove it actually
# catches the defect it was written for. A test that passes against the buggy build is decoration.
INSTALL="${MM_INSTALL_UNDER_TEST:-$REPO/install.sh}"
TMP="$(mktemp -d)"
# -P: on macOS both /tmp and mktemp's /var/folders are symlinks to /private/..., and comparing
# a logical path against a resolved one is how two path bugs shipped. Fixtures use the real path.
TMP_REAL="$(cd "$TMP" && pwd -P)"

PASS=0; FAIL=0
g=$'\033[0;32m'; r=$'\033[0;31m'; x=$'\033[0m'
ok()   { printf '  %s✓%s %s\n' "$g" "$x" "$1"; PASS=$((PASS+1)); }
no()   { printf '  %s✖%s %s\n' "$r" "$x" "$1"; FAIL=$((FAIL+1)); }
is()   { if [ "$2" = "$3" ]; then ok "$1"; else no "$1 (got '$2', want '$3')"; fi; }
yes_() { if [ -n "$2" ]; then ok "$1"; else no "$1"; fi; }

proj() { local d="$TMP/$1"; rm -rf "$d"; mkdir -p "$d"; printf '%s' "$d"; }

# EVERY invocation runs under a sandboxed HOME. install.sh always writes `$HOME/.mastermind`,
# and `--global` writes `~/.claude` / `~/.codex` — so without this the suite mutates the
# developer's own setup. A `--global --uninstall` case once wiped a real global install.
# This is what makes the "touches nothing in $HOME" promise at the top of this file true.
SANDBOX_HOME="$TMP/home"; mkdir -p "$SANDBOX_HOME"
# install.sh repoints $HOME/.mastermind at whatever repo runs it. A case that forgets
# HOME="$SANDBOX_HOME" therefore rewires the developer's real global brain — it happened twice.
# Fail loudly instead of silently damaging the machine.
REAL_HOME_LINK="$(readlink "$HOME/.mastermind" 2>/dev/null || echo none)"
trap 'now="$(readlink "$HOME/.mastermind" 2>/dev/null || echo none)"
      if [ "$now" != "$REAL_HOME_LINK" ]; then
        printf "\n\033[0;31m✖ a test modified the real ~/.mastermind (%s → %s) — restoring\033[0m\n" "$REAL_HOME_LINK" "$now" >&2
        [ "$REAL_HOME_LINK" = none ] || ln -sfn "$REAL_HOME_LINK" "$HOME/.mastermind"
      fi
      rm -rf "$TMP"' EXIT
# ── The canary ────────────────────────────────────────────────────────────────
# Every other test asserts what SHOULD exist inside its own fixture. None of them can see a
# write that lands somewhere nobody thought to look, which is exactly how an installer that
# followed a repo-supplied `.claude -> /elsewhere` put 28 files outside the project and exited
# 0 while 179 tests stayed green. This directory sits outside every fixture and is checked
# after EVERY installer run: a stray write fails the suite whether or not anyone predicted
# that particular escape route.
CANARY="$TMP_REAL/canary"; mkdir -p "$CANARY"; CANARY_LOG="$TMP_REAL/canary.log"
canary_check() {
  local found; found="$(find "$CANARY" -mindepth 1 2>/dev/null | head -3 | tr '\n' ' ')"
  [ -z "$found" ] && return 0
  # Append rather than print: nearly every caller runs the installer as `>/dev/null 2>&1`, so
  # a message here is swallowed by the very tests that need to hear it. The summary reads the
  # log, where no redirection can hide it.
  printf '%s\n' "$found" >> "$CANARY_LOG"
  rm -rf "${CANARY:?}"/* 2>/dev/null || true
}
count_in() { [ -f "$1" ] || { printf '0'; return; }; grep -c "$2" "$1" 2>/dev/null | head -1; }
run()  { local rc; (cd "$1" && shift && HOME="$SANDBOX_HOME" "$INSTALL" "$@" 2>&1); rc=$?; canary_check; return $rc; }

# Derived from the repo, never hand-written: the promise is "every skill/agent we ship gets
# linked", not "exactly 17". A literal here silently becomes a lie the next time one is added.
N_SKILLS="$(ls -d "$REPO"/skills/*/ | wc -l | tr -d ' ')"
N_AGENTS="$(ls "$REPO"/agents/*.md | wc -l | tr -d ' ')"

echo "── syntax"
bash -n "$INSTALL" && ok "install.sh parses" || no "install.sh parses"
bash -n "$REPO/hooks/session-start.sh" && ok "session-start.sh parses" || no "session-start.sh parses"

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
# Regression: REPO used plain `pwd`, which returns the LOGICAL path. Running the documented
# `~/.mastermind/install.sh` therefore set REPO=~/.mastermind and `ln -sfn "$REPO" ~/.mastermind`
# pointed the symlink at itself — an unreadable loop that silently broke every glob, so skills
# linked as a literal `*` while the installer still printed ✓. The documented command was the
# one that destroyed the install.
H="$TMP/fakehome"; mkdir -p "$H"
ln -sfn "$REPO" "$H/.mastermind"
(cd "$H" && HOME="$H" "$H/.mastermind/install.sh" --global claude >/dev/null 2>&1) || true
is "brain link still points at the real clone" "$(readlink "$H/.mastermind")" "$REPO"
is "no literal-glob links created" "$(ls "$H/.claude/skills" 2>/dev/null | grep -c '^\*' | tr -d ' ')" "0"
is "all skills linked via the symlink path" "$(ls "$H/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')" "$N_SKILLS"

echo "── the npx path: the brain IS ~/.mastermind and install.sh runs from inside it"
# THE 0.29.0 RELEASE BLOCKER. `npx mastermind-brain` clones the brain to ~/.mastermind and then
# runs that clone's install.sh, so REPO == $HOME/.mastermind. A string comparison treated that
# as the self-link catastrophe and aborted: every new user got "refusing to link ~/.mastermind
# to itself" and an unwired project. It survived the suite because sandboxes sat under /tmp,
# which `pwd -P` rewrites to /private/tmp — the strings differed, so the case was never hit.
# This test puts the brain at the canonical location, which is what a real HOME looks like.
# The HOME must be a CANONICAL path. On macOS both /tmp and mktemp's /var/folders are
# symlinks (-> /private/...), so `pwd -P` yields a different string than "$HOME/.mastermind"
# and the broken comparison slips through — which is exactly how this shipped.
H="$TMP_REAL/npxhome"; mkdir -p "$H/.mastermind"
tar -C "$REPO" --exclude=.git --exclude=node_modules -cf - . | tar -C "$H/.mastermind" -xf -
P=$(proj npxwired)
(cd "$P" && HOME="$H" "$H/.mastermind/install.sh" claude >/dev/null 2>&1); rc=$?
is "install from ~/.mastermind exits 0" "$rc" "0"
is "the project actually got wired" "$(ls "$P/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')" "$N_SKILLS"
is "~/.mastermind is still the real clone" "$([ -d "$H/.mastermind" ] && [ ! -L "$H/.mastermind" ] && echo dir)" "dir"
is "no link written inside the brain" "$([ -e "$H/.mastermind/mastermind" ] && echo present || echo gone)" "gone"

echo "── a DIFFERENT brain already at ~/.mastermind is refused, not written into"
H2="$TMP_REAL/otherbrain"; mkdir -p "$H2/.mastermind/skills"
P=$(proj otherwired)
out=$( (cd "$P" && HOME="$H2" "$INSTALL" claude 2>&1) || true )
is "refused with a clear reason" "$(printf '%s' "$out" | grep -c 'different brain')" "1"
is "nothing written inside their clone" "$([ -e "$H2/.mastermind/mastermind" ] && echo present || echo gone)" "gone"

echo "── the isolated brain can run the commands init tells the model to run"
# Release blocker: ISO_ENGINE shipped no scripts/, but `init` and `levelup bootstrap` instruct
# `node scripts/build-router.mjs` / `check-integrity.mjs`. A real init did all the work and then
# dead-ended on "Cannot find module '.mastermind/scripts/build-router.mjs'". check-integrity also
# hard-read repo-only files (README.md, .githooks/) that a project brain does not ship.
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
# Running it from the home directory reported phantom failures ("CLAUDE.md is not linked") for a
# perfectly healthy global install: project scope walked $HOME/.claude — which IS the global
# config — and judged it by project rules. Install mode already refuses ~; the read-only path
# now agrees, and says so rather than switching silently.
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
# Arbitrary write. A repository containing `.claude -> /elsewhere`
# made the installer write 28 files into that location and exit 0; `.cursor` did the same. The
# brain-path walker never covered the integration directories, only paths under .mastermind.
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
# The installer renamed an existing .claude/CLAUDE.md to .bak and linked ours over it. The
# backup prevented data loss but not deactivation: rules like "never deploy on Friday" stopped
# reaching Claude, which breaks MasterMind's own "the project wins". Keep theirs, append ours.
P=$(proj projwins); mkdir -p "$P/.claude"
printf '# Our rules\nNever deploy to prod on Friday.\n' > "$P/.claude/CLAUDE.md"
printf '# Team file\nUse pnpm.\n' > "$P/AGENTS.md"
run "$P" claude agents >/dev/null 2>&1
is "their rule still applies" "$(grep -c Friday "$P/.claude/CLAUDE.md")" "1"
is "and ours is wired in too" "$(grep -c 'mastermind/CLAUDE.md' "$P/.claude/CLAUDE.md")" "1"
is "their AGENTS.md content survives" "$(grep -c pnpm "$P/AGENTS.md")" "1"
# An isolated project must be pointed at ITS OWN brain, not the shared clone: pointing at
# ~/.mastermind sent Codex to a brain without this project's field, lessons and stack.
is "AGENTS.md points at the project brain" "$(grep -c './.mastermind/CLAUDE.md' "$P/AGENTS.md")" "1"

echo "── the doctor knows what SHOULD be wired, not just what survived"
# --check inferred the expected tool set from artifacts that still existed, so deleting the
# Cursor rule removed cursor from the check and a broken install reported "healthy", exit 0.
P=$(proj doctor); run "$P" claude cursor >/dev/null 2>&1
is "the install is recorded" "$(sed -n 's/^tools=//p' "$P/.mastermind/.installed" 2>/dev/null)" "claude cursor"
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" --check >/dev/null 2>&1); is "a healthy install passes" "$?" "0"
rm -f "$P/.cursor/rules/mastermind.mdc"
(cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" --check >/dev/null 2>&1); rc=$?
is "deleted wiring is reported, not ignored" "$([ "$rc" -ne 0 ] && echo caught)" "caught"

echo "── canary self-test: an escape must trip it even with no rule that names the path"
P=$(proj canaryprobe); (cd "$P" && ln -s "$CANARY" .claude)
run "$P" claude >/dev/null 2>&1 || true

# ══ Hostile repository ════════════════════════════════════════════════════════
# The installer reads a directory it did not create. Every path it writes through can be
# replaced by a symlink pointing anywhere, and the previous suite only ever tested paths
# someone had already thought of. This loop covers every integration path at once, so a new
# one is covered the day it is added rather than the day it is exploited.
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
# Directories were covered; individual FILES were not. An owned file sitting in a legitimate
# directory (.cursor/rules/mastermind.mdc, .mastermind/VERSION, .manifest, .installed) could be
# a symlink to anywhere, and the parent-directory check passed while the write landed outside.
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

# ══ Portability ═══════════════════════════════════════════════════════════════
# A project brain is committed and shared. Everything the installer writes must therefore
# survive the two things that happen to committed work: it gets cloned somewhere else, and the
# original directory goes away. 28 absolute symlinks and two absolute hook paths shipped under
# a comment promising the opposite, because nothing ever moved a project after installing it.
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

# ══ Preservation ══════════════════════════════════════════════════════════════
# "The project wins" is MasterMind's own rule, and the installer broke it by renaming an
# existing .claude/CLAUDE.md aside and linking over it: the file survived, the instructions
# stopped applying. Put a user file in every place we write and assert the CONTENT still works.
echo "── a user's own file keeps working wherever we write"
P=$(proj preserve); mkdir -p "$P/.claude" "$P/.cursor/rules"
printf '# mine\nCANARY-CLAUDE never deploy on Friday\n' > "$P/.claude/CLAUDE.md"
printf '# mine\nCANARY-AGENTS use pnpm\n' > "$P/AGENTS.md"
# `--` is load-bearing: a format string starting with `-` is parsed as options, so without it
# this writes nothing and the assertion below fails against a product that behaved correctly.
printf -- '---\nalwaysApply: true\n---\nCANARY-CURSOR house style\n' > "$P/.cursor/rules/team.mdc"
run "$P" claude cursor agents >/dev/null 2>&1
is "their CLAUDE.md still applies"  "$(grep -c CANARY-CLAUDE "$P/.claude/CLAUDE.md" 2>/dev/null)" "1"
is "their AGENTS.md still applies"  "$(grep -c CANARY-AGENTS "$P/AGENTS.md" 2>/dev/null)" "1"
is "their cursor rule is untouched" "$(grep -c CANARY-CURSOR "$P/.cursor/rules/team.mdc" 2>/dev/null)" "1"
is "and MasterMind is wired alongside" "$(ls "$P/.claude/skills" 2>/dev/null | wc -l | tr -d ' ')" "$N_SKILLS"

# ══ Repair ════════════════════════════════════════════════════════════════════
# The doctor inferred what to check from artifacts that still existed, so deleting one removed
# it from the check. Delete each thing the installer recorded, one at a time, and require the
# doctor to notice every time. Generated from the install record, so a tool added later is
# covered without editing this test.
echo "── the doctor notices every piece of wiring that goes missing"
for target in .claude/CLAUDE.md .claude/skills/build .claude/settings.json .cursor/rules/mastermind.mdc AGENTS.md; do
  P=$(proj "repair-$(printf '%s' "$target" | tr '/.' '__')")
  run "$P" claude cursor agents >/dev/null 2>&1
  rm -rf "${P:?}/$target"
  (cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" --check >/dev/null 2>&1); rc=$?
  is "deleting $target is reported" "$([ "$rc" -ne 0 ] && echo caught)" "caught"
done

echo "── the install record survives a partial repair, and shrinks on uninstall"
# Re-running with one tool named ("install.sh claude" to repair Claude) REPLACED the record, so
# the doctor forgot Cursor had ever been wired and called a broken install healthy — the exact
# blind spot the record was added to remove.
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

echo "── uninstall takes our pointer back out of the files it appended to"
# Install preserved the user's AGENTS.md and .claude/CLAUDE.md, then uninstall left the appended
# MasterMind line behind: .claude/CLAUDE.md was missing from the cleanup list, and the cleanup
# matched only the shared-clone hint while an isolated install writes a project-relative one.
P=$(proj pointer); mkdir -p "$P/.claude"
printf '# mine\nMY CLAUDE RULE\n' > "$P/.claude/CLAUDE.md"
printf '# mine\nMY AGENTS RULE\n' > "$P/AGENTS.md"
run "$P" claude agents >/dev/null 2>&1
run "$P" --uninstall claude agents >/dev/null 2>&1
is "no pointer left in .claude/CLAUDE.md" "$(count_in "$P/.claude/CLAUDE.md" 'mastermind/CLAUDE.md')" "0"
is "no pointer left in AGENTS.md"        "$(count_in "$P/AGENTS.md" 'mastermind/CLAUDE.md')" "0"
is "their CLAUDE.md content survived"    "$(count_in "$P/.claude/CLAUDE.md" 'MY CLAUDE RULE')" "1"
is "their AGENTS.md content survived"    "$(count_in "$P/AGENTS.md" 'MY AGENTS RULE')" "1"

# ══ Half-edited markers must never cost the user a line ═══════════════════════
# A repeated START inside a block reset the buffer that exists to protect their content, so an
# unbalanced anchor lost everything written before the second marker.
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

# ══ The brain ships what it runs, and nothing else ════════════════════════════
# ABOUT.md is the article behind each public library page. The website build reads it and the
# repo's own checks read it; no tool reads it at run time, so 101KB of it in every project was
# a second description of every capability sitting on the user's disk.
echo "── the installed brain carries no ABOUT pages"
P=$(proj noabout)
run "$P" claude >/dev/null 2>&1
is "no ABOUT.md was installed" "$(find "$P/.mastermind" -name ABOUT.md 2>/dev/null | wc -l | tr -d ' ')" "0"
# Directories only: the skills folder also carries an index and a readme.
is "the skills themselves are there" "$(find "$P/.mastermind/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "$N_SKILLS"
is "and the shipped checks still pass there" \
   "$( (cd "$P/.mastermind" && node scripts/check-integrity.mjs >/dev/null 2>&1) && echo ok || echo fail)" "ok"

# ══ An edit to an engine file is replaced, but never silently ═════════════════
# Engine files refresh on every run: that is how updates land. Until the ledger recorded what we
# wrote, a project's own change to one disappeared without a word.
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

# ══ A route is healthy only when every anchor it generates is ════════════════
# The check looked at one marker in the nested CLAUDE.md, so a route passed while AGENTS.md
# and the Cursor rule were gone and the app silently loaded nothing.
echo "── the route check covers every anchor, not just the first"
P=$(proj routecheck)
mkdir -p "$P/apps/web"
run "$P" claude cursor >/dev/null 2>&1
cp -R "$P/.mastermind/engineering/fields/_template" "$P/.mastermind/engineering/fields/frontend"
printf 'apps/web frontend\n' > "$P/.mastermind/routes.map"
run "$P" claude cursor >/dev/null 2>&1
is "a complete route reports ok" "$(run "$P" --check 2>&1 | grep -c 'route apps/web/ → frontend (frontend)')" "1"
rm -f "$P/apps/web/AGENTS.md"
is "a missing AGENTS.md anchor is caught" "$(run "$P" --check 2>&1 | grep -c 'AGENTS.md anchor missing')" "1"
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

# ══ Cleanup reads what we generated, not what the map happens to say now ══════
# routes.map describes the present. Delete a rule and the anchor it created has nothing left
# pointing at it, so uninstall walked straight past a file it had written.
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

# ══ The declared field wins over whatever the filesystem lists first ══════════
# A context templated against `find | head -1`, so a project with two packs got an arbitrary
# one, and the anchor disagreed with what the brain reports as active.
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

# ══ "We left your file as we found it" means byte for byte ════════════════════
# The pointer is appended as a blank line plus the hint. Removing only the hint left the blank
# behind, so every install/uninstall cycle grew the file by one newline.
echo "── a pointer round trip changes nothing in the file"
P=$(proj exactbytes)
printf 'line one\nline two\n' > "$P/AGENTS.md"
cp "$P/AGENTS.md" "$P/.orig"
run "$P" claude agents >/dev/null 2>&1
run "$P" --uninstall >/dev/null 2>&1
is "AGENTS.md is byte-identical" "$(cmp -s "$P/AGENTS.md" "$P/.orig" && echo same || echo differs)" "same"

# ══ An instruction file that is already a symlink is theirs ═══════════════════
# Projects do point AGENTS.md at another file. Replacing that link outright loses the
# arrangement, and with no backup recorded there is nothing to give back on uninstall.
echo "── a project's own symlinked AGENTS.md survives install and uninstall"
P=$(proj symlinkedagents)
printf 'SHARED RULES\n' > "$P/RULES.md"
ln -s RULES.md "$P/AGENTS.md"
run "$P" claude agents >/dev/null 2>&1
run "$P" --uninstall >/dev/null 2>&1
is "AGENTS.md is a symlink again"  "$([ -L "$P/AGENTS.md" ] && echo yes || echo no)" "yes"
is "and it points where it did"    "$(readlink "$P/AGENTS.md")" "RULES.md"

# ══ The doctor checks the destination, not merely "somewhere in the brain" ════
# A link that resolves into MasterMind but points at the wrong file passed every check, so a
# skill silently loading another skill's instructions read as healthy.
echo "── a link aimed at the wrong target is reported"
P=$(proj wrongtarget)
run "$P" claude >/dev/null 2>&1
ln -sfn ../../.mastermind/skills/debug "$P/.claude/skills/build"
is "the doctor rejects it" "$(run "$P" --check 2>&1 | grep -c 'build points at')" "1"
run "$P" claude >/dev/null 2>&1
is "and re-running repairs it" "$(run "$P" --check 2>&1 | grep -c 'healthy')" "1"

# ══ A file that mentions the pointer is not a file that carries it ════════════
echo "── an incidental mention does not count as wiring"
P=$(proj mentiononly)
printf 'See ~/.mastermind/CLAUDE.md for details.\n' > "$P/AGENTS.md"
is "a mention alone is not wired" "$(run "$P" --check 2>&1 | grep -c "isn't set up")" "1"

# ══ Every install shape records what it wired ═════════════════════════════════
# A shared install kept no record, so its doctor could only infer from what it found.
echo "── a shared install leaves an expected-integration record"
P=$(proj sharedrecord)
run "$P" --shared claude cursor >/dev/null 2>&1
_key="$(printf '%s' "$P" | tr -c 'A-Za-z0-9._-' '_')"
is "the record lists both tools" "$(count_in "$SANDBOX_HOME/.mastermind-state/projects/$_key" 'tools=claude cursor')" "1"
# The record has to track removals too, or the doctor keeps demanding wiring the user dropped.
run "$P" --uninstall cursor >/dev/null 2>&1
is "a targeted uninstall drops that tool" "$(count_in "$SANDBOX_HOME/.mastermind-state/projects/$_key" 'cursor')" "0"
run "$P" --uninstall >/dev/null 2>&1
# Scoped to THIS project's record: the state directory is shared across the whole run, so
# counting every file in it makes the result depend on which other tests ran first.
_key="$(printf '%s' "$P" | tr -c 'A-Za-z0-9._-' '_')"
is "a bare uninstall drops the record"    "$([ -f "$SANDBOX_HOME/.mastermind-state/projects/$_key" ] && echo present || echo gone)" "gone"

# ══ Ownership decides deletion, never the filename ════════════════════════════
# Reserved paths are not proof of ownership. A user file sitting where we want to write is
# theirs: preserve it on install, hand it back on uninstall, and never delete a same-named
# file we did not generate.
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

# ══ Uninstall does not claim work it could not do ═════════════════════════════
# The hook lives inside a settings.json we do not own. If that file cannot be parsed the entry
# stays registered and every session keeps firing a script that is about to disappear, yet the
# command reported a clean removal and exited 0.
echo "── unreadable settings.json is reported, not glossed over"
P=$(proj honestuninstall)
run "$P" claude >/dev/null 2>&1
mkdir -p "$P/.claude"
printf '{ this is not json\n' > "$P/.claude/settings.json"
out=$(run "$P" --uninstall 2>&1) || true
is "it says what it could not undo" "$(printf '%s' "$out" | grep -c 'could not edit settings.json')" "1"
is "and does not claim success"     "$(printf '%s' "$out" | grep -c 'left untouched')" "0"

# ══ A project uninstall stays inside the project ══════════════════════════════
# The global Codex instruction file lives in the user's home. Pointer cleanup used to include
# it unconditionally, so uninstalling one project edited a file shared by every other.
echo "── a project uninstall does not edit the global Codex file"
P=$(proj codexscope)
mkdir -p "$SANDBOX_HOME/.codex"
# It must carry the pointer, or the cleanup loop skips it and the test proves nothing: this is
# exactly the line a global install writes, and a project uninstall must leave it in place.
{ printf 'MY CODEX GLOBAL\n\n'
  printf 'Follow ~/.mastermind/CLAUDE.md — the MasterMind brain (skills, agents, engineering rigor).\n'
} > "$SANDBOX_HOME/.codex/AGENTS.md"
run "$P" claude codex >/dev/null 2>&1
run "$P" --uninstall >/dev/null 2>&1
is "the global Codex pointer survives"  "$(count_in "$SANDBOX_HOME/.codex/AGENTS.md" 'the MasterMind brain (skills')" "1"
is "and their own content survives too" "$(count_in "$SANDBOX_HOME/.codex/AGENTS.md" 'MY CODEX GLOBAL')" "1"

# ══ Uninstall restores only what the installer itself backed up ═══════════════
# safe_link leaves a "<file>.mm-backup" pointer naming the renamed original, and uninstall
# moves that original back. The pointer lives in the project, so a repository can author one
# naming any path on the machine; uninstall then relocates that file into the project.
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

# ══ Pruning removes our stale links, not the user's ═══════════════════════════
# Every reinstall sweeps broken symlinks out of the skills and agents directories. A broken
# link the user made themselves is not ours to delete, and a dead link still names its target.
echo "── pruning leaves symlinks that were never ours"
P=$(proj prunemine)
run "$P" claude >/dev/null 2>&1
ln -s "$TMP_REAL/victims/nowhere-at-all" "$P/.claude/skills/my-own-skill"
run "$P" claude >/dev/null 2>&1
is "the user's own broken link survives a reinstall" "$([ -L "$P/.claude/skills/my-own-skill" ] && echo yes || echo no)" "yes"

# ══ Containment: the full destination, not the first hop ══════════════════════
# Three bypasses shared one root cause: the guard stopped resolving too early, or compared
# paths as string prefixes. Each of these passed with exit 0 and a modified file outside the
# intended target, through a suite that was green at the time.
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

# (c) an owned file aimed at the ENGINE's own source. Containment cannot catch this one: in an
# isolated install the brain lives inside the project, so the target is legitimately "inside".
# Files we write content into are never symlinks, wherever they point.
P=$(proj braintarget); run "$P" cursor >/dev/null 2>&1
core="$P/.mastermind/engineering/core/mindset.md"; before="$(head -c 40 "$core")"
rm -f "$P/.cursor/rules/mastermind.mdc"; ln -s "$core" "$P/.cursor/rules/mastermind.mdc"
run "$P" cursor >/dev/null 2>&1 || true
is "an owned file cannot be aimed at the engine" "$(head -c 40 "$core")" "$before"

echo "── uninstalling one tool leaves the others wired"
# `--uninstall cursor` removed all 22 Claude skills, the kernel link and the bootstrap hook,
# while the install record still claimed Claude was present.
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
run "$P" --uninstall claude cursor >/dev/null 2>&1
is "bootstrap hook unwired" "$(python3 -c "
import json;d=json.load(open('$P/.claude/settings.json'))
print(len([e for e in d.get('hooks',{}).get('SessionStart',[]) if 'session-start.sh' in json.dumps(e)]))")" "0"
is "their settings survive uninstall" "$(python3 -c "
import json;d=json.load(open('$P/.claude/settings.json'));print(d.get('model'),'PreToolUse' in d.get('hooks',{}))")" "opus True"
is "legacy copilot hook file removed" "$([ -f "$P/.github/hooks/mastermind.json" ] && echo present || echo gone)" "gone"

echo "── --global --uninstall must not delete project files"
# HOME is overridden to a throwaway dir: --global operates on ~/.claude, so running this
# against the real $HOME would uninstall the developer's own global setup — which is exactly
# what happened once. This file promises it touches nothing in $HOME.
# AGENTS.md is the live case now: it is a PROJECT file with no global counterpart, so a
# --global uninstall must leave it alone rather than resolving it against $PROJECT.
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
# Shared mode points every project at ~/.mastermind, so one active field, one lessons.md
# and one stack-defaults for every project. Right for one stack, wrong across client repos.
# --isolated copies the engine into <project>/.mastermind so the project owns its knowledge.
P=$(proj iso); run "$P" --isolated claude >/dev/null 2>&1
is "brain copied into the project" "$([ -f "$P/.mastermind/VERSION" ] && echo y)" "y"
is "records the version it installed" "$(cat "$P/.mastermind/VERSION" 2>/dev/null)" "$(cat "$REPO/VERSION")"
yes_ "links point at the LOCAL brain" "$(readlink "$P/.claude/skills/build" | grep -o '\.mastermind/skills/build')"
yes_ "no ~/.mastermind left in the copied docs" "$([ "$(grep -rl '~/\.mastermind' "$P/.mastermind" 2>/dev/null | wc -l | tr -d ' ')" = 0 ] && echo y)"

# is_ours() matched only $REPO, so on a second run the project's own links looked like the
# user's files and every skill was duplicated as mastermind-<name>: 17 became 34.
run "$P" claude >/dev/null 2>&1
run "$P" claude >/dev/null 2>&1
is "idempotent — no duplicate aliases" "$(ls "$P/.claude/skills" | wc -l | tr -d ' ')" "$N_SKILLS"
yes_ "stays isolated without the flag" "$(readlink "$P/.claude/skills/build" | grep -o '\.mastermind/skills/build')"

echo "── isolated: no field is shipped — the project builds its own, and keeps it"
# Nothing is pre-baked: a pack tuned to someone else's stack is worse than none. Only the
# scaffold ships; `init` builds the real field. Whatever the project then creates is ITS
# knowledge, and an update must never refresh, rewrite or retire it.
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

echo "── isolated: real isolation — one project cannot change another"
# The project wrote OUR LESSON into its own field and TAMPERED into its own core; neither may
# reach the shared clone. Assert against a file that exists in the clone (core is always there).
is "the shared clone is untouched" "$(grep -rc 'OUR LESSON\|TAMPERED\|OUR FIELD CHOICE' "$REPO/engineering/core" | grep -cv ':0$')" "0"
yes_ "--isolated --global is refused" "$( (cd "$P" && HOME="$SANDBOX_HOME" "$INSTALL" --isolated --global 2>&1 || true) | grep -o 'per-project by definition')"
is "uninstall keeps the project's own brain" "$([ -d "$P/.mastermind" ] && echo kept)" "kept"

echo "── isolated: never write through a symlinked .mastermind (data loss)"
# `ln -s ~/anywhere .mastermind` made every rm -rf in the sync resolve THROUGH the link and
# delete that directory's contents, exit 0, no warning. Worse: pointed at the shared clone it
# also auto-enabled isolation (the clone has a VERSION), so a plain `install.sh` — no flag —
# deleted the clone's kernel and broke every other project.
P=$(proj symguard); PRECIOUS="$TMP/precious"; rm -rf "$PRECIOUS"; mkdir -p "$PRECIOUS"
echo IRREPLACEABLE > "$PRECIOUS/my-thing.md"
ln -s "$PRECIOUS" "$P/.mastermind"
run "$P" --isolated claude >/dev/null 2>&1 || true
is "user's files survive"        "$(cat "$PRECIOUS/my-thing.md" 2>/dev/null)" "IRREPLACEABLE"
is "nothing was written through" "$(ls "$PRECIOUS" | wc -l | tr -d ' ')" "1"
# Either guard may catch this first: the containment gate (checked before any write) or the
# brain-path walker. Assert the refusal, not one guard's wording.
yes_ "and it refuses out loud"   "$(run "$P" --isolated claude 2>&1 | grep -oE 'is a symlink|resolves outside the project' | head -1)"
# A symlinked .mastermind must never flip a project into isolated mode either.
yes_ "no silent isolation via symlink" "$(run "$P" claude 2>&1 | grep -o 'is a symlink' || echo skipped)"

echo "── isolated: the copied brain has no dangling references"
P=$(proj isodeps); run "$P" --isolated claude agents >/dev/null 2>&1
# route/SKILL.md points at ROUTER.md and AGENTS.md is the wired instruction file; neither was copied,
# so the isolated brain shipped broken references to its own most-used entry point.
is "ROUTER.md copied" "$([ -f "$P/.mastermind/engineering/ROUTER.md" ] && echo y)" "y"
is "AGENTS.md copied" "$([ -e "$P/.mastermind/AGENTS.md" ] && echo y)" "y"

echo "── isolated: --check works without naming a tool"
# is_wired() was the one call site missed when $BRAIN was introduced, so the doctor told a
# perfectly healthy isolated project it wasn't installed at all.
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
# The engine dirs were `rm -rf`'d wholesale, so anything a project added to its own brain was
# destroyed on the next install — and that wipe short-circuited the manifest reconciliation
# built to protect exactly these files. Users must be able to add their own skills.
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
# Asserted against the CLONE path specifically: an earlier version of this test grepped for
# 'AGENTS.md$', which matches both the clone and the project copy, so it passed either way.
P=$(proj sharedreg); run "$P" --shared agents >/dev/null 2>&1
is "no project brain created" "$([ -e "$P/.mastermind" ] && echo created || echo none)" "none"
is "AGENTS.md targets the clone" "$(readlink "$P/AGENTS.md")" "$REPO/AGENTS.md"
yes_ "--check calls it healthy"  "$(run "$P" --check --shared agents 2>&1 | grep -o 'healthy here')"
# `codex` was the old name for this exact target — the alias keeps old commands working.
P=$(proj alias); run "$P" --shared codex >/dev/null 2>&1
is "codex alias still wires AGENTS.md" "$(readlink "$P/AGENTS.md")" "$REPO/AGENTS.md"

echo "── monorepo: one brain per REPO, wherever you run install from"
# Wiring whichever directory you stood in gave one repo several brains: the root on its own
# field and lessons, apps/web silently on the shared clone. Same repo, different rules, no
# warning — and the symptom surfaces far from the cause.
P=$(proj mono); mkdir -p "$P/apps/web/src"; (cd "$P" && git init -q .)
(cd "$P/apps/web/src" && HOME="$SANDBOX_HOME" "$INSTALL" --isolated claude >/dev/null 2>&1)
is "brain created at the repo root" "$([ -f "$P/.mastermind/VERSION" ] && echo y)" "y"
is "no stray brain in the subdir"   "$([ -e "$P/apps/web/src/.mastermind" ] && echo stray || echo none)" "none"
is "tools wired at the repo root"   "$([ -d "$P/.claude" ] && echo y)" "y"
is "no stray .claude in the subdir" "$([ -e "$P/apps/web/src/.claude" ] && echo stray || echo none)" "none"
run "$P" claude >/dev/null 2>&1
is "running from the root is a no-op" "$(find "$P" -path '*/.mastermind/VERSION' | wc -l | tr -d ' ')" "1"

echo "── isolated update: retire what upstream dropped, keep what the project added"
# Nothing reconciled deletions, so a file retired upstream lived on forever — and since
# .mastermind/ is committed, it spread to every teammate. Deleting anything simply "not in
# the source" would instead destroy files the project added on purpose, which is worse.
# The manifest records what WE installed, so the two cases stay distinguishable.
CLONE="$TMP/clone"; rm -rf "$CLONE"; cp -R "$REPO/." "$CLONE/" 2>/dev/null
P=$(proj retire)
(cd "$P" && HOME="$SANDBOX_HOME" "$CLONE/install.sh" --isolated claude >/dev/null 2>&1)
# The project's own field — what `init` builds in real use.
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
# Upgrading from a release that DID ship a pack must not gut it: those files are in the old
# manifest, so without the fields/ guard reconciliation would delete the project's whole pack.
mkdir -p "$P/.mastermind/engineering/fields/frontend"
echo "LEGACY" > "$P/.mastermind/engineering/fields/frontend/web-animations.md"
printf 'engineering/fields/frontend/web-animations.md\n' >> "$P/.mastermind/.manifest"
(cd "$P" && HOME="$SANDBOX_HOME" "$CLONE/install.sh" claude >/dev/null 2>&1)
is "a pre-0.27 pack is never gutted" "$(cat "$P/.mastermind/engineering/fields/frontend/web-animations.md" 2>/dev/null)" "LEGACY"

echo "── project under \$HOME with the shared clone present — must NOT resolve PROJECT=\$HOME"
# The shared clone is $HOME/.mastermind (a symlink). A walk-up from a project UNDER $HOME
# used to ascend into $HOME, match it, and return PROJECT=$HOME — no-op'ing install and, on
# uninstall, deleting the user's GLOBAL wiring. The old harness never nested the project
# inside HOME, so it couldn't see this. This does.
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
# A monorepo's apps want their own field/lessons. routes.map declares path→context; the
# installer compiles each into that dir's native anchor (nested CLAUDE.md/AGENTS.md + a
# glob-scoped Cursor rule). Selection is by file path — the AI never reads the map.
P=$(proj fc); mkdir -p "$P/apps/web/src" "$P/apps/api" "$P/packages/ui"; (cd "$P" && git init -q .)
run "$P" --isolated claude >/dev/null 2>&1
# A context attaches to a field, and 0.27.0 ships none — so the project must have built one
# first (what init does). Stand up a minimal field so routing has something to point at.
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
is "their content survives"  "$(count_in "$P/apps/web/CLAUDE.md" 'internal auth')" "1"
is "cursor rule removed"     "$([ -f "$P/apps/web/.cursor/rules/mastermind.mdc" ] && echo present || echo gone)" "gone"

echo "── single-project (no routes.map) is untouched — the common case stays simple"
P=$(proj single); (cd "$P" && git init -q .)
run "$P" --isolated claude >/dev/null 2>&1
is "no contexts dir created" "$([ -d "$P/.mastermind/engineering/contexts" ] && echo made || echo none)" "none"
is "no per-app anchors"      "$(find "$P" -name CLAUDE.md ! -path '*/.mastermind/*' ! -path '*/.claude/*' | wc -l | tr -d ' ')" "0"

echo "── field+context: a malformed routes.map line warns and skips, never aborts"
# A one-token line (context omitted) or a context name with a slash used to interpolate into a
# sed and abort the whole install under set -e, then "heal" into a broken context on re-run.
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
# Every other tool receives CLAUDE.md by symlink. Cursor can't (an .mdc needs frontmatter),
# and the installer used to write a one-line "Follow ~/.mastermind/CLAUDE.md" instead — so
# Cursor got a note about where the brain lives rather than the brain, and users typed
# "use mastermind" on every prompt to do by hand what the rule should have done.
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
# Measured 2026-07-26 on Composer 2.5: the kernel names the pack files and tells the model to load
# them, and it never did — asked directly it read them instantly, so the pack sat inert and the run
# scored exactly baseline. Same fix as the kernel: inline it, don't point at it.
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
# Codex has no project-level file of its own — it reads AGENTS.md, so naming either tool must
# produce the same wiring. Asking for `codex` in a project must NOT touch ~/.codex.
P=$(proj codexproj); CH="$TMP/codexhome"; mkdir -p "$CH"
(cd "$P" && HOME="$SANDBOX_HOME" CODEX_HOME="$CH" "$INSTALL" codex >/dev/null 2>&1) || true
yes_ "AGENTS.md wired by name 'codex'" "$([ -L "$P/AGENTS.md" ] && echo yes)"
is   "and CODEX_HOME untouched in project scope" "$([ -e "$CH/AGENTS.md" ] && echo present || echo none)" "none"

echo "── codex: --global wires CODEX_HOME/AGENTS.md, honouring CODEX_HOME"
P=$(proj codexglob); GH2="$TMP/cghome"; CH2="$TMP/cgcodex"; mkdir -p "$GH2" "$CH2"
(cd "$P" && HOME="$GH2" CODEX_HOME="$CH2" "$INSTALL" --global codex >/dev/null 2>&1) || true
yes_ "CODEX_HOME/AGENTS.md linked to the brain" "$([ -L "$CH2/AGENTS.md" ] && echo yes)"
# The docs say Codex uses only the first NON-EMPTY file at that level, and Codex creates an
# empty one itself — a pointer appended to a 0-byte file was the old, silently-dead behaviour.
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
# We wire only what we test (Claude, Cursor, AGENTS.md). Asking for a retired target must
# say so and write NOTHING — a half-wired file that no longer refreshes is worse than none.
P=$(proj retired)
yes_ "gemini explains itself"  "$(run "$P" gemini 2>&1 | grep -o 'no longer wired automatically')"
is   "and writes no GEMINI.md" "$([ -e "$P/GEMINI.md" ] && echo present || echo none)" "none"
yes_ "copilot explains itself" "$(run "$P" copilot 2>&1 | grep -o 'no longer wired automatically')"
is   "and writes no copilot file" "$([ -e "$P/.github/copilot-instructions.md" ] && echo present || echo none)" "none"

echo "── AGENTS.md is wired even with no tool installed"
# The brain is plain Markdown; AGENTS.md is how every tool we don't wire natively reads it.
P=$(proj noagent); mkdir -p "$TMP/emptyhome"
(cd "$P" && HOME="$TMP/emptyhome" "$INSTALL" >/dev/null 2>&1) || true
is "AGENTS.md wired anyway" "$([ -e "$P/AGENTS.md" ] && echo y || echo n)" "y"

# ── filesystem trust boundary ───────────────────────────────────────────────────
# Both attacks below were reproduced: the installer wrote OUTSIDE the
# project. Keep them adversarial.
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
# Links are written resolved (/private/tmp/...) while BRAIN is computed logically (/tmp/...).
# Comparing the raw strings made is_ours() false for every link, so uninstall removed nothing
# and reported success. macOS /tmp, symlinked homes and network mounts all hit this.
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
