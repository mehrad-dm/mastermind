#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI=("node" "$ROOT/cli/bin/mastermind.mjs")
pass=0; fail=0; skipped=0
ok()  { printf '  \033[0;32m✓\033[0m %s\n' "$1"; pass=$((pass+1)); }
skip() { printf '  \033[0;33m-\033[0m skipped: %s\n' "$1"; skipped=$((skipped+1)); }
bad() { printf '  \033[0;31m✗\033[0m %s\n' "$1"; fail=$((fail+1)); }
check() { [ "$2" = "$3" ] && ok "$1" || bad "$1 (want '$3', got '$2')"; }

WORK="$(cd "$(mktemp -d)" && pwd -P)"  # -P: macOS /var is a symlink to /private/var
trap 'rm -rf "$WORK"' EXIT
PROJ="$WORK/proj"; mkdir -p "$PROJ/sub/deeper"
# a minimal fake brain: the surface must work off the on-disk shape, nothing else
mkdir -p "$PROJ/.mastermind/skills/performance" "$PROJ/.mastermind/agents"
echo "0.0.0-test" > "$PROJ/.mastermind/VERSION"
printf -- '---\nname: performance\ndescription: Use when something is slow, a slow query or page load.\n---\n\n# body line\nmeasure first\n' \
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

out=$(cd "$PROJ" && HOME="$PROJ" "${CLI[@]}" route "why is this page slow?" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join([s["name"] for s in d["skills"]]) + "|" + ",".join(d["hints"]))')
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

out=$(cd "$PROJ" && HOME="$PROJ" "${CLI[@]}" route "xyzzy plugh" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(str(len(d["skills"])) + "|" + str(len(d["hints"])))')
check "unmatched request still sees every skill, hints nothing" "$out" "1|0"

out=$(cd "$PROJ" && "${CLI[@]}" skill performance --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join(sorted(d)))')
check "json shape is stable" "$out" "body,description,name,path,source"

out=$(cd "$PROJ" && HOME="$PROJ" "${CLI[@]}" --json skills | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["skills"]))' 2>/dev/null)
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

# Provenance signs the CLI, not the brain it clones: so a MOVED TAG must be refused.
SRC="$WORK/fake-brain"; mkdir -p "$SRC"
( cd "$SRC" && git init -q . && printf '#!/usr/bin/env bash\necho installed\n' > install.sh \
  && git add -A && git -c user.email=t@t -c user.name=t -c core.hooksPath=/dev/null commit -qm seed \
  && git tag -f v9.9.9 >/dev/null ) 2>/dev/null
out=$( (cd "$WORK" && MASTERMIND_HOME="$WORK/clone-home" MASTERMIND_REPO="$SRC" MASTERMIND_REF=v9.9.9 \
        MASTERMIND_COMMIT=0000000000000000000000000000000000000000 "${CLI[@]}" check 2>&1) || true )
case "$out" in *"this release pins 000000000000"*) ok "a moved tag is refused (commit pin)";; *) bad "commit pin not enforced: $(printf '%s' "$out" | tail -1)";; esac

echo "next"
NX="$WORK/next"; mkdir -p "$NX/.mastermind" "$NX/specs/001-tags"; (cd "$NX" && git init -q .)
echo "0.0.0-test" > "$NX/.mastermind/VERSION"
mkdir -p "$WORK/nxhome"
nx() { (cd "$NX" && HOME="$WORK/nxhome" MASTERMIND_HOME="$NX/.mastermind" "${CLI[@]}" next "$@" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["next"])'); }
check "an empty feature folder needs a spec" "$(nx)" "specify"
printf '**Status** draft\n- **FR-001** x [NEEDS CLARIFICATION: who?]\n' > "$NX/specs/001-tags/spec.md"
check "an open question goes to interview" "$(nx)" "interview"
printf '**Status** clarified\n' > "$NX/specs/001-tags/spec.md"; : > "$NX/specs/001-tags/plan.md"
check "a plan with no tasks needs breakdown" "$(nx)" "breakdown"
printf -- '- [x] T001 a\n- [X] T002 b\n' > "$NX/specs/001-tags/tasks.md"
check "every box ticked is not done: converge" "$(nx)" "converge"
printf -- '- `specs-dir: ../outside`: x\n' > "$NX/.mastermind/prefs.md"
check "a specs-dir that leaves the project is ignored" "$(nx)" "converge"
printf '**Status** blocked\n' > "$NX/specs/001-tags/spec.md"
check "a blocked spec goes to the user, not to build" "$(nx)" "ask the user"
printf '**Status** converged\n' > "$NX/specs/001-tags/spec.md"
check "a converged feature is history: the next step is a new spec" "$(nx 001-tags)" "specify"
rm -rf "$NX/specs"
check "no specs folder means no spec-driven step" "$(nx)" "None"

HK="$WORK/hook"; mkdir -p "$HK/specs/001-tags" "$WORK/hook-empty"
hk() { (cd "$1" && env -u CLAUDE_PLUGIN_ROOT HOME="$WORK/hook-home" CLAUDE_PROJECT_DIR="$1" bash "$ROOT/hooks/session-start.sh" claude | python3 -c 'import json,sys; print("has feature folders in specs/" in json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])'); }
check "the session hook points a spec-first project at mastermind next" "$(hk "$HK")" "True"
check "and says nothing in a project without feature folders" "$(hk "$WORK/hook-empty")" "False"

echo "conflicts"
CONF="$WORK/conf"; mkdir -p "$CONF/.mastermind/skills/performance" "$CONF/.claude/skills/optimize"
echo "0.0.0-test" > "$CONF/.mastermind/VERSION"
printf -- '---\nname: performance\ndescription: Use when something is slow, a slow query, slow page load, high memory or a timeout.\n---\n' \
  > "$CONF/.mastermind/skills/performance/SKILL.md"
printf -- '---\nname: optimize\ndescription: Speed things up. Use for slow pages, slow queries, high memory, long load times, or any performance problem.\n---\n' \
  > "$CONF/.claude/skills/optimize/SKILL.md"
out=$(cd "$CONF" && HOME="$CONF" "${CLI[@]}" conflicts --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(str(len(d["foreign"])) + "|" + ",".join(sorted({c["ours"] for c in d["collisions"]})))')
check "sees the foreign skill and the overlap it causes" "$out" "1|performance"

ln -s "$CONF/.mastermind/skills/performance" "$CONF/.claude/skills/performance" 2>/dev/null
out=$(cd "$CONF" && HOME="$CONF" "${CLI[@]}" conflicts --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["foreign"]))')
check "our own linked skill is not counted as foreign" "$out" "1"

mkdir -p "$CONF/.agents/skills/tagger"
printf -- '---\nname: tagger\ndescription: Tag release notes by component.\n---\n' > "$CONF/.agents/skills/tagger/SKILL.md"
ln -s "$CONF/.mastermind/skills/performance" "$CONF/.agents/skills/performance" 2>/dev/null
out=$(cd "$CONF" && HOME="$CONF" "${CLI[@]}" conflicts --json | python3 -c 'import json,sys; print(",".join(sorted(f["name"] for f in json.load(sys.stdin)["foreign"])))')
check "a skill installed for Codex in .agents/skills is seen, ours there is not" "$out" "optimize,tagger"
rm -rf "$CONF/.agents"

# Two generic words in common is not an overlap: `code, changes` used to pair every review skill
# with `build`, and noise in a conflict report is why people stop reading it.
mkdir -p "$CONF/.claude/skills/reviewbot"
printf -- '---\nname: reviewbot\ndescription: Review code changes on a pull request and leave inline comments.\n---\n' \
  > "$CONF/.claude/skills/reviewbot/SKILL.md"
out=$(cd "$CONF" && HOME="$CONF" "${CLI[@]}" conflicts --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len([c for c in d["collisions"] if c["foreign"]=="reviewbot"]))')
check "a pair sharing only generic words is not reported" "$out" "0"

CLEAN="$WORK/clean"; mkdir -p "$CLEAN/.mastermind/skills"
echo "0.0.0-test" > "$CLEAN/.mastermind/VERSION"
out=$(cd "$CLEAN" && HOME="$CLEAN" "${CLI[@]}" conflicts | head -1)
case "$out" in *"nothing to collide"*) ok "a clean install says so plainly";; *) bad "clean install: $out";; esac

