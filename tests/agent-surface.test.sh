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
out=$(cd "$ROOT" && "${CLI[@]}" route "anything at all" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d["skills"]) > 10)' 2>/dev/null)
check "large piped json is not truncated" "$out" "True"

GONE="$WORK/gone"; mkdir -p "$GONE"
out=$( (cd "$GONE" && rm -rf "$GONE" && "${CLI[@]}" skills 2>&1 >/dev/null) | head -1 )
case "$out" in *"uv_cwd"*|*"internal/bootstrap"*) bad "deleted cwd crashes with a node stack";; *) ok "deleted cwd fails cleanly";; esac

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
