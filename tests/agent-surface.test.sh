#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI=("node" "$ROOT/cli/bin/mastermind.mjs")
pass=0; fail=0
ok()  { printf '  \033[0;32m✓\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  \033[0;31m✗\033[0m %s\n' "$1"; fail=$((fail+1)); }
check() { [ "$2" = "$3" ] && ok "$1" || bad "$1 (want '$3', got '$2')"; }

WORK="$(cd "$(mktemp -d)" && pwd -P)"  # -P: macOS /var is a symlink to /private/var
trap 'rm -rf "$WORK"' EXIT
PROJ="$WORK/proj"; mkdir -p "$PROJ/sub/deeper"
# a minimal fake brain: the surface must work off the on-disk shape, nothing else
mkdir -p "$PROJ/.mastermind/skills/performance" "$PROJ/.mastermind/agents"
echo "0.0.0-test" > "$PROJ/.mastermind/VERSION"
printf -- '---\nname: performance\ndescription: Use when something is slow — a slow query or page load.\n---\n\n# body line\nmeasure first\n' \
  > "$PROJ/.mastermind/skills/performance/SKILL.md"
printf -- '---\nname: code-reviewer\ndescription: Reviews a diff against the rigor gate.\n---\n\nreviewer body\n' \
  > "$PROJ/.mastermind/agents/code-reviewer.md"

echo "agent surface"

META="$WORK/meta"; mkdir -p "$META"
out=$(cd "$META" && HOME="$META" MASTERMIND_HOME="$META/absent" "${CLI[@]}" --help 2>/dev/null)
check "--help exits without installing" "$?" "0"
case "$out" in *"mastermind skills"*) ok "--help prints the command surface";; *) bad "--help output is incomplete";; esac
[ -e "$META/absent" ] && bad "--help created a brain" || ok "--help creates nothing"
out=$(cd "$META" && HOME="$META" MASTERMIND_HOME="$META/absent" "${CLI[@]}" --version 2>/dev/null)
check "--version comes from the package without installing" "$out" "$(node -p "require('$ROOT/cli/package.json').version")"
[ -e "$META/absent" ] && bad "--version created a brain" || ok "--version creates nothing"

out=$(cd "$PROJ/sub/deeper" && "${CLI[@]}" skills --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["brain"])')
check "resolves the project brain from a subdirectory" "$out" "$PROJ/.mastermind"

out=$(cd "$PROJ" && "${CLI[@]}" skill performance | tail -1)
check "prints the skill body" "$out" "measure first"

out=$(cd "$PROJ" && "${CLI[@]}" route "why is this page slow?" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join([s["name"] for s in d["skills"]]) + "|" + ",".join(d["hints"]))')
check "route returns the table and hints the match" "$out" "performance|performance"

out=$(cd "$PROJ" && "${CLI[@]}" agent code-reviewer | tail -1)
check "prints an agent brief" "$out" "reviewer body"

(cd "$PROJ" && "${CLI[@]}" skill nope >/dev/null 2>&1); check "unknown skill exits non-zero" "$?" "1"
(cd "$PROJ" && "${CLI[@]}" skills --json >/dev/null 2>&1); check "listing exits zero" "$?" "0"

EMPTY="$WORK/empty"; mkdir -p "$EMPTY"
before=$(ls -A "$EMPTY" | wc -l | tr -d ' ')
(cd "$EMPTY" && HOME="$EMPTY" MASTERMIND_HOME="$EMPTY/absent" "${CLI[@]}" skill performance >/dev/null 2>&1)
code=$?
after=$(ls -A "$EMPTY" | wc -l | tr -d ' ')
check "refuses when no brain exists" "$code" "1"
check "wrote nothing while refusing" "$after" "$before"
[ -e "$EMPTY/absent" ] && bad "created MASTERMIND_HOME" || ok "did not create MASTERMIND_HOME"