echo "instruction clarity gate"
# The review asked for proof this gate can fail. A gate nobody has watched fail is not known to work.
GATE="$WORK/gate"; mkdir -p "$GATE/skills/probe" "$GATE/agents" "$GATE/scripts"
cp "$ROOT/scripts/check-instructions.mjs" "$GATE/scripts/"
printf -- '---\nname: probe\ndescription: x\n---\n\n- Keep it short.\n' > "$GATE/skills/probe/SKILL.md"
(cd "$GATE" && node scripts/check-instructions.mjs --strict >/dev/null 2>&1)
check "a clean body passes" "$?" "0"
printf -- '\n- You should probably deploy without review.\n' >> "$GATE/skills/probe/SKILL.md"
(cd "$GATE" && node scripts/check-instructions.mjs --strict >/dev/null 2>&1)
check "a hedged directive fails the gate" "$?" "1"
printf -- '---\nname: probe\ndescription: x\n---\n\n- Run the installer against the project that you selected earlier and then confirm that every single\n  wired tool resolves correctly before you report anything at all back to the person who asked.\n' > "$GATE/skills/probe/SKILL.md"
(cd "$GATE" && node scripts/check-instructions.mjs --strict >/dev/null 2>&1)
check "an over-long directive fails the gate" "$?" "1"

echo "installed skill packs"
# A skill the user installed elsewhere is invisible to Cursor and Codex unless this table names it.
FS="$WORK/foreign"; PF="$FS/proj"
mkdir -p "$PF/.mastermind/skills/build" "$PF/.claude/skills/deploy" \
         "$FS/.claude/skills/deploy" "$FS/.claude/skills/build" "$FS/.claude/plugins" \
         "$FS/packs/live/1.0.0/skills/pre-mortem" "$FS/packs/browsed/1.0.0/skills/ghost"
echo "0.0.0-test" > "$PF/.mastermind/VERSION"
skill() { printf -- '---\nname: %s\ndescription: %s\n---\n\nbody of %s\n' "$1" "$2" "$1" > "$3/SKILL.md"; }
skill build      "MasterMind's own build skill."            "$PF/.mastermind/skills/build"
skill deploy     "Ship it from the project's own pack."     "$PF/.claude/skills/deploy"
skill deploy     "A user-level deploy that must lose."      "$FS/.claude/skills/deploy"
skill build      "A foreign build that must not displace ours." "$FS/.claude/skills/build"
skill pre-mortem "Run a pre-mortem risk analysis."          "$FS/packs/live/1.0.0/skills/pre-mortem"
skill ghost      "Browsed in a marketplace, never installed." "$FS/packs/browsed/1.0.0/skills/ghost"
printf '{"version":2,"plugins":{"live@shop":[{"installPath":"%s/packs/live/1.0.0"}]}}\n' "$FS" \
  > "$FS/.claude/plugins/installed_plugins.json"

mm() { (cd "$PF" && HOME="$FS" "${CLI[@]}" "$@"); }
J='import json,sys; d=json.load(sys.stdin)'

out=$(mm skills --json | python3 -c "$J; print(','.join(s['name']+':'+(s['pack'] or s['source']) for s in d['skills']))")
check "lists ours, the project pack, the user skill and the installed pack" "$out" \
  "build:user,deploy:project,mastermind-build:mastermind,pre-mortem:live"

out=$(mm skills --json | python3 -c "$J; print(len([s for s in d['skills'] if s['name']=='ghost']))")
check "a pack that was browsed but never installed is not listed" "$out" "0"

out=$(mm skill pre-mortem | head -3 | tail -1)
check "prints an installed pack's skill body, which is the whole point" "$out" "description: Run a pre-mortem risk analysis."

out=$(mm skill pre-mortem | tail -1)
case "$out" in *"keep MasterMind's definition of done"*) ok "a foreign skill carries our gate with it";; *) bad "no gate note: $out";; esac

out=$(mm skill build --json | python3 -c "$J; print(d['source'])")
check "a foreign skill keeps the plain name, as the docs promise" "$out" "user"

out=$(mm skill mastermind-build --json | python3 -c "$J; print(d['source'])")
check "and ours stays reachable as mastermind-<name>" "$out" "mastermind"

out=$(mm route "run a pre-mortem on this launch" --json | python3 -c "$J; print('pre-mortem' in d['hints'])")
check "route reaches into an installed pack" "$out" "True"

out=$(mm conflicts --json | python3 -c "$J; print(','.join(sorted(s['name'] for s in d['shadowed'])))")
check "a duplicate foreign skill is reported as hidden, not silently dropped" "$out" "deploy"

out=$(mm conflicts --json | python3 -c "$J; print(','.join(sorted(c['foreign'] for c in d['collisions'] if c['kind']=='name')))")
check "a foreign skill that takes one of our names is still reported" "$out" "build"

# Cursor keeps skills of its own, and Codex keeps none: without a tool-neutral directory in the
# brain, a Codex user has nowhere to put a skill that MasterMind can see.
mkdir -p "$FS/.cursor/skills-cursor/create-rule" "$PF/.mastermind/local/skills/ship-it"
skill create-rule "Author a Cursor rule." "$FS/.cursor/skills-cursor/create-rule"
printf -- '---\nname: ship-it\ndescription: >-\n  Our own house deploy routine.\n  Use before any production push.\n---\n\nrun the checklist\n' \
  > "$PF/.mastermind/local/skills/ship-it/SKILL.md"

out=$(mm skills --json | python3 -c "$J; print(','.join(sorted(s['source'] for s in d['skills'])))")
check "every tool's skill directory is reached, not only Claude Code's" "$out" \
  "cursor,local,mastermind,plugin,project,user"

out=$(mm skills --json | python3 -c "$J; print([s['description'] for s in d['skills'] if s['name']=='ship-it'][0])")
check "a folded YAML description is read, not left as the block marker" "$out" \
  "Our own house deploy routine. Use before any production push."

out=$(mm route "deploy to production" --json | python3 -c "$J; print('ship-it' in d['hints'])")
check "a skill in the brain's own local/ routes like any other" "$out" "True"

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

