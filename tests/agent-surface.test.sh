#!/usr/bin/env bash
# Guards the agent-callable surface of the CLI: the lookups must resolve the PROJECT's brain,
# must never install or write anything, and must fail loudly instead of guessing.
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

out=$(cd "$PROJ/sub/deeper" && "${CLI[@]}" skills --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["brain"])')
check "resolves the project brain from a subdirectory" "$out" "$PROJ/.mastermind"

out=$(cd "$PROJ" && "${CLI[@]}" skill performance | tail -1)
check "prints the skill body" "$out" "measure first"

# The contract is the whole table every time; the → arrow is advisory. Assert both: the skill
# is present, and a matching request marks it.
out=$(cd "$PROJ" && "${CLI[@]}" route "why is this page slow?" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join([s["name"] for s in d["skills"]]) + "|" + ",".join(d["hints"]))')
check "route returns the table and hints the match" "$out" "performance|performance"

out=$(cd "$PROJ" && "${CLI[@]}" agent code-reviewer | tail -1)
check "prints an agent brief" "$out" "reviewer body"

(cd "$PROJ" && "${CLI[@]}" skill nope >/dev/null 2>&1); check "unknown skill exits non-zero" "$?" "1"
(cd "$PROJ" && "${CLI[@]}" skills --json >/dev/null 2>&1); check "listing exits zero" "$?" "0"

# The load-bearing promise: with no brain in sight, a lookup refuses — it must not clone,
# install, or create anything, because an agent calling it is not asking to change the machine.
EMPTY="$WORK/empty"; mkdir -p "$EMPTY"
before=$(ls -A "$EMPTY" | wc -l | tr -d ' ')
(cd "$EMPTY" && HOME="$EMPTY" MASTERMIND_HOME="$EMPTY/absent" "${CLI[@]}" skill performance >/dev/null 2>&1)
code=$?
after=$(ls -A "$EMPTY" | wc -l | tr -d ' ')
check "refuses when no brain exists" "$code" "1"
check "wrote nothing while refusing" "$after" "$before"
[ -e "$EMPTY/absent" ] && bad "created MASTERMIND_HOME" || ok "did not create MASTERMIND_HOME"

# A request nothing matches must still show every option with no arrows — the failure mode to
# avoid is a confident wrong shortlist, not an empty one.
out=$(cd "$PROJ" && "${CLI[@]}" route "xyzzy plugh" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(str(len(d["skills"])) + "|" + str(len(d["hints"])))')
check "unmatched request still sees every skill, hints nothing" "$out" "1|0"

out=$(cd "$PROJ" && "${CLI[@]}" skill performance --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join(sorted(d)))')
check "json shape is stable" "$out" "body,description,name,path"

# A flag before the subcommand used to match no command and fall through to the DEFAULT,
# which is install — so `mastermind --json skills` cloned the brain instead of listing it.
# The lookup must stay read-only however the flags are ordered.
out=$(cd "$PROJ" && "${CLI[@]}" --json skills | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["skills"]))' 2>/dev/null)
check "flag before the command still lists (never installs)" "$out" "1"

ORDER="$WORK/order"; mkdir -p "$ORDER"
(cd "$ORDER" && HOME="$ORDER" MASTERMIND_HOME="$ORDER/absent" "${CLI[@]}" --json skills >/dev/null 2>&1)
[ -e "$ORDER/absent" ] && bad "flag-first lookup installed a brain" || ok "flag-first lookup installed nothing"

# --json means every answer parses as JSON, including the ones that say no. An agent cannot
# tell a bad argument from a broken tool if the error arrives as prose.
for bad_call in "skill" "route"; do
  out=$(cd "$PROJ" && "${CLI[@]}" "$bad_call" --json 2>/dev/null | python3 -c 'import json,sys; print("error" in json.load(sys.stdin))' 2>/dev/null)
  check "--json $bad_call with no argument answers in json" "$out" "True"
done

# cwd can vanish under a watcher or a stale CI worktree; that must not surface as a raw
# Node ENOENT stack trace from inside the tool.
# Output goes down a PIPE whenever an agent calls this, and stdout is async there: an
# exit() straight after a write truncated the table mid-string at ~8KB and produced invalid
# JSON. Assert on the REAL brain, whose table is big enough to cross that boundary.
# MASTERMIND_HOME pinned to this checkout: the assertion is about output size, not about
# whatever brain the machine happens to have installed.
out=$(cd "$ROOT" && MASTERMIND_HOME="$ROOT" "${CLI[@]}" route "anything at all" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d["skills"]) > 10)' 2>/dev/null)
check "large piped json is not truncated" "$out" "True"

# The calibration record: only lines that record a miss, and an empty log must say "nothing was
# logged" rather than implying nothing went wrong.
# The header deliberately contains prose about `· wrong ·` entries: an unanchored filter
# counted that sentence as a miss.
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
# An external audit installed a brain by typing `skilss`: unknown words fell through to init.
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
# Users end up with several packs installed. This must see foreign skills, must NOT mistake
# our own (a global install symlinks into the shared clone, not the project brain), and must
# report rather than resolve.
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

# An explicit MASTERMIND_HOME must beat the walk-up. findBrain climbs from cwd looking for
# `.mastermind`, and every directory under the home dir has $HOME/.mastermind as an ancestor —
# so with the override set it still answered from the user's installed brain. Routing QA
# certified an older install instead of the checkout it was pointed at.
OVER="$WORK/override"; mkdir -p "$OVER/home/.mastermind" "$OVER/home/proj" "$OVER/checkout"
echo "0.0.0-user-install" > "$OVER/home/.mastermind/VERSION"
echo "9.9.9-under-test"   > "$OVER/checkout/VERSION"
out=$(cd "$OVER/home/proj" && HOME="$OVER/home" MASTERMIND_HOME="$OVER/checkout" "${CLI[@]}" skills --json | head -3)
case "$out" in *"$OVER/checkout"*) ok "MASTERMIND_HOME wins over the walk-up";; *) bad "override ignored: $out";; esac
out=$(cd "$OVER/home/proj" && HOME="$OVER/home" "${CLI[@]}" skills --json | head -3)
case "$out" in *"$OVER/home/.mastermind"*) ok "without the override the walk-up still finds ~/.mastermind";; *) bad "walk-up broke: $out";; esac

# The win32 refusal used to tell people to use Git Bash — but Git Bash runs the Windows build of
# Node, so it hits this same branch. Advertising a path the guard rejects is worse than silence.
msg=$(grep -A3 "process.platform === 'win32'" "$ROOT/cli/bin/mastermind.mjs" | grep -c "Git Bash will not work")
case "$msg" in 1) ok "the Windows refusal no longer advertises Git Bash as working";; *) bad "Git Bash still advertised";; esac

# A published release must verify what it executes. Both holes below were reproduced by an
# external audit against the signed 0.29.2 package, so they are tested against a build that
# carries a pin (a local checkout has none, and skips verification by design).
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

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