out=$(cd "$PROJ" && "${CLI[@]}" route "xyzzy plugh" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(str(len(d["skills"])) + "|" + str(len(d["hints"])))')
check "unmatched request still sees every skill, hints nothing" "$out" "1|0"

out=$(cd "$PROJ" && "${CLI[@]}" skill performance --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join(sorted(d)))')
check "json shape is stable" "$out" "body,description,name,path"

out=$(cd "$PROJ" && "${CLI[@]}" --json skills | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["skills"]))' 2>/dev/null)
check "flag before the command still lists (never installs)" "$out" "1"

ORDER="$WORK/order"; mkdir -p "$ORDER"
(cd "$ORDER" && HOME="$ORDER" MASTERMIND_HOME="$ORDER/absent" "${CLI[@]}" --json skills >/dev/null 2>&1)
[ -e "$ORDER/absent" ] && bad "flag-first lookup installed a brain" || ok "flag-first lookup installed nothing"

for bad_call in "skill" "route"; do
  out=$(cd "$PROJ" && "${CLI[@]}" "$bad_call" --json 2>/dev/null | python3 -c 'import json,sys; print("error" in json.load(sys.stdin))' 2>/dev/null)
  check "--json $bad_call with no argument answers in json" "$out" "True"
done

out=$(cd "$ROOT" && MASTERMIND_HOME="$ROOT" "${CLI[@]}" route "anything at all" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d["skills"]) > 10)' 2>/dev/null)
check "large piped json is not truncated" "$out" "True"

printf '# Journal\n\nLines marked · wrong · are the calibration record.\n\n2026-08-04 · shipped a thing · ship\n2026-08-04 · wrong · claimed X · caught by test Y · do Z\n' \
  > "$PROJ/.mastermind/journal.md"
out=$(cd "$PROJ" && "${CLI[@]}" wrong-log --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["count"])')
check "wrong-log returns only the misses" "$out" "1"

rm -f "$PROJ/.mastermind/journal.md"
out=$(cd "$PROJ" && "${CLI[@]}" wrong-log | grep -c "not that nothing was wrong")
check "empty wrong-log does not imply a clean record" "$out" "1"

GONE="$WORK/gone"; mkdir -p "$GONE"
out=$( (cd "$GONE" && rm -rf "$GONE" && "${CLI[@]}" skills 2>&1 >/dev/null) | head -1 )
case "$out" in *"uv_cwd"*|*"internal/bootstrap"*) bad "deleted cwd crashes with a node stack";; *) ok "deleted cwd fails cleanly";; esac

echo "cli arguments"
# A review installed a brain by typing `skilss`: unknown words fell through to init.
TYPO="$WORK/typo"; mkdir -p "$TYPO"
(cd "$TYPO" && HOME="$TYPO" MASTERMIND_HOME="$TYPO/absent" "${CLI[@]}" skilss >/dev/null 2>&1)
check "a typo exits 2 instead of installing" "$?" "2"
check "a typo creates nothing" "$([ -z "$(ls -A "$TYPO")" ] && echo yes || echo no)" "yes"
out=$( (cd "$TYPO" && HOME="$TYPO" MASTERMIND_HOME="$TYPO/absent" "${CLI[@]}" skilss 2>&1) | head -1 )
case "$out" in *"Did you mean"*) ok "a typo suggests the real command";; *) bad "no suggestion: $out";; esac

# Provenance signs the CLI, not the brain it clones — so a MOVED TAG must be refused.
SRC="$WORK/fake-brain"; mkdir -p "$SRC"
( cd "$SRC" && git init -q . && printf '#!/usr/bin/env bash\necho installed\n' > install.sh \
  && git add -A && git -c user.email=t@t -c user.name=t -c core.hooksPath=/dev/null commit -qm seed \
  && git tag -f v9.9.9 >/dev/null ) 2>/dev/null
out=$( (cd "$WORK" && MASTERMIND_HOME="$WORK/clone-home" MASTERMIND_REPO="$SRC" MASTERMIND_REF=v9.9.9 \
        MASTERMIND_COMMIT=0000000000000000000000000000000000000000 "${CLI[@]}" check 2>&1) || true )
case "$out" in *"this release pins 000000000000"*) ok "a moved tag is refused (commit pin)";; *) bad "commit pin not enforced: $(printf '%s' "$out" | tail -1)";; esac