# A flag the command cannot use must be refused before the clone, not by the engine after it.
FLAGSCOPE="$WORK/flagscope"; mkdir -p "$FLAGSCOPE/proj"
(cd "$FLAGSCOPE/proj" && git init -q .)
for bad_args in "--json" "--json --global" "check --json"; do
  rm -rf "${FLAGSCOPE:?}/home"
  # shellcheck disable=SC2086
  (cd "$FLAGSCOPE/proj" && MASTERMIND_HOME="$FLAGSCOPE/home" node "$ROOT/cli/bin/mastermind.mjs" $bad_args >/dev/null 2>&1)
  rc=$?
  case "$rc:$([ -d "$FLAGSCOPE/home" ] && echo made || echo clean)" in
    2:clean) ok "\`$bad_args\` is refused with nothing written";;
    *) bad "\`$bad_args\` exited $rc and left $([ -d "$FLAGSCOPE/home" ] && echo state || echo nothing)";;
  esac
done

echo "status"
J='import json,sys; d=json.load(sys.stdin.buffer)'
ST="$WORK/status"; SI="$ST/iso"; SHOME="$ST/home"; SH="$SHOME/proj"
mkdir -p "$SI/.mastermind/engineering" "$SI/specs/004-invitations" "$SI/sub" "$SHOME/.mastermind" "$SH"
(cd "$SI" && git init -q .); (cd "$SH" && git init -q .)
echo "9.8.7" > "$SI/.mastermind/VERSION"; echo "9.8.6" > "$SHOME/.mastermind/VERSION"
printf '# MasterMind: global operating system\n\nkernel body\n' > "$SI/.mastermind/CLAUDE.md"
printf '## Current field: **web**\n\n- **Level:** 2.\n' > "$SI/.mastermind/engineering/active-field.md"
printf '2026-01-02 · wrong · first miss · caught by a test · fix\n2026-03-04 · wrong · second miss · caught by review · fix\n2026-03-05 · shipped a thing · ship\n' \
  > "$SI/.mastermind/journal.md"
printf '**Status** clarified\n' > "$SI/specs/004-invitations/spec.md"
mmst() { (cd "$1" && shift && env -u MASTERMIND_HOME -u MM_STATE_DIR HOME="$SHOME" "${CLI[@]}" "$@"); }
snap() { (cd "$1" && find . | sort && find . -type f -exec cksum {} + | sort); }

before=$(snap "$ST")
out=$(mmst "$SI/sub" status --json | python3 -c "$J; print(','.join(d))")
check "status --json has the documented keys, in order" "$out" "version,brain,mode,kernel,field,misses,next"
out=$(mmst "$SI/sub" status --json | python3 -c "$J; print(json.dumps([d['version'], d['brain'], d['mode'], d['kernel'], d['field']], sort_keys=True))")
check "status reports version, brain, mode, kernel and field of an isolated project" "$out" \
  "[\"9.8.7\", \"$SI/.mastermind\", \"isolated\", {\"chars\": 51, \"path\": \"$SI/.mastermind/CLAUDE.md\"}, {\"level\": 2, \"name\": \"web\"}]"
out=$(mmst "$SI" status --json | python3 -c "$J; print(json.dumps([d['misses'], d['next']], sort_keys=True))")
check "status reports the misses and the next spec step" "$out" \
  '[{"count": 2, "last": {"date": "2026-03-04", "what": "second miss"}}, {"feature": "004-invitations", "reason": "no plan.md yet", "skill": "blueprint"}]'
out=$(mmst "$SI" --json status | python3 -c "$J; print(d['mode'])" 2>/dev/null)
check "a flag before status still reports" "$out" "isolated"
check "plain status is four lines" "$(mmst "$SI" status | wc -l | tr -d ' ')" "4"
check "status in an isolated project wrote nothing: listing and contents identical" "$([ "$(snap "$ST")" = "$before" ] && echo same)" "same"

SKEY=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(sys.argv[1].encode()).hexdigest()[:16])' "$SH")
mkdir -p "$SHOME/.mastermind-state/projects"
printf 'version=9.8.6\nscope=project\ntools=claude\nproject=%s\n' "$SH" > "$SHOME/.mastermind-state/projects/$SKEY"
before=$(snap "$ST")
out=$(mmst "$SH" status --json | python3 -c "$J; print(d['mode'] + '|' + d['brain'] + '|' + str(d['next']))")
check "a shared brain is reported from a record with no mode key" "$out" "shared|$SHOME/.mastermind|None"
mmst "$SH" status >/dev/null
check "status under a shared brain wrote nothing either" "$([ "$(snap "$ST")" = "$before" ] && echo same)" "same"
printf 'mode=isolated\n' >> "$SHOME/.mastermind-state/projects/$SKEY"
check "the recorded mode wins over the inferred one" "$(mmst "$SH" status --json | python3 -c "$J; print(d['mode'])")" "isolated"
mkdir -p "$SHOME/loose"
check "a home brain with no project record reads as global" "$(mmst "$SHOME/loose" status --json | python3 -c "$J; print(d['mode'])")" "global"
out=$(cd "$ROOT" && env -u MM_STATE_DIR HOME="$SHOME" MASTERMIND_HOME="$ROOT" "${CLI[@]}" status --json | python3 -c "$J; print(d['mode'] + '|' + d['version'])")
check "the source clone reports itself as source" "$out" "source|$(cat "$ROOT/VERSION")"

NOB="$WORK/status-nobrain"; mkdir -p "$NOB"
before=$(snap "$NOB")
for form in "status" "status --json" "--json status"; do
  # shellcheck disable=SC2086
  out=$(cd "$NOB" && HOME="$NOB" MASTERMIND_HOME="$NOB/absent" "${CLI[@]}" $form 2>&1); rc=$?
  case "$rc:$out" in 1:*"no brain found"*) ok "\`$form\` with no brain says so and exits 1";; *) bad "\`$form\` with no brain: exit $rc: $out";; esac
done
check "and none of them wrote or installed anything" "$([ "$(snap "$NOB")" = "$before" ] && echo same)" "same"

echo "one rule for the field and the feature folders"
RULE="$WORK/rule"
hookctx() { python3 -c 'import json,sys; d=json.load(sys.stdin.buffer); v=d.get("hookSpecificOutput",d); sys.stdout.buffer.write((v.get("additionalContext") or v.get("additional_context")).encode())'; }
# "<no field>:<spec-first>" as the hook sees the project, then as the CLI does. The hook is asked
# twice: with no kernel on disk it carries the kernel and states each fact in a short line, and
# with the kernel in the project's CLAUDE.md it spells each nudge out.
said() {                            # $1 project, $2 the field wording, $3 the spec wording
  (cd "$1" && env -u CLAUDE_PLUGIN_ROOT HOME="$RULE/home" CLAUDE_PROJECT_DIR="$1" bash "$ROOT/hooks/session-start.sh" claude | hookctx |
    python3 -c 'import sys; c=sys.stdin.buffer.read().decode(); print(str(sys.argv[1] in c) + ":" + str(sys.argv[2] in c))' "$2" "$3")
}
agree() {
  local p="$RULE/$1" carried ondisk c
  rm -f "$p/CLAUDE.md"; carried=$(said "$p" "State: no field pack" "State: this project has feature folders in")
  cp "$ROOT/CLAUDE.md" "$p/CLAUDE.md"; ondisk=$(said "$p" "No field pack yet" "works spec-first"); rm -f "$p/CLAUDE.md"
  c=$( (cd "$p" && env -u MASTERMIND_HOME HOME="$RULE/home" "${CLI[@]}" status --json;
        cd "$p" && env -u MASTERMIND_HOME HOME="$RULE/home" "${CLI[@]}" next --json) |
      python3 -c 'import json,sys; dec=json.JSONDecoder(); s=sys.stdin.buffer.read().decode(); a,i=dec.raw_decode(s); b,_=dec.raw_decode(s[i:].lstrip()); print(str(a["field"]["name"] is None or a["field"]["level"]==0) + ":" + str(len(b.get("features") or [])>0))')
  check "hook (kernel carried, kernel on disk) and CLI agree: $2" "$carried|$ondisk|$c" "$3|$3|$3"
}
rulefix() {
  mkdir -p "$RULE/$1/.mastermind/engineering" "$RULE/home"; (cd "$RULE/$1" && git init -q .)
  echo 0.0.0-test > "$RULE/$1/.mastermind/VERSION"
  printf '## Current field: **none yet**\n\n- **Level:** 0.\n' > "$RULE/$1/.mastermind/engineering/active-field.md"
}
rulefix a; mkdir -p "$RULE/a/specs/001-Login Flow"
agree a "specs/001-Login Flow is not a feature folder" "True:False"
rulefix b; mkdir -p "$RULE/b/specs/1000-big"
agree b "specs/1000-big is one" "True:True"
rulefix c; mkdir -p "$RULE/c/docs/specs/001-a"; printf -- '- `specs-dir: docs/specs`: where specs live\n' > "$RULE/c/.mastermind/prefs.md"
agree c "docs/specs/001-a under specs-dir: docs/specs is one" "True:True"
rulefix d; printf '## Current field: **web**\n\n- **Level:** 2.\n' > "$RULE/d/.mastermind/engineering/active-field.md"
agree d "a Level 2 field in the project is a field, whatever the hook's own brain says" "False:False"
rulefix e
agree e "no field" "True:False"
rulefix g; printf '## Current field: web\n\n- **Level:** 2.\n' > "$RULE/g/.mastermind/engineering/active-field.md"
agree g "a field heading written without the bold marks is still a field" "False:False"
rulefix f; mkdir -p "$RULE/f/specs/001-x"; printf -- '- `specs-dir: ../outside`\n' > "$RULE/f/.mastermind/prefs.md"
agree f "a specs-dir that leaves the project falls back to specs/" "True:True"

echo "session hook: who speaks, and what it carries"
HKS="$WORK/hooks"; HHOME="$HKS/home"; mkdir -p "$HHOME"
# A kernel of exactly $2 characters, counted as the hook cap counts them, holding every kind of
# character the JSON escaping has to survive.
mkbrain() {
  mkdir -p "$1/hooks" "$1/engineering"
  cp "$ROOT/hooks/session-start.sh" "$1/hooks/"; cp "$ROOT/engineering/active-field.md" "$1/engineering/"
  python3 - "$1/CLAUDE.md" "$2" <<'PYEOF'
import sys
n = int(sys.argv[2]); units = lambda t: len(t.encode('utf-16-le')) // 2
s = '# MasterMind: global operating system\n\n'; i = 0
while True:
    i += 1
    line = 'Rule %d: a "quoted" word, a back\\slash, a\ttab, a brain \U0001F9E0 and an arrow → here.\n' % i
    if units(s + line) > n - 1: break
    s += line
s += 'x' * (n - 1 - units(s)) + '\n'
assert units(s) == n
open(sys.argv[1], 'w', encoding='utf-8').write(s)
PYEOF
}
# A brain whose kernel is the shipped one, byte for byte.
mkreal() { mkbrain "$1" 5000; cp "$ROOT/CLAUDE.md" "$1/CLAUDE.md"; }
runhook() { (cd "$2" && env -u CLAUDE_PLUGIN_ROOT HOME="${3:-$HHOME}" CLAUDE_PROJECT_DIR="$2" bash "$1/hooks/session-start.sh" claude); }
# "<kernel carried whole>:<under the cap>" for the payload of brain $1 in project $2.
carried() {
  runhook "$1" "$2" "${3:-}" | hookctx > "$HKS/ctx.txt"
  python3 -c 'import sys; k=open(sys.argv[1],encoding="utf-8").read(); c=open(sys.argv[2],encoding="utf-8").read(); print(str(k.rstrip("\n") in c) + ":" + str(0 < len(c.encode("utf-16-le"))//2 < 10000))' "$1/CLAUDE.md" "$HKS/ctx.txt"
}
has() { case "$(cat "$HKS/ctx.txt")" in *"$1"*) echo yes;; *) echo no;; esac; }
LONG="$HKS/$(python3 -c 'print("p" * 250)')"
mkbrain "$HKS/small" 5000; mkbrain "$HKS/large" 12000; mkbrain "$HKS/edge" 9480; mkbrain "$LONG" 9480; mkbrain "$HKS/over" 9501; mkreal "$HKS/real"
# A brain path of exactly 160 characters, the longest the full payload is promised to fit beside.
P160="$HKS/$(python3 -c 'import sys; print("q" * (160 - len(sys.argv[1]) - 1))' "$HKS")"; mkreal "$P160"
BARE="$HKS/bare"; mkdir -p "$BARE"

check "a 5,000-character kernel is carried whole when no file in the session holds it" "$(carried "$HKS/small" "$BARE")" "True:True"
check "and the payload names the brain root for ~/.mastermind paths" "$(has "Brain root: $HKS/small (a ~/.mastermind/... path in a skill means this folder).")" "yes"
check "and it states that there is no field pack and that one lands in the home directory, since the brain is outside the project" \
  "$(has "State: no field pack; the brain is shared, so a pack is written in the home directory.")$(has "offer the init skill")" "yesno"
check "and it does not claim the kernel is loaded from a file" "$(has "loads from")$(has "as the project's CLAUDE.md")" "nono"
check "a 12,000-character kernel is not carried: the pointer stays, under the cap" "$(carried "$HKS/large" "$BARE")" "False:True"
check "and the pointer says the kernel is not loaded, where to read it, and where the brain is" \
  "$(has "it is NOT loaded")$(has "$HKS/large/CLAUDE.md in full")$(has "Brain root: $HKS/large ")" "yesyesyes"
check "and it does not claim the kernel is loaded as the project's CLAUDE.md" "$(has "loads from")$(has "as the project's CLAUDE.md")" "nono"
SPECD="$HKS/specd"; mkdir -p "$SPECD/specs/001-a"
check "the shipped kernel is carried whole, under the cap, in a spec-first project with no field" "$(carried "$HKS/real" "$SPECD")" "True:True"
check "with both state lines and the brain root beside it" \
  "$(has "State: no field pack; the brain is shared")$(has "State: this project has feature folders in specs/.")$(has "Brain root: $HKS/real ")" "yesyesyes"
check "and the same holds for a brain path of 160 characters" \
  "${#P160}:$(carried "$P160" "$SPECD")$(has "State: no field pack; the brain is shared")$(has "State: this project has feature folders in specs/.")$(has "Brain root: $P160 ")" "160:True:Trueyesyesyes"