echo "conflicts"
CONF="$WORK/conf"; mkdir -p "$CONF/.mastermind/skills/performance" "$CONF/.claude/skills/optimize"
echo "0.0.0-test" > "$CONF/.mastermind/VERSION"
printf -- '---\nname: performance\ndescription: Use when something is slow — a slow query, slow page load, high memory or a timeout.\n---\n' \
  > "$CONF/.mastermind/skills/performance/SKILL.md"
printf -- '---\nname: optimize\ndescription: Speed things up. Use for slow pages, slow queries, high memory, long load times, or any performance problem.\n---\n' \
  > "$CONF/.claude/skills/optimize/SKILL.md"
out=$(cd "$CONF" && HOME="$CONF" "${CLI[@]}" conflicts --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(str(len(d["foreign"])) + "|" + ",".join(sorted({c["ours"] for c in d["collisions"]})))')
check "sees the foreign skill and the overlap it causes" "$out" "1|performance"

ln -s "$CONF/.mastermind/skills/performance" "$CONF/.claude/skills/performance" 2>/dev/null
out=$(cd "$CONF" && HOME="$CONF" "${CLI[@]}" conflicts --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["foreign"]))')
check "our own linked skill is not counted as foreign" "$out" "1"

CLEAN="$WORK/clean"; mkdir -p "$CLEAN/.mastermind/skills"
echo "0.0.0-test" > "$CLEAN/.mastermind/VERSION"
out=$(cd "$CLEAN" && HOME="$CLEAN" "${CLI[@]}" conflicts | head -1)
case "$out" in *"nothing to collide"*) ok "a clean install says so plainly";; *) bad "clean install: $out";; esac

OVER="$WORK/override"; mkdir -p "$OVER/home/.mastermind" "$OVER/home/proj" "$OVER/checkout"
echo "0.0.0-user-install" > "$OVER/home/.mastermind/VERSION"
echo "9.9.9-under-test"   > "$OVER/checkout/VERSION"
out=$(cd "$OVER/home/proj" && HOME="$OVER/home" MASTERMIND_HOME="$OVER/checkout" "${CLI[@]}" skills --json | head -3)
case "$out" in *"$OVER/checkout"*) ok "MASTERMIND_HOME wins over the walk-up";; *) bad "override ignored: $out";; esac
out=$(cd "$OVER/home/proj" && HOME="$OVER/home" "${CLI[@]}" skills --json | head -3)
case "$out" in *"$OVER/home/.mastermind"*) ok "without the override the walk-up still finds ~/.mastermind";; *) bad "walk-up broke: $out";; esac

msg=$(grep -A3 "process.platform === 'win32'" "$ROOT/cli/bin/mastermind.mjs" | grep -c "Git Bash will not work")
case "$msg" in 1) ok "the Windows refusal no longer advertises Git Bash as working";; *) bad "Git Bash still advertised";; esac

PINDIR="$WORK/pinned"; mkdir -p "$PINDIR/bin"
cp -R "$ROOT/cli/." "$PINDIR/"
HEADSHA=$(git -C "$ROOT" rev-parse HEAD)
python3 - "$PINDIR/bin/mastermind.mjs" "$HEADSHA" <<'PYEOF'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
p.write_text(re.sub(r"const PINNED_COMMIT = [^\n]+", f"const PINNED_COMMIT = '{sys.argv[2]}'", s, count=1))
PYEOF

# (a) A directory holding install.sh and no .git skipped every check and was EXECUTED.
NOGIT="$WORK/nogit"; mkdir -p "$NOGIT/.mastermind" "$NOGIT/proj"
printf '#!/usr/bin/env bash\ntouch %s/PWNED\n' "$NOGIT" > "$NOGIT/.mastermind/install.sh"
chmod +x "$NOGIT/.mastermind/install.sh"
(cd "$NOGIT/proj" && git init -q . && env -u MASTERMIND_HOME HOME="$NOGIT" node "$PINDIR/bin/mastermind.mjs" >/dev/null 2>&1) || true
case "$([ -f "$NOGIT/PWNED" ] && echo ran || echo refused)" in
  refused) ok "a brain with no git history is refused, not executed";;
  *) bad "arbitrary install.sh executed under a pinned build";;