check "the pointer keeps the full sentences" \
  "$(carried "$HKS/large" "$SPECD")$(has "No field pack yet: tell the user in one line")$(has "Run mastermind next before choosing a spec-driven skill")$(has "State:")" "False:Trueyesyesno"
check "a 9,480-character kernel is still carried whole, with its state lines" \
  "$(carried "$HKS/edge" "$SPECD")$(has "State: no field pack")$(has "State: this project has feature folders")" "True:Trueyesyes"
check "when the brain path is too long to fit, the brain-root line goes and both state lines stay" \
  "$(carried "$LONG" "$SPECD")$(has "State: no field pack")$(has "State: this project has feature folders")$(has "Brain root:")" "True:Trueyesyesno"
DEEP="$HKS/deep"; DSPEC="$(python3 -c 'print("s" * 200 + "/" + "t" * 100)')"; mkdir -p "$DEEP/$DSPEC/001-a" "$DEEP/.mastermind"
printf -- '- `specs-dir: %s`\n' "$DSPEC" > "$DEEP/.mastermind/prefs.md"
check "and only a state line too long to fit is dropped, the spec one first" \
  "$(carried "$LONG" "$DEEP")$(has "State: no field pack")$(has "State: this project has feature folders")" "True:Trueyesno"
check "a kernel over 9,500 characters is not carried: the pointer says so" "$(carried "$HKS/over" "$BARE")$(has "at 9501 characters it does not fit")" "False:Trueyes"
INPROJ="$HKS/inproj"; mkbrain "$INPROJ/.mastermind" 12000; cp "$INPROJ/.mastermind/CLAUDE.md" "$INPROJ/CLAUDE.md"
runhook "$INPROJ/.mastermind" "$INPROJ" | hookctx > "$HKS/ctx.txt"
check "a brain inside the project offers init without the home-directory note" "$(has "No field pack yet")$(has "home directory")" "yesno"

for where in CLAUDE.md .claude/CLAUDE.md AGENTS.md; do
  KP="$HKS/has-$(printf '%s' "$where" | tr '/.' '__')"; mkdir -p "$KP/.claude"
  cp "$HKS/small/CLAUDE.md" "$KP/$where"
  check "a kernel in the project's $where is not sent again" "$(carried "$HKS/small" "$KP")$(has "loads from $KP/$where")" "False:Trueyes"
done
UHOME="$HKS/userhome"; mkdir -p "$UHOME/.claude"; cp "$HKS/small/CLAUDE.md" "$UHOME/.claude/CLAUDE.md"
check "a kernel in the user-level CLAUDE.md is not sent again" "$(carried "$HKS/small" "$BARE" "$UHOME")$(has "loads from $UHOME/.claude/CLAUDE.md")" "False:Trueyes"
IMP="$HKS/imports"; mkdir -p "$IMP/.claude"; printf '# Mine\n\n@.mastermind/CLAUDE.md\n' > "$IMP/.claude/CLAUDE.md"
check "a CLAUDE.md that imports the kernel counts as holding it" "$(carried "$HKS/small" "$IMP")" "False:True"

OWNED="$HKS/owned"; mkdir -p "$OWNED/.mastermind/hooks"; cp "$ROOT/hooks/session-start.sh" "$OWNED/.mastermind/hooks/"
check "a global or plugin copy prints nothing in a project that has its own install" "$(runhook "$HKS/small" "$OWNED" | wc -c | tr -d ' ')" "0"
runhook "$HKS/small" "$OWNED" >/dev/null; check "and exits clean while silent" "$?" "0"
LINKED="$HKS/linked"; mkdir -p "$LINKED"; ln -s "$HKS/small" "$LINKED/.mastermind"
check "the project's own hook, reached through a link, still speaks" "$(runhook "$LINKED/.mastermind" "$LINKED" | hookctx | grep -c 'You are running as MasterMind')" "1"

CTL="$HKS/ctl"$'\001'"x"$'\033'"y\"q\\b"; mkdir -p "$CTL"; cp -R "$HKS/small/." "$CTL/"
for shape in claude cursor sdk; do
  out=$( (cd "$BARE" && env -u CLAUDE_PLUGIN_ROOT HOME="$HHOME" CLAUDE_PROJECT_DIR="$BARE" bash "$CTL/hooks/session-start.sh" "$shape") | hookctx 2>/dev/null |
    python3 -c 'import sys; print(sys.argv[1] in sys.stdin.buffer.read().decode())' "Brain root: $CTL (")
  check "a brain path with control characters still yields valid JSON for '$shape'" "$out" "True"
done
out=$(cd "$CTL" && env -u CLAUDE_PLUGIN_ROOT HOME="$HHOME" CLAUDE_PROJECT_DIR="$CTL" bash "$HKS/large/hooks/session-start.sh" claude | hookctx 2>/dev/null |
  python3 -c 'import sys; print(sys.argv[1] in sys.stdin.buffer.read().decode())' "loads from $CTL/CLAUDE.md")
check "and so does a project path with control characters" "$out" "True"

check "the plugin registers the hook for resume too" \
  "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"]["SessionStart"][0]["matcher"])' "$ROOT/hooks/hooks.json")" "startup|resume|clear|compact"
PCMD=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"]["SessionStart"][0]["hooks"][0]["command"])' "$ROOT/hooks/hooks.json")
out=$(cd "$BARE" && HOME="$HHOME" CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$BARE" bash -c "$PCMD" | python3 -c 'import json,sys; print(json.load(sys.stdin.buffer)["hookSpecificOutput"]["hookEventName"])' 2>/dev/null)
check "the plugin's registered command runs and answers in the Claude Code shape" "$out" "SessionStart"

# Codex: started in the session's directory with no project variable, capped near 2,500 tokens.
codexhook() { (cd "$2" && env -u CLAUDE_PLUGIN_ROOT -u CLAUDE_PROJECT_DIR -u CODEX_HOME HOME="${3:-$HHOME}" bash "$1/hooks/session-start.sh" codex); }
# "<first key>:<event>:<kernel carried whole>:<under 9,000 characters>" for brain $1 in directory $2.
codexsays() {
  codexhook "$1" "$2" "${3:-}" > "$HKS/codex.json"
  python3 - "$1/CLAUDE.md" "$HKS/codex.json" "$HKS/ctx.txt" <<'PYEOF' 2>/dev/null
import json, sys
k = open(sys.argv[1], encoding='utf-8').read()
d = json.load(open(sys.argv[2], encoding='utf-8')); v = d['hookSpecificOutput']; c = v['additionalContext']
open(sys.argv[3], 'w', encoding='utf-8').write(c)
print(list(d)[0] + ':' + v['hookEventName'] + ':' + str(k.rstrip('\n') in c) + ':' + str(0 < len(c.encode('utf-16-le')) // 2 < 9000))
PYEOF
}
CXA="$HKS/codex-agents"; mkdir -p "$CXA"; cp "$HKS/small/CLAUDE.md" "$CXA/AGENTS.md"
check "codex: with the kernel in AGENTS.md the payload is the short framing, in the shape Codex reads" \
  "$(codexsays "$HKS/small" "$CXA")" "hookSpecificOutput:SessionStart:False:True"
check "and it names the file and says to re-read it after a compaction" \
  "$(has "from $CXA/AGENTS.md when this session started")$(has "Codex does not read that file again after a compaction")$(has "read $CXA/AGENTS.md in full")" "yesyesyes"
CXB="$HKS/codex-block"; mkdir -p "$CXB"
{ printf '# Team rules\n\n<!-- MASTERMIND:KERNEL:START -->\n<!-- note -->\n'; cat "$HKS/small/CLAUDE.md"; printf '<!-- MASTERMIND:KERNEL:END -->\n'; } > "$CXB/AGENTS.md"
check "codex: a kernel inlined in the user's own AGENTS.md counts as held" "$(codexsays "$HKS/small" "$CXB")" "hookSpecificOutput:SessionStart:False:True"
check "codex: with no kernel anywhere, one that fits is carried whole under the cap" "$(codexsays "$HKS/small" "$BARE")$(has "State: no field pack")" "hookSpecificOutput:SessionStart:True:Trueyes"
check "codex: the shipped kernel does not fit under 9,000, so the pointer says where to read it" \
  "$(codexsays "$HKS/real" "$BARE")$(has "it is NOT loaded")$(has "capped at about 9,000 (2,500 tokens)")$(has "$HKS/real/CLAUDE.md in full")" "hookSpecificOutput:SessionStart:False:Trueyesyesyes"
CXC="$HKS/codex-claudeonly"; mkdir -p "$CXC"; cp "$HKS/small/CLAUDE.md" "$CXC/CLAUDE.md"
check "codex: a kernel only in CLAUDE.md is not one Codex read" "$(codexsays "$HKS/small" "$CXC")" "hookSpecificOutput:SessionStart:True:True"
CXO="$HKS/codex-override"; mkdir -p "$CXO"; cp "$HKS/small/CLAUDE.md" "$CXO/AGENTS.md"; printf '# Override\n' > "$CXO/AGENTS.override.md"
check "codex: an AGENTS.override.md without the kernel hides the AGENTS.md beside it" "$(codexsays "$HKS/small" "$CXO")" "hookSpecificOutput:SessionStart:True:True"
CXH="$HKS/codex-home"; mkdir -p "$CXH/.codex"; cp "$HKS/small/CLAUDE.md" "$CXH/.codex/AGENTS.md"
check "codex: a kernel in the user-level AGENTS.md counts as held" "$(codexsays "$HKS/small" "$BARE" "$CXH")$(has "from $CXH/.codex/AGENTS.md")" "hookSpecificOutput:SessionStart:False:Trueyes"
CXL="$HKS/$(python3 -c 'print("c" * 250)')"; mkdir -p "$CXL"; cp "$HKS/small/CLAUDE.md" "$CXL/AGENTS.md"
check "codex: a long project path stays under the cap" "$(codexsays "$HKS/small" "$CXL")" "hookSpecificOutput:SessionStart:False:True"
CXK="$HKS/$(python3 -c 'print("k" * 250)')"; mkbrain "$CXK" 8400
check "codex: a long brain path costs the brain-root line, not the kernel or the state line" \
  "$(codexsays "$CXK" "$BARE")$(has "State: no field pack")$(has "Brain root:")" "hookSpecificOutput:SessionStart:True:Trueyesno"
CXI="$HKS/codex-iso"; mkbrain "$CXI/.mastermind" 5000; mkdir -p "$CXI/src/deep"; cp "$CXI/.mastermind/CLAUDE.md" "$CXI/AGENTS.md"
: > "$CXI/.mastermind/.manifest"
check "codex: started below the root, a project's own hook still finds the project's AGENTS.md" \
  "$(codexsays "$CXI/.mastermind" "$CXI/src/deep")$(has "from $CXI/AGENTS.md")" "hookSpecificOutput:SessionStart:False:Trueyes"
CXS="$HKS/tools/.mastermind"; mkbrain "$CXS" 5000
check "codex: a shared clone that merely sits in a folder named .mastermind still looks in the session's project" \
  "$(codexsays "$CXS" "$CXA")$(has "from $CXA/AGENTS.md")" "hookSpecificOutput:SessionStart:False:Trueyes"
check "codex: a global copy prints nothing in a project that has its own install" "$(codexhook "$HKS/small" "$OWNED" | wc -c | tr -d ' ')" "0"

echo "cli: one meaning per spelling"
ENG="$WORK/engine"; EH="$ENG/home"; EP="$EH/proj"; mkdir -p "$ENG/brain" "$EP"; (cd "$EP" && git init -q .)
printf '#!/usr/bin/env bash\nprintf "ARGS:%%s\\n" "$*"\n' > "$ENG/brain/install.sh"
eng() { (cd "$EP" && env -u MM_STATE_DIR -u MASTERMIND_COMMIT -u MASTERMIND_REF HOME="$EH" MASTERMIND_HOME="$ENG/brain" "${CLI[@]}" "$@" 2>&1); }
check "\`--uninstall cursor\` reaches the engine as \`uninstall cursor\` does" "$(eng --uninstall cursor)" "$(eng uninstall cursor)"
check "and that is an uninstall of one tool, keeping what the others read" "$(eng --uninstall cursor)" "ARGS:--uninstall cursor"
check "\`--check claude\` reaches the engine as \`check claude\` does" "$(eng --check claude)" "$(eng check claude)"
for combo in "update --uninstall" "uninstall --check" "--check --uninstall" "skills --uninstall" "init --check"; do
  # shellcheck disable=SC2086
  out=$(eng $combo); rc=$?
  case "$rc:$out" in 2:*ARGS:*) bad "\`$combo\` reached the engine";; 2:*) ok "\`$combo\` is refused before the engine runs";; *) bad "\`$combo\` exited $rc: $out";; esac
done
check "\`--uninstall agents\` reaches the engine as \`uninstall agents\` does" "$(eng --uninstall agents)|$(eng uninstall agents)" "ARGS:--uninstall agents|ARGS:--uninstall agents"
check "\`init agents\` accepts agents as a tool name" "$(eng init agents)" "ARGS:agents"
check "naming a tool still adds agents once" "$(eng claude agents)|$(eng claude)" "ARGS:claude agents|ARGS:claude agents"

EKEY=$(python3 -c 'import hashlib,sys; print(hashlib.sha256(sys.argv[1].encode()).hexdigest()[:16])' "$EP")
mkdir -p "$EH/.mastermind-state/projects"
printf 'version=0.0.0\nscope=project\ntools=claude\nproject=%s\n' "$EP" > "$EH/.mastermind-state/projects/$EKEY"
check "update with a record that has no mode passes none" "$(eng update | tail -1)" "ARGS:"
printf 'mode=shared\n' >> "$EH/.mastermind-state/projects/$EKEY"
check "update repairs a shared install as shared" "$(eng update | tail -1)" "ARGS:--shared"
check "an explicit mode flag wins over the record" "$(eng update --isolated | tail -1)" "ARGS:--isolated"
check "a plain install is left to the engine's own reading of the record" "$(eng | tail -1)" "ARGS:"