esac

# (b) The pin proves the commit, not the tree: an edited install.sh ran with HEAD unchanged.
DIRTY="$WORK/dirty"; mkdir -p "$DIRTY/proj"
git clone -q "$ROOT" "$DIRTY/.mastermind" 2>/dev/null
echo "# tampered" >> "$DIRTY/.mastermind/install.sh"
out=$(cd "$DIRTY/proj" && git init -q . && env -u MASTERMIND_HOME HOME="$DIRTY" node "$PINDIR/bin/mastermind.mjs" 2>&1 | head -1)
case "$out" in *"uncommitted changes"*) ok "a dirty engine tree is refused";; *) bad "dirty tree accepted: $out";; esac
git -C "$DIRTY/.mastermind" checkout -- install.sh
out=$(cd "$DIRTY/proj" && env -u MASTERMIND_HOME HOME="$DIRTY" node "$PINDIR/bin/mastermind.mjs" 2>&1 | grep -c "isolated brain")
case "$out" in 1) ok "the same clone installs once it is clean";; *) bad "clean clone refused too";; esac

PREV_TAG=$(git -C "$ROOT" tag --list 'v*' --sort=-v:refname | sed -n 2p)
if [ -n "$PREV_TAG" ]; then
  LIFE="$WORK/lifecycle"; mkdir -p "$LIFE/proj"
  git clone -q "$ROOT" "$LIFE/.mastermind" 2>/dev/null
  git -C "$LIFE/.mastermind" checkout -q "$PREV_TAG" 2>/dev/null
  # Pin the CLI to the tag it would ship as, so this is a real release-to-release upgrade.
  CURTAG=$(git -C "$ROOT" tag --list 'v*' --sort=-v:refname | sed -n 1p)
  CURSHA=$(git -C "$ROOT" rev-parse "$CURTAG^{commit}")
  LIFECLI="$WORK/lifecli"; mkdir -p "$LIFECLI"; cp -R "$ROOT/cli/." "$LIFECLI/"
  python3 - "$LIFECLI/bin/mastermind.mjs" "$CURSHA" "$CURTAG" <<'PYEOF'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = re.sub(r"const PINNED_COMMIT = [^\n]+", f"const PINNED_COMMIT = '{sys.argv[2]}'", s, count=1)
s = re.sub(r"const PIN = [^\n]+", f"const PIN = '{sys.argv[3]}'", s, count=1)
p.write_text(s)
PYEOF
  out=$(cd "$LIFE/proj" && git init -q . && env -u MASTERMIND_HOME HOME="$LIFE" node "$LIFECLI/bin/mastermind.mjs" 2>&1)
  now=$(git -C "$LIFE/.mastermind" describe --tags 2>/dev/null)
  case "$now" in "$CURTAG"*) ok "the documented command upgrades $PREV_TAG -> $CURTAG";;
    *) bad "upgrade left the brain at $now: $(printf '%s' "$out" | head -1)";; esac
  case "$out" in *"isolated brain"*) ok "and the project is wired after the upgrade";;
    *) bad "upgrade did not finish the install: $(printf '%s' "$out" | tail -1)";; esac
else
  ok "lifecycle test skipped (no previous tag yet)"
fi

BROKE="$WORK/brokenidx"; mkdir -p "$BROKE/proj"
git clone -q "$ROOT" "$BROKE/.mastermind" 2>/dev/null
printf 'garbage' > "$BROKE/.mastermind/.git/index"
out=$(cd "$BROKE/proj" && git init -q . && env -u MASTERMIND_HOME HOME="$BROKE" node "$PINDIR/bin/mastermind.mjs" 2>&1 | tail -3)
case "$out" in *"cannot read the working tree"*) ok "an unreadable index refuses, it does not pass as clean";;
  *) bad "broken index accepted: $out";; esac

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