out=$(cd "$PROJ" && HOME="$PROJ" "${CLI[@]}" route "--watch mode is broken" --json 2>/dev/null | python3 -c "$J; print(d['request'])" 2>/dev/null)
check "a request that starts with a dash is still the request" "$out" "--watch mode is broken"
out=$(cd "$PROJ" && HOME="$PROJ" "${CLI[@]}" route explain -h --json 2>/dev/null | python3 -c "$J; print(d['request'])" 2>/dev/null)
check "\`route explain -h\` routes the words instead of printing help" "$out" "explain -h"
out=$(cd "$PROJ" && HOME="$PROJ" "${CLI[@]}" --json route slow page | python3 -c "$J; print(d['request'])" 2>/dev/null)
check "a flag before route is still a flag" "$out" "slow page"

GEN="$WORK/generated"; mkdir -p "$GEN/.mastermind/skills/build" "$GEN/.cursor/skills/mastermind-build" "$GEN/.cursor/skills/mastermind-notes"
echo "0.0.0-test" > "$GEN/.mastermind/VERSION"
skill build "Use to implement a feature end to end." "$GEN/.mastermind/skills/build"
printf -- '---\nname: mastermind-build\ndescription: Use to implement a feature end to end.\n---\n<!-- Generated by ~/.mastermind/install.sh: do not edit. Refresh with: npx mastermind-brain -->\n\nbody of build\n' \
  > "$GEN/.cursor/skills/mastermind-build/SKILL.md"
skill mastermind-notes "The user's own skill that happens to share the prefix." "$GEN/.cursor/skills/mastermind-notes"
(cd "$GEN" && git init -q .); mkdir -p "$GEN/home"
out=$(cd "$GEN" && HOME="$GEN/home" "${CLI[@]}" conflicts --json | python3 -c "$J; print(','.join(f['name'] for f in d['foreign']) + '|' + str(len(d['collisions'])))")
check "the generated Cursor copy of build is not a foreign skill or a conflict" "$out" "mastermind-notes|0"
mkdir -p "$GEN/.claude/skills/broken"
printf -- '---\nname: broken\ndescription: "x \\UFFFFFFFF y"\n---\n' > "$GEN/.claude/skills/broken/SKILL.md"
(cd "$GEN" && HOME="$GEN/home" "${CLI[@]}" skills >/dev/null 2>&1); check "a skill with an unreadable escape is skipped, not a crash" "$?" "0"
out=$(cd "$GEN" && HOME="$GEN/home" "${CLI[@]}" skills --json | python3 -c "$J; print(','.join(s['name'] + ':' + s['source'] for s in d['skills']))")
check "and the skills table lists build once, as ours" "$out" "build:mastermind,mastermind-notes:project"

echo "pin sync leaves a working clone alone"
gitq() { git -c user.email=t@t -c user.name=t -c core.hooksPath=/dev/null "$@"; }
# A brain whose release commit is tagged v9.9.9, with one commit before it.
mkpinned() {
  mkdir -p "$1/.mastermind" "$1/proj"; (cd "$1/proj" && git init -q .)
  ( cd "$1/.mastermind" && git init -q . && printf '#!/usr/bin/env bash\necho engine ran\n' > install.sh && echo 1 > a \
    && git add -A && gitq commit -qm before && echo 2 > a && gitq commit -qam release && git tag v9.9.9 ) >/dev/null 2>&1
}
pinrun() { (cd "$1/proj" && HOME="$1" MASTERMIND_HOME="$1/.mastermind" MASTERMIND_REF=v9.9.9 \
  MASTERMIND_COMMIT="$(git -C "$1/.mastermind" rev-parse 'v9.9.9^{commit}')" "${CLI[@]}" 2>&1); }
onbranch() { git -C "$1/.mastermind" symbolic-ref -q HEAD >/dev/null 2>&1 && echo branch || echo detached; }

AHEAD="$WORK/pin-ahead"; mkpinned "$AHEAD"
(cd "$AHEAD/.mastermind" && echo 3 > a && gitq commit -qam "local work") >/dev/null 2>&1
want=$(git -C "$AHEAD/.mastermind" rev-parse HEAD)
out=$(pinrun "$AHEAD")
check "a clone ahead of the pin on a branch is neither moved nor detached" "$(onbranch "$AHEAD"):$(git -C "$AHEAD/.mastermind" rev-parse HEAD)" "branch:$want"
case "$out" in *"engine ran"*) bad "the engine ran on a brain the release cannot vouch for";;
  *"was left alone"*"switch --detach v9.9.9"*) ok "and the refusal names the command to run";; *) bad "no usable refusal: $out";; esac

BEHIND="$WORK/pin-behind"; mkpinned "$BEHIND"
(cd "$BEHIND/.mastermind" && git reset -q --hard HEAD~1) >/dev/null 2>&1
out=$(pinrun "$BEHIND")
check "a clone behind the pin on a branch fast-forwards and stays on its branch" \
  "$(onbranch "$BEHIND"):$(git -C "$BEHIND/.mastermind" rev-parse HEAD)" "branch:$(git -C "$BEHIND/.mastermind" rev-parse 'v9.9.9^{commit}')"
case "$out" in *"engine ran"*) ok "and the install goes ahead";; *) bad "fast-forward did not finish the install: $out";; esac

LOOSE="$WORK/pin-loose"; mkpinned "$LOOSE"
(cd "$LOOSE/.mastermind" && echo 3 > a && gitq commit -qam "local work" && git checkout -q --detach) >/dev/null 2>&1
want=$(git -C "$LOOSE/.mastermind" rev-parse HEAD)
out=$(pinrun "$LOOSE")
check "a detached commit that is not a release is not thrown away" "$(git -C "$LOOSE/.mastermind" rev-parse HEAD)" "$want"

echo "git hooks"
GH="$WORK/githooks"; mkdir -p "$GH/scripts"; ZERO=0000000000000000000000000000000000000000
printf 'process.exit(Number(process.env.PROSE_RC || 0))\n' > "$GH/scripts/check-prose.mjs"
for s in check-comments check-shell-patterns check-instructions; do printf 'process.exit(0)\n' > "$GH/scripts/$s.mjs"; done
( cd "$GH" && git init -q . && git add -A && gitq commit -qm stubs && echo note > notes.txt && git add -A && gitq commit -qm notes ) >/dev/null 2>&1
GSHA=$(git -C "$GH" rev-parse HEAD)
# $1 hook file, $2 the ref line git would feed it; the rest is the environment.
push() { local hook="$1" line="$2"; shift 2; (cd "$GH" && printf '%s\n' "$line" | env -u ALLOW_SENSITIVE -u MM_SKIP_TESTS "$@" bash "$hook" origin "$GH" 2>&1); }
LIVE="$ROOT/.githooks/pre-push"; SHIPPED="$ROOT/skills/quarantine/assets/pre-push"

out=$(push "$LIVE" "refs/heads/main $GSHA refs/tags/v9.9.9 $ZERO" MM_SKIP_TESTS=1); rc=$?
case "$rc:$out" in 1:*"BLOCKED"*"v9.9.9"*) ok "a branch pushed to a remote tag ref meets the tag guard";; *) bad "remote tag ref not guarded: exit $rc: $out";; esac
out=$(push "$LIVE" "refs/heads/main $GSHA refs/tags/v9.9.9 $ZERO" MM_SKIP_TESTS=1 ALLOW_SENSITIVE=1); rc=$?
check "and the bypass does not lift the tag guard" "$rc" "1"
out=$(push "$LIVE" "refs/tags/v9.9.9 $GSHA refs/heads/topic $ZERO" MM_SKIP_TESTS=1); rc=$?
check "a local tag pushed to a branch name is not a release tag" "$rc" "0"

out=$(push "$LIVE" "refs/heads/main $GSHA refs/heads/main $ZERO" ALLOW_SENSITIVE=1 PROSE_RC=1); rc=$?
case "$rc:$out" in 1:*"em dashes would be pushed"*) ok "ALLOW_SENSITIVE=1 does not skip the prose gate";; *) bad "prose gate skipped: exit $rc: $out";; esac
out=$(push "$LIVE" "refs/heads/main $GSHA refs/heads/main $ZERO" ALLOW_SENSITIVE=1); rc=$?
case "$rc:$out" in 0:*"BYPASSED"*"suite not needed"*) ok "nor the step that decides whether the suites run";; *) bad "suites step skipped: exit $rc: $out";; esac
case "$out" in *"push guard: clean"*) bad "a bypassed scan was reported as clean";; *) ok "and a bypassed scan is not reported as clean";; esac
out=$(push "$LIVE" "refs/heads/main $GSHA refs/heads/main $ZERO" MM_SKIP_TESTS=1 PROSE_RC=2); rc=$?
case "$rc:$out" in 0:*"✓ no em dashes"*) bad "an unchecked site was reported as clean";; 0:*"NOT checked"*) ok "check-prose exit 2 is reported as not checked";; *) bad "exit 2 handling: exit $rc: $out";; esac

( cd "$GH" && printf 'key = %s%s\n' "AKIA" "ABCDEFGHIJKLMNOP" > leak.txt && git add -A && gitq commit -qm leak ) >/dev/null 2>&1
LSHA=$(git -C "$GH" rev-parse HEAD)
for hook in "$LIVE" "$SHIPPED"; do
  label=$([ "$hook" = "$LIVE" ] && echo "repo hook" || echo "shipped hook")
  out=$(push "$hook" "refs/heads/main $LSHA refs/heads/main $GSHA" MM_SKIP_TESTS=1); rc=$?
  case "$rc:$out" in 1:*"credentials"*) ok "$label: a credential is blocked";; *) bad "$label: credential not blocked: exit $rc";; esac
  out=$(push "$hook" "refs/heads/main $LSHA refs/heads/main $GSHA" MM_SKIP_TESTS=1 ALLOW_SENSITIVE=1); rc=$?
  case "$rc:$out" in 0:*"scan BYPASSED"*) ok "$label: ALLOW_SENSITIVE=1 skips that scan and says so";; *) bad "$label: bypass: exit $rc: $out";; esac
done

echo "release lifecycle"
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
  mkdir -p "$LIFE/named"
  (cd "$LIFE/named" && git init -q . && env -u MASTERMIND_HOME HOME="$LIFE" node "$LIFECLI/bin/mastermind.mjs" claude cursor >/dev/null 2>&1)
  check "naming tools still wires AGENTS.md and .agents/skills" \
    "$([ -e "$LIFE/named/AGENTS.md" ] && [ -d "$LIFE/named/.agents/skills" ] && echo yes)" "yes"
  (cd "$LIFE/named" && env -u MASTERMIND_HOME HOME="$LIFE" node "$LIFECLI/bin/mastermind.mjs" uninstall cursor >/dev/null 2>&1)
  check "uninstalling one tool keeps AGENTS.md for the others" "$([ -e "$LIFE/named/AGENTS.md" ] && echo kept)" "kept"
else
  skip "release-to-release upgrade: this checkout has fewer than two release tags"
fi

LATEST_TAG=$(git -C "$ROOT" tag --list 'v*' --sort=-v:refname | sed -n 1p)
if [ -n "$LATEST_TAG" ]; then
  UP="$WORK/uptree"; mkdir -p "$UP/proj"
  git clone -q "$ROOT" "$UP/.mastermind" 2>/dev/null
  git -C "$UP/.mastermind" checkout -q "$LATEST_TAG" 2>/dev/null
  uprun() { (cd "$UP/proj" && env -u MM_STATE_DIR -u MASTERMIND_HOME -u MASTERMIND_COMMIT -u MASTERMIND_REF -u CLAUDE_PLUGIN_ROOT HOME="$UP" MM_NO_NETWORK=1 "$@"); }
  (cd "$UP/proj" && git init -q .)
  uprun bash "$UP/.mastermind/install.sh" claude cursor >/dev/null 2>&1
  check "the latest release installs ($LATEST_TAG)" "$(cat "$UP/proj/.mastermind/VERSION" 2>/dev/null)" "${LATEST_TAG#v}"
  # The home brain moves on to the working tree, as an update would move it to the next release.
  mv "$UP/.mastermind" "$UP/released"; ln -s "$ROOT" "$UP/.mastermind"
  out=$(uprun "${CLI[@]}" claude cursor 2>&1); rc=$?
  check "the working tree installs over $LATEST_TAG" "$rc" "0"
  check "and the project now runs the working tree's hook" \
    "$(cmp -s "$UP/proj/.mastermind/hooks/session-start.sh" "$ROOT/hooks/session-start.sh" && echo same)" "same"
  out=$(uprun "${CLI[@]}" check 2>&1); rc=$?
  check "and check finds the upgraded project healthy" "$rc:$(printf '%s' "$out" | grep -c '✖')" "0:0"
  out=$(uprun "${CLI[@]}" status --json | python3 -c "$J; print(d['mode'] + '|' + d['version'])")
  check "and status reads the upgraded brain" "$out" "isolated|$(cat "$ROOT/VERSION")"
  out=$(uprun env CLAUDE_PROJECT_DIR="$UP/proj" bash "$UP/proj/.mastermind/hooks/session-start.sh" claude | hookctx | grep -c 'You are running as MasterMind')
  check "and its session hook answers" "$out" "1"
else
  skip "upgrade from the latest release to the working tree: this checkout has no release tag"
fi

BROKE="$WORK/brokenidx"; mkdir -p "$BROKE/proj"
git clone -q "$ROOT" "$BROKE/.mastermind" 2>/dev/null
printf 'garbage' > "$BROKE/.mastermind/.git/index"
out=$(cd "$BROKE/proj" && git init -q . && env -u MASTERMIND_HOME HOME="$BROKE" node "$PINDIR/bin/mastermind.mjs" 2>&1 | tail -3)
case "$out" in *"cannot read the working tree"*) ok "an unreadable index refuses, it does not pass as clean";;
  *) bad "broken index accepted: $out";; esac

printf '\n%s passed, %s failed, %s skipped\n' "$pass" "$fail" "$skipped"
[ "$fail" -eq 0 ] || exit 1
if [ "$skipped" -gt 0 ] && [ "${MM_REQUIRE_LIFECYCLE:-0}" = "1" ]; then
  printf 'MM_REQUIRE_LIFECYCLE=1: a skipped lifecycle test fails this run. Fetch the release tags (git fetch --tags) and run it again.\n'
  exit 1
fi
exit 0
