#!/usr/bin/env bash
# MasterMind installer — safe, idempotent, self-healing.
#
# Two scopes:
#   (default) PER-PROJECT — wires MasterMind into the CURRENT project: Claude Code
#             (.claude/), Cursor (.cursor/rules/), and AGENTS.md — the open instruction
#             file every other agentic tool reads. Active only here. Run it in each
#             project you want it in.
#   --global              — wires ~/.claude, so Claude Code gets it in EVERY project.
#             (Cursor rules and AGENTS.md are per-project by design.)
#
# Supported: Claude Code, Cursor, Codex. The brain is plain Markdown, so another tool that reads
# an instruction file may load it too — but we don't wire it, test it, or claim it.
#
# You install FROM the clone at ~/.mastermind. Re-run anytime — ESPECIALLY after `git pull`
# — to refresh. It NEVER destroys your data: a real CLAUDE.md is backed up, an existing
# AGENTS.md is appended to (never overwritten), and a project's own lessons are kept
# across updates.
#
# Usage:
#   cd my-project && ~/.mastermind/install.sh          # this project, all your tools (isolated)
#   cd my-project && ~/.mastermind/install.sh --shared # opt into the one shared clone instead
#   ~/.mastermind/install.sh --global                  # Claude Code in every project (shared)
#   ~/.mastermind/install.sh --check                   # doctor (add --global to check global)
#   ~/.mastermind/install.sh --uninstall               # remove from this project (or --global)
#   cd my-project && ~/.mastermind/install.sh cursor   # only the named tool(s)
#
# Isolated (default) vs --shared:
#   Isolated  — the engine is COPIED into <project>/.mastermind/, committed to that repo, and
#               the project owns its field, lessons and stack. Nothing another project learns
#               can change it; it updates only when you re-run install here. A monorepo can
#               route a different field/context per app via `.mastermind/routes.map`.
#   Shared    — every project symlinks back to ~/.mastermind: ONE field, ONE lessons.md, ONE
#               stack-defaults for all of them, updated together by `git pull`. Right when your
#               projects genuinely share a stack.
set -euo pipefail

# `pwd -P` — resolve symlinks to the REAL repo path. Plain `pwd` returns the logical path,
# so running the documented `~/.mastermind/install.sh` gave REPO=~/.mastermind, and the
# `ln -sfn "$REPO" "$HOME/.mastermind"` below then pointed that symlink at ITSELF — an
# unreadable loop that silently unlinks the whole brain ("Too many levels of symbolic links",
# every glob stops matching, and skills link as a literal `*`). The documented update command
# was the one that broke it.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MODE=install; SCOPE=project; TOOLS=(); ISOLATED=0; SHARED=0
for a in "$@"; do
  case "$a" in
    --check)     MODE=check ;;
    --uninstall) MODE=uninstall ;;
    --global)    SCOPE=global ;;
    --isolated)  ISOLATED=1 ;;   # (now the default; kept so existing commands still work)
    --shared)    SHARED=1 ;;
    --*)         printf 'unknown flag: %s\n' "$a" >&2; exit 2 ;;
    *)           TOOLS+=("$a") ;;
  esac
done

g=$'\033[0;32m'; y=$'\033[0;33m'; r=$'\033[0;31m'; x=$'\033[0m'

[ "$ISOLATED" = 1 ] && [ "$SCOPE" = global ] && {
  printf '%s✖ --isolated is per-project by definition; drop --global.%s\n' "$r" "$x" >&2; exit 2
}
ok()   { printf '  %s✓%s %s\n' "$g" "$x" "$*"; }
warn() { printf '  %s⚠%s %s\n' "$y" "$x" "$*"; }
bad()  { printf '  %s✖%s %s\n' "$r" "$x" "$*"; }
ISSUES=0; LINKED_SKILLS=0; LINKED_AGENTS=0; PRUNED=0; RENAMED=0; SKIPPED=0
HINT='Follow ~/.mastermind/CLAUDE.md — the MasterMind brain (skills, agents, engineering rigor).'
HINT_GLOBAL="$HINT"
HINT_ISOLATED='Follow ./.mastermind/CLAUDE.md — the MasterMind brain for this project (skills, agents, engineering rigor).'
# Set once $BRAIN/$PROJECT are known (below): an isolated project must point at its OWN brain.
mm_hint() {
  if [ "$ISOLATED" = 1 ]; then
    printf 'Follow ./.mastermind/CLAUDE.md — the MasterMind brain for this project (skills, agents, engineering rigor).'
  else
    printf '%s' "$HINT"
  fi
}
# Anchor-block markers — matched as WHOLE lines so a project's own text that merely mentions
# them is never edited. Kept minimal and stable so old blocks stay recognizable across versions.
MM_START='<!-- MASTERMIND:START -->'
MM_END='<!-- MASTERMIND:END -->'

# One brain per repository, so a monorepo doesn't sprout a separate brain per subfolder.
# Walk up for an existing project brain, else the git root, else stay put (non-git dir).
# Two guards: STOP at $HOME (the shared clone is $HOME/.mastermind — ascending into it would
# make a project resolve its root to $HOME, no-op'ing install and deleting global wiring on
# uninstall), and require a REAL dir (the shared clone is a symlink; a project brain isn't).
find_project_root() {
  local d="$PWD" gitroot=""
  # The repository you are standing in is the project. Walking up for any `.mastermind` first
  # meant a nested repo inside a non-git parent that happened to hold one got skipped: the
  # installer wired the PARENT and left the actual repository unwired. Never climb past the
  # git root; inside a repo, that root is the answer unless a nearer .mastermind exists.
  gitroot="$(git rev-parse --show-toplevel 2>/dev/null)" || gitroot=""
  while [ "$d" != / ] && [ "$d" != "$HOME" ]; do
    [ -d "$d/.mastermind" ] && [ ! -L "$d/.mastermind" ] && { printf '%s' "$d"; return; }
    [ -n "$gitroot" ] && [ "$d" = "$gitroot" ] && break
    d="$(dirname "$d")"
  done
  [ -n "$gitroot" ] && { printf '%s' "$gitroot"; return; }
  printf '%s' "$PWD"
}

if [ "$SCOPE" = global ]; then
  PROJECT="$HOME"
else
  PROJECT="$(find_project_root)"
fi

# `--check` run from ~ (or the clone) is a GLOBAL question, not a project one. There is no
# project there, and `$HOME/.claude` IS the global config — so project scope walked the global
# directory while judging it by project rules and reported phantom failures ("CLAUDE.md is not
# linked") for an install that was healthy. Install mode already refuses these two directories
# further down; this makes the read-only path agree with it. `-ef` compares inodes, so a
# symlinked HOME still matches.
if [ "$MODE" = check ] && [ "$SCOPE" = project ] && { [ "$PROJECT" -ef "$HOME" ] || [ "$PROJECT" -ef "$REPO" ]; }; then
  SCOPE=global
  CHECK_SCOPE_SWITCHED=1
fi

# Scope → where Claude gets wired (project-local by default, home with --global).
# AGENTS.md is a PROJECT file by convention, so it stays empty under --global and every use of
# it is guarded. Codex is the one tool with a real global instruction file of its own
# (`$CODEX_HOME/AGENTS.md`, default ~/.codex) — see wire_codex_global below for the caveat.
if [ "$SCOPE" = global ]; then
  CLAUDE_DIR="$HOME/.claude"; AGENTS_FILE=""
else
  CLAUDE_DIR="$PROJECT/.claude";  AGENTS_FILE="$PROJECT/AGENTS.md"
fi
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CODEX_GLOBAL="$CODEX_HOME_DIR/AGENTS.md"

# Which brain does this project actually read? The shared clone, or its own copy.
# Resolved HERE, before anything that inspects links: `is_ours` and the uninstall block
# both need it, and both run earlier than the install path does.
# A project that already has .mastermind/VERSION stays isolated on later runs even
# without the flag — otherwise a plain `install.sh` would silently re-point it at the clone.
# Per-project installs are ISOLATED by default: the project gets its own field, lessons and
# stack, and updates only when you re-run install there. `--shared` opts back into the single
# clone every project reads — right when your projects genuinely share a stack.
if [ "$SCOPE" = project ] && [ "$SHARED" = 0 ] && [ "$MODE" != uninstall ]; then ISOLATED=1; fi
if [ "$SCOPE" = project ] && { [ "$ISOLATED" = 1 ] || { [ -f "$PROJECT/.mastermind/VERSION" ] && [ ! -L "$PROJECT/.mastermind" ]; }; }; then
  BRAIN="$PROJECT/.mastermind"; ISOLATED=1
else
  BRAIN="$REPO"
fi

# `.mastermind/` is committed, so a clone can ship a symlinked subdirectory that redirects
# every write below it. Refuse the whole path, not just its root.
mm_assert_no_symlink_path() {
  local base="$1"
  local rel="$2"
  local cur="$base"
  local rest="$rel"
  local seg target
  while [ -n "$rest" ]; do
    seg="${rest%%/*}"
    if [ "$seg" = "$rest" ]; then rest=""; else rest="${rest#*/}"; fi
    [ -n "$seg" ] && [ "$seg" != "." ] || continue
    cur="$cur/$seg"
    [ -L "$cur" ] || continue
    if [ -n "$rest" ]; then
      printf '%s! %s is a symlink (-> %s).%s Refusing to write through it.\n' \
        "$r" "${cur#"$PROJECT"/}" "$(readlink "$cur")" "$x" >&2
      exit 1
    fi
    target="$(readlink "$cur")"
    case "$target" in
      /*|*..*)
        printf '%s! %s points outside the brain (-> %s).%s Refusing to write through it.\n' \
          "$r" "${cur#"$PROJECT"/}" "$target" "$x" >&2
        exit 1 ;;
    esac
  done
  return 0
}

# Every project write target must RESOLVE inside the project. A repo can ship
# `.claude -> /somewhere/else` (or `.cursor`, or `AGENTS.md`), and the installer happily wrote
# 28 files into that location and exited 0: an arbitrary write driven by repo contents. The
# existing walker guards paths under the brain; this guards the integration directories too.
mm_assert_contained() {
  local path="$1" proj real lnk
  [ -e "$path" ] || [ -L "$path" ] || return 0          # not there yet: we create it ourselves
  proj="$(cd -P "$PROJECT" 2>/dev/null && pwd -P)" || return 0
  if [ -L "$path" ] && [ ! -d "$path" ]; then
    # A symlinked FILE: resolving its parent is not enough. `.cursor/rules/mastermind.mdc ->
    # /outside` sits in a perfectly legitimate directory, so the parent check said yes while
    # the write landed outside the repo. Follow the link itself, relative targets included.
    lnk="$(readlink "$path")"
    case "$lnk" in /*) ;; *) lnk="$(dirname "$path")/$lnk" ;; esac
    real="$(cd -P "$(dirname "$lnk")" 2>/dev/null && pwd -P)/$(basename "$lnk")" || real=""
  elif [ -d "$path" ]; then
    real="$(cd -P "$path" 2>/dev/null && pwd -P)" || real=""
  else
    real="$(cd -P "$(dirname "$path")" 2>/dev/null && pwd -P)/$(basename "$path")" || real=""
  fi
  case "$real" in
    "$proj"|"$proj"/*) return 0 ;;
  esac
  # A --shared install deliberately points AGENTS.md and CLAUDE.md at the clone, which is
  # outside the project by design. Refuse foreign targets, not our own: is_ours resolves both
  # sides, so this stays a containment check rather than a ban on leaving the directory.
  is_ours "$path" && return 0
  printf '%s! %s resolves outside the project (-> %s).%s Refusing to write there.\n' \
    "$r" "${path#"$PROJECT"/}" "${real:-unreadable}" "$x" >&2
  printf '  A repository cannot be allowed to redirect the installer onto paths you did not choose.\n' >&2
  exit 1
}

# Paths from config files are untrusted: resolve, then require containment in $PROJECT.
mm_resolve_inside_project() {
  local real proj
  proj="$(cd -P "$PROJECT" 2>/dev/null && pwd -P)" || return 1
  real="$(cd -P "$1" 2>/dev/null && pwd -P)" || return 1
  case "$real" in "$proj"|"$proj"/*) printf '%s' "$real" ;; *) return 1 ;; esac
}

# A committed project has to work on a teammate's machine and survive being moved. Absolute
# links did neither: a fresh install wrote 28 of them, and cloning the repo elsewhere broke
# every one, contradicting the "project-relative, never absolute" contract below. When BOTH
# ends live inside the project, emit a relative link; when the target is the shared clone
# (outside the project), absolute is the only thing that can work.
mm_relpath() {                      # $1 target (absolute), $2 directory the link sits in
  local t="$1" s="$2" up=""
  while [ "$s" != "/" ] && [ "${t#"$s"/}" = "$t" ]; do s="$(dirname "$s")"; up="../$up"; done
  printf '%s%s' "$up" "${t#"$s"/}"
}

mm_link_src() {                     # $1 target, $2 link path -> what to store in the symlink
  local src="$1" dst="$2" proj rsrc dir
  # RESOLVE both ends before comparing. Comparing a logical path ($TMP/proj) against a resolved
  # one (/private/var/.../proj) fails the containment test and falls back to absolute links, so
  # on any path that crosses a symlink (macOS /tmp, a symlinked home, a network mount) this fix
  # would quietly do nothing. Two path bugs have already shipped in exactly that shape.
  proj="$(cd -P "$PROJECT" 2>/dev/null && pwd -P)" || { printf '%s' "$src"; return; }
  dir="$(cd -P "$(dirname "$dst")" 2>/dev/null && pwd -P)" || { printf '%s' "$src"; return; }
  if [ -d "$src" ]; then rsrc="$(cd -P "$src" 2>/dev/null && pwd -P)" || rsrc="$src"
  else rsrc="$(cd -P "$(dirname "$src")" 2>/dev/null && pwd -P)/$(basename "$src")" || rsrc="$src"; fi
  case "$rsrc" in "$proj"/*) ;; *) printf '%s' "$src"; return ;; esac
  case "$dir"  in "$proj"|"$proj"/*) ;; *) printf '%s' "$src"; return ;; esac
  mm_relpath "$rsrc" "$dir"
}

# Link src→dst. In check mode, only verify. Back up a real file before linking.
safe_link() {
  local src="$1" dst="$2"
  if [ "$MODE" = check ]; then
    if is_ours "$dst" && [ -e "$dst" ]; then ok "$(basename "$dst")"
    else bad "$(basename "$dst") is not linked to MasterMind"; ISSUES=$((ISSUES + 1)); fi
    return
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local bak="$dst.bak-$(date +%Y%m%d%H%M%S)"
    mv "$dst" "$bak"; warn "backed up your existing $(basename "$dst") → $bak"
    # Record which backup THIS install created: restoring "the newest *.bak-*" could resurrect
    # an unrelated older file the user made themselves.
    mkdir -p "$(dirname "$dst")" && printf '%s\n' "$bak" > "$dst.mm-backup"
  fi
  ln -sfn "$(mm_link_src "$src" "$dst")" "$dst"
}

# Ownership compares RESOLVED paths. A link written as /private/tmp/... did not match a BRAIN
# computed as /tmp/... , so uninstall silently left every link in place on any path that
# crosses a symlink (macOS /tmp, symlinked homes, network mounts).
is_ours() {
  [ -L "$1" ] || return 1
  local t rt rrepo rbrain
  t="$(readlink "$1")"
  case "$t" in "$REPO"*|"$BRAIN"*) return 0 ;; esac
  # Links inside a project are relative now, so resolve them from the LINK's directory. Using
  # the cwd here would report a healthy link as foreign, and uninstall would leave it behind.
  local tdir
  case "$t" in
    /*) tdir="$(dirname "$t")" ;;
    *)  tdir="$(dirname "$1")/$(dirname "$t")" ;;
  esac
  rt="$(cd -P "$tdir" 2>/dev/null && pwd -P)/$(basename "$t")" || return 1
  rrepo="$(cd -P "$REPO" 2>/dev/null && pwd -P)" || rrepo="$REPO"
  rbrain="$(cd -P "$BRAIN" 2>/dev/null && pwd -P)" || rbrain="$BRAIN"
  case "$rt" in "$rrepo"*|"$rbrain"*) return 0 ;; *) return 1 ;; esac
}
path_exists() { [ -e "$1" ] || [ -L "$1" ]; }

# Link a skill/agent so BOTH the project's and MasterMind's survive.
#
# The kernel's rule is "the project wins" — but winning must never mean MasterMind
# loses a capability. So on a name collision we leave the project's file exactly where
# it is and install ours ALONGSIDE it as `mastermind-<name>`. Nothing is displaced,
# nothing silently disappears, and the names say which is which.
link_skill() {
  local src="$1" base="$2" name="$3" kind="$4"
  local dst="$base/$name" alt="$base/mastermind-$name"
  local target="$dst" renamed=0   # separate `local`: same-statement $dst isn't set yet

  if path_exists "$dst" && ! is_ours "$dst"; then target="$alt"; renamed=1; fi

  if [ "$MODE" = check ]; then
    if is_ours "$target" && [ -e "$target" ]; then
      if [ "$renamed" = 1 ]; then ok "mastermind-$name (your own '$name' kept)"; else ok "$name"; fi
      return 0
    fi
    bad "$(basename "$target") is not linked to MasterMind"; ISSUES=$((ISSUES + 1)); return 1
  fi

  # The project owns BOTH names — refuse rather than clobber anything of theirs.
  if [ "$renamed" = 1 ] && path_exists "$alt" && ! is_ours "$alt"; then
    warn "you own both '$name' and 'mastermind-$name' — MasterMind's $kind skipped"
    SKIPPED=$((SKIPPED + 1)); return 1
  fi

  ln -sfn "$(mm_link_src "$src" "$target")" "$target"
  if [ "$renamed" = 1 ]; then
    warn "you already have a $kind '$name' — installed MasterMind's as 'mastermind-$name' (both work)"
    RENAMED=$((RENAMED + 1))
  elif is_ours "$alt"; then
    # Their colliding file is gone, so ours reclaimed the real name — drop the alias.
    rm -f "$alt"
  fi
  return 0
}

# Wire an instruction file (AGENTS.md) to the brain WITHOUT clobbering: if absent,
# symlink to the full brain; if the project already has one, append a one-line pointer
# (idempotent).
wire_brain_file() {
  local dst="$1" src="$2"
  if [ "$MODE" = check ]; then
    if is_ours "$dst" || { [ -f "$dst" ] && grep -q 'mastermind/CLAUDE.md' "$dst"; }; then ok "$(basename "$dst")"
    else bad "$(basename "$dst") not wired to MasterMind"; ISSUES=$((ISSUES + 1)); fi
    return
  fi
  mkdir -p "$(dirname "$dst")"
  # A zero-byte file is nothing to preserve — link over it rather than appending a pointer to
  # an empty file. Codex creates an empty ~/.codex/AGENTS.md on its own, and the old behaviour
  # left it as a one-line pointer that Codex may not follow.
  if [ ! -e "$dst" ] || [ -L "$dst" ] || { [ -f "$dst" ] && [ ! -s "$dst" ]; }; then
    ln -sfn "$(mm_link_src "$src" "$dst")" "$dst"; ok "$(basename "$dst") linked"
  elif grep -q 'mastermind/CLAUDE.md' "$dst"; then ok "$(basename "$dst") already wired"
  else printf '\n%s\n' "$(mm_hint)" >> "$dst"; ok "appended MasterMind pointer to your $(basename "$dst")"
  fi
}

# Codex's own global instruction file. Two vendor behaviours this has to respect, both from
# the Codex docs (developers.openai.com/codex/guides/agents-md), not from guesswork:
#
#  1. Codex reads AGENTS.override.md FIRST and uses only the first non-empty file at that level.
#     If the user has an override, ours is dead text — say so instead of printing a green ✓.
#  2. Global instructions are NOT reliably merged into project chats in the Codex app when the
#     project has its own AGENTS.md (openai/codex#27705, open). So the project-level file is the
#     load-bearing path; this one is a bonus, and --check reports it as unverified rather than
#     healthy. Do not claim global Codex wiring works until that issue closes.
wire_codex_global() {
  local ovr="$CODEX_HOME_DIR/AGENTS.override.md"
  if [ "$MODE" = check ]; then
    if [ -s "$ovr" ]; then warn "$CODEX_HOME_DIR/AGENTS.override.md takes priority — MasterMind's global file is ignored by Codex"; return 0; fi
    if is_wired "$CODEX_GLOBAL"; then warn "$CODEX_GLOBAL wired (may not reach project chats — openai/codex#27705)"
    else bad "$CODEX_GLOBAL not wired to MasterMind"; ISSUES=$((ISSUES + 1)); fi
    return 0
  fi
  wire_brain_file "$CODEX_GLOBAL" "$BRAIN/AGENTS.md"
  [ -s "$ovr" ] && warn "you have AGENTS.override.md — Codex reads that instead, so this file won't apply"
  warn "Codex may not merge global instructions into a project that has its own AGENTS.md (openai/codex#27705) — run install.sh inside each project for the reliable path"
  return 0
}

# Cursor rule (its own file, always ours) — needs alwaysApply frontmatter to load.
wire_cursor() {
  local dst="$PROJECT/.cursor/rules/mastermind.mdc"
  if [ "$MODE" = check ]; then
    # Grep for kernel CONTENT: a pointer-only rule ("Follow ~/.mastermind/CLAUDE.md") is the
    # stale shape and must read as unwired, not healthy.
    if [ -f "$dst" ] && grep -q 'Prime directives' "$dst"; then ok ".cursor/rules/mastermind.mdc"
    elif [ -f "$dst" ]; then bad ".cursor rule is the old pointer-only shape — re-run install.sh"; ISSUES=$((ISSUES + 1))
    else bad ".cursor rule not set"; ISSUES=$((ISSUES + 1)); fi
    return
  fi
  mkdir -p "$PROJECT/.cursor/rules"
  # Other tools get the kernel by symlink; Cursor can't — an .mdc needs YAML frontmatter. So
  # compose frontmatter + the real kernel inline. A pointer to the file (instead of its content)
  # leaves loading to the model's discretion, which is why it often didn't. Generated, not
  # linked: re-run install.sh after a `git pull` to refresh it.
  { printf -- '---\nalwaysApply: true\n---\n'
    printf -- '<!-- Generated by ~/.mastermind/install.sh — do not edit. Refresh with: npx mastermind-brain -->\n\n'
    cat "$BRAIN/CLAUDE.md"
  } > "$dst"
  ok ".cursor/rules/mastermind.mdc — full kernel inlined"
  wire_cursor_field
  wire_cursor_hook
}

# The field pack, inlined for Cursor — same lesson as the kernel above, learned again the hard way.
# The kernel *names* the pack files and tells the model to load them. Measured 2026-07-26 on Cursor
# Composer 2.5: it never did. Asked directly, it read them instantly — so the capability was there and
# the instruction simply didn't fire, leaving the pack inert and the run scoring exactly baseline.
# Anything that must reach the model belongs in what the harness injects, not in prose it may decline.
# Only the two files the kernel calls behavior-changing go here; mentors/curriculum/databases stay
# on-disk and on-demand, so this costs a bounded amount of context rather than the whole pack.
wire_cursor_field() {
  local dst="$PROJECT/.cursor/rules/mastermind-field.mdc"
  local af="$BRAIN/engineering/active-field.md" field pdir
  field="$(sed -n 's/^[[:space:]]*[-*][[:space:]]*\*\*Field pack:\*\*[[:space:]]*`\([^`]*\)`.*/\1/p' "$af" 2>/dev/null | head -1)"
  field="${field%/}"; field="${field##*/}"

  # No field yet (a fresh install ships none) → nothing to inline, and a stale rule must go.
  if [ -z "$field" ] || [ ! -d "$BRAIN/engineering/fields/$field" ]; then
    [ "$MODE" = check ] || rm -f "$dst"
    return
  fi
  pdir="$BRAIN/engineering/fields/$field"

  if [ "$MODE" = check ]; then
    if [ -f "$dst" ]; then ok ".cursor/rules/mastermind-field.mdc — $field pack inlined"
    else bad "field pack '$field' exists but is not delivered to Cursor — re-run install.sh"; ISSUES=$((ISSUES + 1)); fi
    return
  fi

  local f had=0
  { printf -- '---\nalwaysApply: true\n---\n'
    printf -- '<!-- Generated by ~/.mastermind/install.sh — do not edit. Refresh with: npx mastermind-brain -->\n'
    printf -- '\n# Active field pack: %s\n\nThe stack knowledge for this project. Apply it as your default;\n' "$field"
    printf -- 'the rest of the pack (mentors, curriculum, audit rules) is on disk under\n`.mastermind/engineering/fields/%s/` and loads on demand.\n' "$field"
    for f in stack-defaults.md lessons.md; do
      [ -f "$pdir/$f" ] || continue
      printf -- '\n\n---\n\n<!-- %s -->\n\n' "$f"; cat "$pdir/$f"; had=1
    done
  } > "$dst"

  if [ "$had" = 0 ]; then rm -f "$dst"; return; fi
  local kb=$(( $(wc -c < "$dst") / 1024 ))
  ok ".cursor/rules/mastermind-field.mdc — $field pack inlined (${kb}KB)"
  [ "$kb" -gt 60 ] && warn "that pack is large for always-on context — prune it with levelup, or Cursor pays it every request"
  return 0
}

# Cursor's own hook system (.cursor/hooks.json). sessionStart re-loads the kernel on a new
# conversation; preCompact fires before Cursor compacts, which is the event that matters.
#
# UNVERIFIED — see docs: Cursor has open bug reports where a sessionStart hook's
# additional_context is accepted but never reaches the model. We wire it because it costs
# nothing and starts working the moment that's fixed, but the .mdc rule above remains the
# load-bearing path for Cursor. Do not claim Cursor re-injection works until it's observed.
wire_cursor_hook() {
  local dst="$PROJECT/.cursor/hooks.json"
  if [ "$MODE" = check ]; then
    if [ -f "$dst" ] && grep -q 'session-start.sh' "$dst"; then ok ".cursor/hooks.json (unverified upstream)"; fi
    return 0
  fi
  command -v node >/dev/null 2>&1 || return 0
  mkdir -p "$PROJECT/.cursor"
  # Relative when the brain is the project's own: a committed hooks.json must not carry this
  # machine's path, and quoting keeps a project directory with spaces working (it returned 127).
  local _hookcmd
  if [ "$ISOLATED" = 1 ]; then _hookcmd='"./.mastermind/hooks/session-start.sh" cursor'
  else _hookcmd="\"$BRAIN/hooks/session-start.sh\" cursor"; fi
  MM_DST="$dst" MM_CMD="$_hookcmd" MM_HOOKS_DIR="$BRAIN/hooks/" node -e '
    const fs=require("fs"); const p=process.env.MM_DST, cmd=process.env.MM_CMD;
    const mmHooks=process.env.MM_HOOKS_DIR;
    let s={version:1,hooks:{}};
    if (fs.existsSync(p)) { try { s=JSON.parse(fs.readFileSync(p,"utf8")||"{}"); } catch { process.exit(3); } }
    s.version ??= 1; s.hooks ||= {};
    for (const ev of ["sessionStart","preCompact"]) {
      const owns=(c)=>typeof c==="string" && ((mmHooks && c.startsWith(mmHooks)) || c.includes("/.mastermind/hooks/session-start.sh") || c.includes("/hooks/session-start.sh") && c.includes("mastermind"));
      const mine=(e)=>owns(e&&e.command)||(e&&e.command)===cmd;
      const keep=(s.hooks[ev]||[]).filter(e=>!mine(e));
      keep.push({command: cmd});
      s.hooks[ev]=keep;
    }
    fs.writeFileSync(p, JSON.stringify(s,null,2)+"\n");
  ' 2>/dev/null \
    && ok ".cursor/hooks.json — sessionStart + preCompact (unverified upstream)" \
    || warn "left your .cursor/hooks.json alone (could not parse it)"
  return 0
}

# Wire Claude Code natively (skills + agents + kernel) into a base .claude dir.
wire_claude() {
  local base="$1"
  [ "$MODE" = check ] || mkdir -p "$base/agents" "$base/skills"
  printf '\nClaude Code:\n'
  wire_brain_file "$base/CLAUDE.md" "$BRAIN/CLAUDE.md"
  # Global links engineering into ~/.claude; per-project reads it via ~/.mastermind.
  [ "$SCOPE" = global ] && safe_link "$REPO/engineering" "$base/engineering"
  prune_dead_links "$base/skills"; prune_dead_links "$base/agents"
  LINKED_SKILLS=0; LINKED_AGENTS=0; RENAMED=0; SKIPPED=0
  local a s
  for a in "$BRAIN"/agents/*.md; do
    if link_skill "$a" "$base/agents" "$(basename "$a")" agent; then
      [ "$MODE" = check ] || LINKED_AGENTS=$((LINKED_AGENTS + 1))
    fi
  done
  for s in "$BRAIN"/skills/*/; do
    if link_skill "${s%/}" "$base/skills" "$(basename "$s")" skill; then
      [ "$MODE" = check ] || LINKED_SKILLS=$((LINKED_SKILLS + 1))
    fi
  done
  if [ "$MODE" != check ]; then
    ok "$LINKED_SKILLS skills, $LINKED_AGENTS agents linked · $PRUNED stale removed"
    if [ "$RENAMED" -gt 0 ]; then
      warn "$RENAMED name(s) clashed with your own — yours kept, ours added as mastermind-*"
    fi
  fi
  wire_bootstrap "$base"
}

# Register the SessionStart bootstrap so the kernel is re-injected on startup AND after
# a compaction — otherwise the brain quietly fades out of a long session. Merges into an
# existing settings.json (never overwrites it) and is idempotent.
wire_bootstrap() {
  local base="$1" settings="$base/settings.json" hook="$BRAIN/hooks/session-start.sh"
  # Same portability problem as the Cursor hook: an absolute path in a committed settings.json
  # is this machine's path. Claude Code expands $CLAUDE_PROJECT_DIR to the project root.
  [ "$ISOLATED" = 1 ] && hook='$CLAUDE_PROJECT_DIR/.mastermind/hooks/session-start.sh'

  if [ "$MODE" = check ]; then
    if [ -f "$settings" ] && grep -q 'session-start.sh' "$settings"; then ok "bootstrap hook"
    else bad "bootstrap hook not registered (kernel will fade after a compaction)"; ISSUES=$((ISSUES + 1)); fi
    return 0
  fi

  if ! command -v node >/dev/null 2>&1; then
    warn "node not found — skipped the bootstrap hook (brain won't survive a compaction)"
    return 0
  fi

  MM_SETTINGS="$settings" MM_HOOK="$hook" MM_HOOKS_DIR="$BRAIN/hooks/" node -e '
    const fs = require("fs");
    const p = process.env.MM_SETTINGS, cmd = JSON.stringify(process.env.MM_HOOK);
    const mmHooks = process.env.MM_HOOKS_DIR;
    let s = {};
    if (fs.existsSync(p)) {
      try { s = JSON.parse(fs.readFileSync(p, "utf8") || "{}"); }
      catch { console.error("KEEP"); process.exit(3); }   // unparseable: never clobber it
    }
    s.hooks ||= {};
    const list = (s.hooks.SessionStart ||= []);
    // Drop any previous MasterMind entry, then re-add — keeps other tools hooks intact.
    // Ownership is the command path, not a substring: another tool at
    // /their/tool/session-start.sh matched the old check and was deleted.
    const mine = (e) => (e?.hooks || []).some((h) => {
      const c = typeof h?.command === "string" ? h.command.replace(/^"|"$/g, "") : "";
      return c === cmd.replace(/^"|"$/g, "") || c.startsWith(mmHooks);
    });
    const clean = list.filter((e) => !mine(e));
    clean.push({
      matcher: "startup|clear|compact",
      hooks: [{ type: "command", command: cmd, async: false }],
    });
    s.hooks.SessionStart = clean;
    fs.writeFileSync(p, JSON.stringify(s, null, 2) + "\n");
  ' 2>/dev/null \
    && ok "bootstrap hook — kernel re-injected on startup + compaction" \
    || warn "left your settings.json alone (could not parse it) — bootstrap hook not registered"
  return 0
}

# Remove every dangling symlink in a dir (target gone — e.g. a renamed skill).
prune_dead_links() {
  local dir="$1"; [ -d "$dir" ] || return 0
  shopt -s nullglob
  local l
  for l in "$dir"/*; do
    if [ -L "$l" ] && [ ! -e "$l" ]; then
      if [ "$MODE" = check ]; then bad "stale link $(basename "$l") → $(readlink "$l")"; ISSUES=$((ISSUES + 1))
      else rm -f "$l"; PRUNED=$((PRUNED + 1)); fi
    fi
  done
  shopt -u nullglob
}

# Remove a path only if it's a MasterMind symlink into this repo (never user files).
remove_link() {
  local f="$1"
  if is_ours "$f"; then rm -f "$f"; ok "removed $(basename "$f")"; return 0; fi
  return 1
}

# safe_link() renames a real file to <name>.bak-<stamp> before linking, and uninstall used to
# leave that orphaned — the user's own file silently stayed gone. Called only for the paths
# safe_link actually touches: restoring on every removed link would resurrect a stale backup
# over content written after the install.
restore_backup() {
  local f="$1" bak=""
  path_exists "$f" && return 0
  [ -f "$f.mm-backup" ] || return 0
  bak="$(head -1 "$f.mm-backup")"
  rm -f "$f.mm-backup"
  [ -n "$bak" ] && [ -f "$bak" ] || return 0
  mv "$bak" "$f" && ok "restored your original $(basename "$f") (from $(basename "$bak"))"
}

# Tell the user if their clone is behind origin. Network-optional: any failure is silent.
check_updates() {
  command -v git >/dev/null 2>&1 || return 0
  git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  git -C "$REPO" fetch --quiet 2>/dev/null || return 0
  local here up base
  here="$(git -C "$REPO" rev-parse @ 2>/dev/null)"        || return 0
  up="$(git -C "$REPO" rev-parse '@{u}' 2>/dev/null)"     || return 0
  base="$(git -C "$REPO" merge-base @ '@{u}' 2>/dev/null)" || return 0
  if [ "$here" != "$up" ] && [ "$here" = "$base" ]; then
    printf '%s⬆ An update is available.%s  cd ~/.mastermind && git pull && ~/.mastermind/install.sh\n' "$y" "$x"
  fi
}

# Strip our generated MASTERMIND block from a nested anchor, keeping the project's own
# content. Deletes the file only if nothing of theirs remains. Reverse of mm_write_block.
mm_strip_block() {
  local file="$1" tmp
  [ -f "$file" ] || return 0
  grep -qxF "$MM_START" "$file" || return 1     # exact full line, not a substring mention
  tmp="$(mktemp)"
  # Match START/END only as WHOLE lines (`$0==m`), so a user line that merely *mentions* the
  # marker text is never touched. Buffer the block body; on a matching END, drop it (our
  # block); at EOF still inside a block (a lone START, no END — a half-edited file), FLUSH the
  # buffer so nothing of theirs is lost. Deleting-to-EOF on an unbalanced marker was the bug.
  awk -v S="$MM_START" -v E="$MM_END" '
    $0==S { inb=1; buf=""; next }
    inb && $0==E { inb=0; next }
    inb { buf = buf $0 "\n"; next }
    { print }
    END { if (inb) printf "%s", buf }
  ' "$file" > "$tmp"
  if [ -s "$tmp" ] && grep -q '[^[:space:]]' "$tmp"; then mv "$tmp" "$file"
  else rm -f "$tmp" "$file"; fi
  return 0
}

# Remove every per-app anchor this project generated, reading the same routes.map that
# created them. Leaves the project's own CLAUDE.md/AGENTS.md content intact.
remove_context_anchors() {
  local map="$BRAIN/routes.map"
  [ -f "$map" ] || return 0
  local glob line adir abs
  while IFS= read -r line; do
    line="${line//$'\r'/}"; line="${line%%#*}"; line="$(printf '%s' "$line" | awk '{$1=$1};1')"
    [ -n "$line" ] || continue
    glob="${line%% *}"
    adir="${glob%/\*\*}"; adir="${adir%/\*}"; adir="${adir%/}"
    case "$adir" in ''|'*'|'.'|'**') continue ;; esac
    # The same containment install applies. Validating only one side is not a fix: a
    # `../outside/**` rule deleted a sibling directory's files during UNINSTALL.
    case "$adir" in /*|*\\*) continue ;; esac
    case "/$adir/" in */../*) continue ;; esac
    [ -d "$PROJECT/$adir" ] || continue
    abs="$(mm_resolve_inside_project "$PROJECT/$adir")" || continue
    mm_strip_block "$abs/CLAUDE.md" && n=$((n + 1)) || true
    mm_strip_block "$abs/AGENTS.md" || true
    [ -f "$abs/.cursor/rules/mastermind.mdc" ] && { rm -f "$abs/.cursor/rules/mastermind.mdc"; n=$((n + 1)); }
  done < "$map"
}

# --- Uninstall (scoped): remove MasterMind links, leave your own files -------
if [ "$MODE" = uninstall ]; then
  printf 'Removing MasterMind from %s%s%s…\n' "$g" "$([ "$SCOPE" = global ] && echo "global (~/.claude)" || echo "this project")" "$x"
  n=0
  remove_link "$CLAUDE_DIR/CLAUDE.md"   && n=$((n + 1))
  remove_link "$CLAUDE_DIR/engineering" && n=$((n + 1))
  shopt -s nullglob
  for l in "$CLAUDE_DIR"/skills/* "$CLAUDE_DIR"/agents/*; do remove_link "$l" && n=$((n + 1)); done
  shopt -u nullglob
  [ -n "$AGENTS_FILE" ] && { remove_link "$AGENTS_FILE" && n=$((n + 1)); }
  restore_backup "$CLAUDE_DIR/CLAUDE.md"
  [ "$SCOPE" = global ] && restore_backup "$CLAUDE_DIR/engineering"
  # Codex's global file is ours only when it's our symlink; remove_link leaves a real file alone.
  [ "$SCOPE" = global ] && { remove_link "$CODEX_GLOBAL" && n=$((n + 1)); }
  # Project-scoped artifacts: only ever touch these when uninstalling THIS project.
  # They live under $PROJECT, so removing them during a --global uninstall would silently
  # de-wire whatever directory the user happened to run the command from.
  if [ "$SCOPE" = project ]; then
    remove_context_anchors    # keeps each app's own CLAUDE.md content
    if [ -f "$PROJECT/.cursor/rules/mastermind.mdc" ]; then rm -f "$PROJECT/.cursor/rules/mastermind.mdc"; ok "removed .cursor/rules/mastermind.mdc"; n=$((n + 1)); fi
    if [ -f "$PROJECT/.cursor/rules/mastermind-field.mdc" ]; then rm -f "$PROJECT/.cursor/rules/mastermind-field.mdc"; ok "removed .cursor/rules/mastermind-field.mdc"; n=$((n + 1)); fi
    # Retired targets (Gemini/Copilot) from earlier installs — cleaned up so an upgrade
    # doesn't strand a file pointing at a brain that no longer wires it.
    remove_link "$PROJECT/GEMINI.md"                       && n=$((n + 1))
    remove_link "$PROJECT/.github/copilot-instructions.md" && n=$((n + 1))
    if [ -f "$PROJECT/.github/hooks/mastermind.json" ]; then rm -f "$PROJECT/.github/hooks/mastermind.json"; ok "removed .github/hooks/mastermind.json"; n=$((n + 1)); fi
    # Cursor's hooks.json is shared: filter our entries out rather than deleting the file.
    if [ -f "$PROJECT/.cursor/hooks.json" ] && command -v node >/dev/null 2>&1; then
      MM_DST="$PROJECT/.cursor/hooks.json" MM_HOOKS_DIR="$BRAIN/hooks/" node -e '
        const fs=require("fs"); const p=process.env.MM_DST, mmHooks=process.env.MM_HOOKS_DIR||"";
        let s; try { s=JSON.parse(fs.readFileSync(p,"utf8")||"{}"); } catch { process.exit(3); }
        let hit=false;
        for (const ev of Object.keys(s.hooks||{})) {
          const owns=(c)=>typeof c==="string" && ((mmHooks && c.startsWith(mmHooks)) || c.includes("/.mastermind/hooks/session-start.sh") || c.includes("/hooks/session-start.sh") && c.includes("mastermind"));
          const mine=(e)=>owns(e&&e.command);
          const keep=(s.hooks[ev]||[]).filter(e=>!mine(e));
          if (keep.length !== (s.hooks[ev]||[]).length) hit=true;
          if (keep.length) s.hooks[ev]=keep; else delete s.hooks[ev];
        }
        if (!hit) process.exit(1);
        fs.writeFileSync(p, JSON.stringify(s,null,2)+"\n");
      ' 2>/dev/null && { ok "unwired .cursor/hooks.json"; n=$((n + 1)); }
    fi
  fi
  # The bootstrap hook is merged into a settings.json we do not own — filter our entry
  # out and leave everything else exactly as it was. Without this, uninstalling and then
  # deleting the clone leaves every session firing a hook that points at a missing script.
  if [ -f "$CLAUDE_DIR/settings.json" ] && command -v node >/dev/null 2>&1; then
    MM_SETTINGS="$CLAUDE_DIR/settings.json" MM_HOOKS_DIR="$BRAIN/hooks/" node -e '
      const fs=require("fs"); const p=process.env.MM_SETTINGS;
      let s; try { s=JSON.parse(fs.readFileSync(p,"utf8")||"{}"); } catch { process.exit(3); }
      const list=(s.hooks||{}).SessionStart||[];
      const mmHooks=process.env.MM_HOOKS_DIR||"";
      const owns=(c)=>typeof c==="string" && ((mmHooks && c.startsWith(mmHooks)) || c.includes("/.mastermind/hooks/session-start.sh") || c.includes("/hooks/session-start.sh") && c.includes("mastermind"));
      const isMine=(e)=>((e&&e.hooks)||[]).some((h)=>owns(typeof (h&&h.command)==="string"?h.command.replace(/^"|"$/g,""):""));
      const keep=list.filter(e=>!isMine(e));
      if (keep.length === list.length) process.exit(1);
      if (keep.length) s.hooks.SessionStart=keep; else delete s.hooks.SessionStart;
      if (s.hooks && !Object.keys(s.hooks).length) delete s.hooks;
      fs.writeFileSync(p, JSON.stringify(s,null,2)+"\n");
    ' 2>/dev/null && { ok "unwired the bootstrap hook from settings.json"; n=$((n + 1)); }
  fi
  # Remove the exact pointer line we appended (and the blank line before it), leaving every
  # other line untouched. Warning about it and walking away left our text in their file.
  # Two gaps left our text in files we promised to leave as we found them: .claude/CLAUDE.md was
  # missing from this list, and the match only looked for the GLOBAL hint while an isolated
  # install appends a project-relative one.
  for f in ${AGENTS_FILE:+"$AGENTS_FILE"} ${CLAUDE_DIR:+"$CLAUDE_DIR/CLAUDE.md"} \
           "$PROJECT/GEMINI.md" "$PROJECT/.github/copilot-instructions.md" \
           ${CODEX_GLOBAL:+"$CODEX_GLOBAL"}; do
    [ -f "$f" ] || continue                        # symlinks are removed above, not edited
   for HINT in "$HINT_GLOBAL" "$HINT_ISOLATED"; do
    grep -qF "$HINT" "$f" || continue
    _pt="$(mktemp)"
    HINT="$HINT" awk 'BEGIN{h=ENVIRON["HINT"]} $0==h{skip=1; next} {if(skip && $0==""){skip=0; next} skip=0; print}' "$f" > "$_pt"
    if [ -s "$_pt" ] && grep -q "[^[:space:]]" "$_pt"; then
      cat "$_pt" > "$f"; ok "removed the MasterMind pointer from $(basename "$f")"; n=$((n + 1))
    else
      rm -f "$f"; ok "removed $(basename "$f") (it held only our pointer)"; n=$((n + 1))
    fi
    rm -f "$_pt"
   done
  done
  # Drop removed tools from the install record, or --check keeps demanding wiring the user
  # deliberately took away.
  if [ -f "$PROJECT/.mastermind/.installed" ]; then
    _keep="$(sed -n 's/^tools=//p' "$PROJECT/.mastermind/.installed")"
    for _g in ${TOOLS[@]+"${TOOLS[@]}"}; do
      _keep="$(printf '%s' "$_keep" | tr ' ' '\n' | grep -vx "$_g" | tr '\n' ' ')"
    done
    _keep="$(printf '%s' "$_keep" | sed 's/  */ /g; s/^ //; s/ $//')"
    if [ -n "$_keep" ]; then
      _tf="$(mktemp)"; sed "s|^tools=.*|tools=$_keep|" "$PROJECT/.mastermind/.installed" > "$_tf"
      cat "$_tf" > "$PROJECT/.mastermind/.installed"; rm -f "$_tf"
    else
      rm -f "$PROJECT/.mastermind/.installed"
    fi
  fi
  printf '\n%s✓ removed %d link(s).%s Your own files were left untouched. (~/.mastermind stays; delete the clone to remove the brain.)\n' "$g" "$n" "$x"
  exit 0
fi

# --- Brain source (always) ---------------------------------------------------
# Never point ~/.mastermind at itself — that loop makes the brain unreadable and every
# glob below silently stops matching. REPO is resolved with `pwd -P` above so this should
# be unreachable; it stays as a hard stop because the failure mode is catastrophic and
# completely silent (the installer still prints ✓ while linking a literal `*`).
if [ "$MODE" != check ]; then
  mm_link="$HOME/.mastermind"
  # Compare RESOLVED paths, not strings. The string form shipped in 0.29.0 and broke every
  # real install: `npx mastermind-brain` clones the brain straight to ~/.mastermind and runs
  # this script from there, so REPO == $HOME/.mastermind and the installer aborted. It slipped
  # through testing because sandboxes used /tmp, which `pwd -P` rewrites to /private/tmp — the
  # two strings differed and the link was created. A real HOME has no such symlink.
  mm_link_real=""
  [ -e "$mm_link" ] && mm_link_real="$(cd "$mm_link" 2>/dev/null && pwd -P || true)"

  if [ "$mm_link_real" = "$REPO" ]; then
    # Already the brain: either ~/.mastermind IS this clone (the npx path), or it is a symlink
    # already pointing here. Nothing to link — linking is what would create the loop.
    :
  elif [ -d "$mm_link" ] && [ ! -L "$mm_link" ]; then
    # A different real clone lives there. `ln -sfn` would silently create a link INSIDE it
    # (~/.mastermind/mastermind) and leave the brain unfound, so stop and say what to do.
    printf '%s✖ %s is a different brain%s (%s).\n' "$r" "$mm_link" "$x" "${mm_link_real:-unreadable}" >&2
    printf '  Remove or move it first, then re-run — refusing to write inside someone else'"'"'s clone.\n' >&2
    exit 1
  else
    ln -sfn "$REPO" "$mm_link"
  fi
fi

# --- Containment: nothing this run writes may resolve outside the project ------
# Checked once, before any write, for every directory and file the installer touches in
# project scope. Uninstall is included: it deletes, and a redirected path deletes elsewhere.
if [ "$SCOPE" = project ] && [ -n "${PROJECT:-}" ]; then
  # Directories AND the exact files the installer overwrites. A directory-only list left every
  # owned file redirectable: .cursor/rules/mastermind.mdc, .mastermind/VERSION, .manifest and
  # .installed were all written through a symlink to outside the repo, exit 0.
  for _t in "$PROJECT/.claude" "$PROJECT/.claude/skills" "$PROJECT/.claude/agents" \
            "$PROJECT/.cursor" "$PROJECT/.cursor/rules" "$PROJECT/.mastermind" \
            "$PROJECT/.github/hooks" "$PROJECT/AGENTS.md" "$PROJECT/CLAUDE.md" \
            "$PROJECT/.claude/settings.json" "$PROJECT/.claude/CLAUDE.md" \
            "$PROJECT/.cursor/hooks.json" "$PROJECT/.cursor/rules/mastermind.mdc" \
            "$PROJECT/.cursor/rules/mastermind-field.mdc" "$PROJECT/.github/hooks/mastermind.json" \
            "$PROJECT/.mastermind/VERSION" "$PROJECT/.mastermind/.manifest" \
            "$PROJECT/.mastermind/.installed"; do
    mm_assert_contained "$_t"
  done
  unset _t
fi

# --- Per-project sanity: need a real project dir, not the clone or ~ ----------
if [ "$SCOPE" = project ] && [ "$MODE" = install ] && { [ "$PROJECT" -ef "$REPO" ] || [ "$PROJECT" -ef "$HOME" ]; }; then
  printf 'MasterMind brain → ~/.mastermind  %s✓ ready%s\n\n' "$g" "$x"
  printf 'Now add it to a project:\n'
  printf '  cd your-project && ~/.mastermind/install.sh      (just that project — recommended)\n'
  printf '  ~/.mastermind/install.sh --global                (Claude Code, every project)\n'
  exit 0
fi

# --- Isolated mode: give this project its own brain --------------------------
# Copies the engine into <project>/.mastermind/ (committed) so the project owns its field,
# lessons and stack instead of sharing one clone. Paths are rewritten project-relative, never
# absolute, so a teammate who pulls the repo gets working paths, not this machine's home.
#
# ISO_ENGINE paths are refreshed every run — that's how updates land. Refreshed FILE-BY-FILE,
# never by wiping the directory: a project may add its own skill or agent inside the brain, and
# that work must survive an update. Files upstream retired are removed by the manifest
# reconciliation below, which only ever touches paths WE shipped — so anything the project added
# is invisible to it and is kept. Also surviving: a pack's lessons.md / stack-defaults.md and
# ISO_OWNED (a project's own knowledge).
# ROUTER.md and active-field.md are ISO_OWNED, not engine: both are DERIVED from the project's
# own field, so refreshing them from the source would overwrite what a project generated. They
# seed once (from a *.seed.md that declares "no field yet") and are then the project's to regen.
# bin/ + cli/ ride along so the lookup surface is runnable from INSIDE the project. Agents
# run sandboxed to the workspace — Claude Code refuses to execute ~/.mastermind/bin/mastermind
# because it resolves outside the allowed directories — so a shim that only exists in the
# shared clone is unusable exactly where it was meant to help. ~14KB.
# `scripts/*` earns its place here: `init` and `levelup bootstrap` tell the model to run
# build-router and check-integrity, and without them an isolated init dead-ends on
# "Cannot find module '.mastermind/scripts/build-router.mjs'" after doing all the work.
# Both resolve their root relative to themselves, so a copy inside .mastermind regenerates
# THAT brain. build-library is deliberately absent — it writes into the website repo.
ISO_ENGINE=(CLAUDE.md AGENTS.md engineering/core skills agents hooks bin cli
            scripts/build-router.mjs scripts/check-integrity.mjs)
ISO_OWNED=(engineering/active-field.md engineering/ROUTER.md)

sync_isolated_brain() {
  local dst="$PROJECT/.mastermind" d
  local SHIPPED; SHIPPED="$(mktemp)"
  # NEVER write through a symlink. Every rm -rf below would resolve through it and delete
  # someone else's directory — including the shared clone, which would break every other
  # project. Refuse loudly instead.
  if [ -L "$dst" ]; then
    printf '%s✖ .mastermind is a symlink (→ %s).%s Refusing to write through it — remove it first.\n' \
      "$r" "$(readlink "$dst")" "$x" >&2; exit 1
  fi
  if path_exists "$dst" && [ ! -d "$dst" ]; then
    printf '%s✖ .mastermind exists and is not a directory.%s Move it aside first.\n' "$r" "$x" >&2; exit 1
  fi
  mkdir -p "$dst"

  for d in "${ISO_ENGINE[@]}" "${ISO_OWNED[@]}"; do mm_assert_no_symlink_path "$dst" "$d"; done

  # Engine: always refreshed — but file-by-file, NEVER by wiping the directory. `rm -rf` here
  # would delete a skill or agent the project added to its own brain, and it short-circuited the
  # manifest reconciliation that exists precisely to protect those. -p keeps the mode bits, so
  # hooks/session-start.sh stays executable; -R and `-type l` keep AGENTS.md a symlink.
  local ef erel
  for d in "${ISO_ENGINE[@]}"; do
    [ -e "$REPO/$d" ] || continue
    if [ -d "$REPO/$d" ] && [ ! -L "$REPO/$d" ]; then
      while IFS= read -r ef; do
        erel="${ef#"$REPO/$d/"}"
        mm_assert_no_symlink_path "$dst" "$d/$erel"
        mkdir -p "$(dirname "$dst/$d/$erel")"
        rm -rf "$dst/$d/${erel:?}"
        cp -Rp "$ef" "$dst/$d/$erel"
        printf '%s\n' "$d/$erel" >> "$SHIPPED"
      done < <(find "$REPO/$d" \( -type f -o -type l \))
    else
      mkdir -p "$(dirname "$dst/$d")"
      rm -rf "$dst/${d:?}"
      cp -Rp "$REPO/$d" "$dst/$d"
      printf '%s\n' "$d" >> "$SHIPPED"
    fi
  done

  # Fields are the PROJECT's, not ours. We ship no field: a pre-baked pack on a project it
  # doesn't fit is worse than none (it carries dead weight and misleads), so `init` builds the
  # right field for the detected stack from _template. We only ever seed the scaffold, once.
  #
  # Once a field directory exists it is untouched forever — not refreshed, not retired. That is
  # what "the project owns its field, lessons and stack" has to mean; anything else lets an
  # update reach in and change knowledge the project earned. Packs a project already has (from
  # an older release that did ship one) are therefore preserved as-is, and never gutted.
  local tsrc="$REPO/engineering/fields/_template"
  if [ -d "$tsrc" ] && [ ! -d "$dst/engineering/fields/_template" ]; then
    mkdir -p "$dst/engineering/fields/_template"
    local tf trel
    while IFS= read -r tf; do
      trel="${tf#"$tsrc"/}"
      mkdir -p "$(dirname "$dst/engineering/fields/_template/$trel")"
      cp -p "$tf" "$dst/engineering/fields/_template/$trel"
    done < <(find "$tsrc" -type f)
  fi

  # Project-owned singletons: seed once, then leave alone. A `<name>.seed.md` beside the file is
  # what a NEW project starts from — the repo's own copy describes the repo's field, which is not
  # what someone else's project should inherit. Seeded active-field declares no field yet.
  local seed
  for d in "${ISO_OWNED[@]}"; do
    [ -e "$dst/$d" ] && continue
    mkdir -p "$(dirname "$dst/$d")"
    seed="$REPO/${d%.md}.seed.md"
    if [ -f "$seed" ]; then cp -p "$seed" "$dst/$d"; else cp -Rp "$REPO/$d" "$dst/$d"; fi
  done

  # Point the copied docs at THIS project's brain instead of the shared clone.
  # Portable and git-safe: `.mastermind/...` resolves from the project root on any machine.
  local file
  # Only files WE shipped are rewritten — the installer never edits a project's own notes.
  # -I skips binaries (rewriting those would corrupt them); the .md filter keeps this to
  # prose, never vendored data or scripts.
  while IFS= read -r file; do
    case "$file" in *.md) ;; *) continue ;; esac
    [ -f "$dst/$file" ] || continue
    grep -qI '~/\.mastermind' "$dst/$file" 2>/dev/null || continue
    _lz="$(mktemp)"
    sed 's|~/\.mastermind|.mastermind|g' "$dst/$file" > "$_lz" && cat "$_lz" > "$dst/$file"
    rm -f "$_lz"
  done < "$SHIPPED"

  # --- reconcile deletions, using the manifest of what WE installed -------------
  # Only paths that are BOTH in the previous manifest (we put them there) and absent from
  # the new one (upstream retired them) are removed. A file the project added was never in
  # a manifest, so it is invisible to this and survives untouched. OWNED files are excluded
  # outright — they belong to the project the moment they are seeded.
  local manifest="$dst/.manifest" newman; newman="$(mktemp)"
  sort -u "$SHIPPED" > "$newman"

  if [ -f "$manifest" ]; then
    local gone
    while IFS= read -r gone; do
      [ -n "$gone" ] || continue
      case "$(basename "$gone")" in lessons.md|stack-defaults.md|active-field.md|prefs.md|ROUTER.md|journal.md) continue ;; esac
      # Fields belong to the project. Releases before 0.27.0 shipped a frontend pack, so its
      # files sit in those projects' manifests — retiring them here would gut a pack the project
      # has been building on. Never retire anything under engineering/fields/. (ROUTER.md moved
      # from engine to project-owned in 0.27.0, so it's excluded above for the same reason.)
      case "$gone" in engineering/fields/*) continue ;; esac
      # in the OLD manifest, still on disk, but no longer shipped → ours, and retired
      # `../precious.txt` in a committed manifest deleted a file outside the project.
      case "$gone" in /*|*..*|*\\*) warn "manifest: refusing to act on '$gone'"; continue ;; esac
      if [ -e "$dst/$gone" ] && ! grep -qxF "$gone" "$newman"; then
        mm_assert_no_symlink_path "$dst" "$gone"
        rm -f "$dst/$gone"
      fi
    done < "$manifest"
    # prune directories the removals emptied, but never the root
    find "$dst" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  fi

  # The manifest records the state we just installed, minus the project's own files.
  cp "$newman" "$manifest"
  rm -f "$newman" "$SHIPPED"

  printf '%s\n' "$(cat "$REPO/VERSION")" > "$dst/VERSION"
}

# --- Field + context: per-app routing in a monorepo --------------------------
# `routes.map` maps `<path-glob> <context>` per line; the installer compiles each rule into
# that app dir's native anchor (nested CLAUDE.md / AGENTS.md + a glob-scoped Cursor rule). The
# AI never reads routes.map — the tool attaches the right context by file path, so selection is
# deterministic. No routes.map = single-field, and this block is a no-op.

# Relative prefix from an anchor dir back to the project root: "apps/web" → "../../".
mm_rel_prefix() {
  local dir="$1" pfx="" part
  IFS='/' read -ra part <<< "$dir"
  for _ in "${part[@]+"${part[@]}"}"; do pfx="../$pfx"; done
  printf '%s' "$pfx"
}

# Write a generated block into a file between MASTERMIND markers, preserving anything the
# project already has outside them. Idempotent: re-running replaces only our block. This is
# how we drop an anchor into an app dir that may already hold the project's own CLAUDE.md.
mm_write_block() {
  local file="$1" body="$2" tmp kept=""
  mkdir -p "$(dirname "$file")"
  tmp="$(mktemp)"
  if [ -f "$file" ]; then
    # Strip any prior block of OURS (whole-line marker match, buffer-flush on an unbalanced
    # one so a half-edited file never loses the project's content), keeping everything else.
    # Command substitution trims trailing newlines, so re-runs don't accumulate blank lines.
    kept="$(awk -v S="$MM_START" -v E="$MM_END" '
      $0==S { inb=1; buf=""; next }
      inb && $0==E { inb=0; next }
      inb { buf = buf $0 "\n"; next }
      { print }
      END { if (inb) printf "%s", buf }
    ' "$file")"
  fi
  # Kept content, then one blank line, then our block. A brand-new file has no kept content,
  # so it starts straight at the block — no leading blank.
  [ -n "$kept" ] && printf '%s\n\n' "$kept" >> "$tmp"
  {
    printf '%s\n' "$MM_START"
    printf '<!-- generated by install.sh — edit above or below, never inside -->\n'
    printf '%s\n' "$body"
    printf '%s\n' "$MM_END"
  } >> "$tmp"
  mv "$tmp" "$file"
}

# Compile routes.map → per-app anchors. Reads from the ACTIVE brain ($BRAIN).
generate_context_anchors() {
  local map="$BRAIN/routes.map"
  [ -f "$map" ] || return 0
  # No field ships by default (0.27.0), so there's no fixed fallback: a context inherits the
  # project's first real (non-scaffold) field, if it has built one. Empty if none yet — the
  # per-context loop below then warns and skips until `init` builds a field.
  local first_field default_field=""
  first_field="$(find "$BRAIN/engineering/fields" -maxdepth 1 -mindepth 1 -type d ! -name '_*' 2>/dev/null | head -1)"
  [ -n "$first_field" ] && default_field="$(basename "$first_field")"

  local glob ctx line
  while IFS= read -r line; do
    line="${line//$'\r'/}"; line="${line%%#*}"; line="$(printf '%s' "$line" | awk '{$1=$1};1')"
    [ -n "$line" ] || continue
    # A rule must be exactly `<glob> <context>`, and the context a plain slug. A one-token
    # line (context omitted) or a name with `/` or another metachar would break the sed
    # templating below and, under set -e, abort the whole install — so reject it here.
    if [ "$(printf '%s' "$line" | wc -w | tr -d ' ')" != 2 ]; then
      warn "routes.map: '$line' is not '<glob> <context>' — skipped"; ISSUES=$((ISSUES + 1)); continue
    fi
    glob="${line%% *}"; ctx="${line##* }"
    case "$ctx" in *[!A-Za-z0-9_-]*)
      warn "routes.map: context '$ctx' has invalid characters (use letters, digits, - or _) — skipped"
      ISSUES=$((ISSUES + 1)); continue ;;
    esac

    # Anchor dir = the glob without its trailing /** or /*. A root/wildcard glob is handled by
    # the top-level wiring. Do this first: if the app dir isn't there, skip before creating a
    # context for it, so a stale route leaves no orphan contexts/ dir behind.
    local adir="${glob%/\*\*}"; adir="${adir%/\*}"; adir="${adir%/}"
    case "$adir" in ''|'*'|'.'|'**') continue ;; esac
    # `../outside/**` reproducibly wrote into a sibling directory.
    case "$adir" in /*|*\\*) warn "routes.map: '$glob' must be a relative path inside the project — skipped"; ISSUES=$((ISSUES + 1)); continue ;; esac
    case "/$adir/" in */../*) warn "routes.map: '$glob' may not contain '..' — skipped"; ISSUES=$((ISSUES + 1)); continue ;; esac
    local abs="$PROJECT/$adir"
    if [ ! -d "$abs" ]; then warn "routes.map: '$glob' → no directory $adir/ — skipped"; continue; fi
    if ! abs="$(mm_resolve_inside_project "$abs")"; then
      warn "routes.map: '$glob' resolves outside the project — skipped"; ISSUES=$((ISSUES + 1)); continue
    fi

    # Seed the context from the template on first use, then read the field it names.
    local cdir="$BRAIN/engineering/contexts/$ctx"
    if [ ! -d "$cdir" ]; then
      local tpl="$BRAIN/engineering/_context_template"; [ -d "$tpl" ] || tpl="$REPO/engineering/_context_template"
      mkdir -p "$cdir"
      sed "s/<field>/$default_field/g; s/<name>/$ctx/g" "$tpl/field.md" > "$cdir/field.md"
      sed "s/<name>/$ctx/g" "$tpl/lessons.md" > "$cdir/lessons.md"
    fi
    local field; field="$(sed -n 's/^field:[[:space:]]*//p' "$cdir/field.md" | head -1)"; field="${field:-$default_field}"
    if [ -z "$field" ] || [ ! -d "$BRAIN/engineering/fields/$field" ]; then
      warn "context '$ctx' needs a field this brain doesn't have yet (${field:-none set}). Run init to build a field, then re-run install — skipped for now."
      ISSUES=$((ISSUES + 1)); continue
    fi

    local pfx; pfx="$(mm_rel_prefix "$adir")"
    local imports="@${pfx}.mastermind/CLAUDE.md
@${pfx}.mastermind/engineering/fields/${field}/field.md
@${pfx}.mastermind/engineering/contexts/${ctx}/field.md
@${pfx}.mastermind/engineering/contexts/${ctx}/lessons.md"

    # Claude Code + Codex read these nested files by path (tool-enforced).
    mm_write_block "$abs/CLAUDE.md" "$imports"
    mm_write_block "$abs/AGENTS.md" "$imports"
    # Cursor: a SMALL glob-scoped rule (not the full kernel — the root rule carries that; a
    # full copy per app would feed Cursor's known monorepo over-load bug).
    mkdir -p "$abs/.cursor/rules"
    { printf -- '---\nglobs: %s\ndescription: MasterMind context for %s\n---\n' "$glob" "$ctx"
      printf 'This app uses the MasterMind **%s** field and the **%s** context.\n' "$field" "$ctx"
      printf 'Its knowledge is in `%s.mastermind/engineering/fields/%s/` and `.../contexts/%s/`.\n' "$pfx" "$field" "$ctx"
      printf 'The repo-root `.cursor/rules/mastermind.mdc` carries the full kernel; this only routes.\n'
    } > "$abs/.cursor/rules/mastermind.mdc"

    ok "context '$ctx' ($field) → $adir/"
  done < "$map"
}

# Seed a commented example routes.map so the feature is discoverable, without routing anything.
seed_routes_example() {
  local map="$BRAIN/routes.map"
  [ -f "$map" ] && return 0
  cat > "$map" <<'RMAP'
# routes.map — per-app field/context routing (monorepos). One rule per line:
#   <path-glob>   <context-name>
# The installer compiles each rule into that directory's native, tool-enforced anchor
# (nested CLAUDE.md / AGENTS.md + a glob-scoped Cursor rule). A missing context is created
# from the template, using the default field. Delete this file to go back to single-field.
#
# Example (uncomment and adapt):
#   apps/web/**    web
#   apps/api/**     api
#   packages/**       shared
RMAP
}

if [ "$ISOLATED" = 1 ] && [ "$MODE" = install ]; then
  sync_isolated_brain
  ok "isolated brain → .mastermind/ (v$(cat "$BRAIN/VERSION")) — this project's own field, lessons and stack"
  seed_routes_example
  generate_context_anchors
fi

if [ "$MODE" != check ]; then
  printf 'MasterMind → %s%s%s\n' "$g" "$([ "$SCOPE" = global ] && echo "global — every project" || echo "this project")" "$x"
fi

# True if a path is a MasterMind link (into this repo) or carries the pointer line.
is_wired() {
  local f="$1"
  is_ours "$f" || { [ -f "$f" ] && grep -q 'mastermind/CLAUDE.md' "$f"; }
}

# --- Which tools? -------------------------------------------------------------
if [ ${#TOOLS[@]} -eq 0 ]; then
  if [ "$MODE" = check ]; then
    # Say it out loud when we switched scope — a silent switch is its own confusion.
    [ "${CHECK_SCOPE_SWITCHED:-0}" = 1 ] &&
      printf '%sno project here — checking the global install instead.%s\n\n' "$y" "$x"
    # Prefer the install record: it says what SHOULD be wired. Inference below is the fallback
    # for installs made before the record existed, and is what let a deleted rule read as healthy.
    if [ "$SCOPE" = project ] && [ -f "$PROJECT/.mastermind/.installed" ]; then
      _rec="$(sed -n 's/^tools=//p' "$PROJECT/.mastermind/.installed")"
      for _t in $_rec; do TOOLS+=("$_t"); done
      unset _rec _t
    fi
    # verify only what's actually wired here (or globally with --global)
    [ ${#TOOLS[@]} -eq 0 ] && is_wired "$CLAUDE_DIR/CLAUDE.md" && TOOLS+=("claude")
    [ ${#TOOLS[@]} -eq 0 ] && [ -n "$AGENTS_FILE" ] && is_wired "$AGENTS_FILE" && TOOLS+=("agents")
    [ ${#TOOLS[@]} -eq 0 ] && [ -f "$PROJECT/.cursor/rules/mastermind.mdc" ] && TOOLS+=("cursor")
    [ "$SCOPE" = global ] && is_wired "$CODEX_GLOBAL" && TOOLS+=("codex")
    if [ ${#TOOLS[@]} -eq 0 ]; then
      bad "MasterMind isn't set up $([ "$SCOPE" = global ] && echo globally || echo 'in this project') yet."
      echo "  Run:  ~/.mastermind/install.sh$([ "$SCOPE" = global ] && echo ' --global')"
      exit 1
    fi
  else
    # install: wire the tools you have
    { command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; } && TOOLS+=("claude")
    # Codex only needs wiring of its own in global scope; per-project it reads AGENTS.md,
    # which the `agents` entry below always wires.
    [ "$SCOPE" = global ] && { command -v codex >/dev/null 2>&1 || [ -d "$CODEX_HOME_DIR" ]; } && TOOLS+=("codex")
    if [ "$SCOPE" = project ]; then
      { command -v cursor >/dev/null 2>&1 || [ -d "$HOME/.cursor" ]; } && TOOLS+=("cursor")
      # AGENTS.md always: it's the open instruction file, it costs one symlink, and it's how
      # every tool we don't wire natively still reads the brain.
      TOOLS+=("agents")
    fi
    if [ ${#TOOLS[@]} -eq 0 ]; then
      warn "No supported tool detected."
      echo "  You need an AI coding tool first — e.g. Claude Code: https://claude.com/claude-code"
    fi
  fi
fi

# --- Per tool ----------------------------------------------------------------
# ${TOOLS[@]+…} guard: on macOS bash 3.2, an empty array under `set -u` is treated
# as unbound — so a tool-less machine would crash here instead of exiting gracefully.
for tool in ${TOOLS[@]+"${TOOLS[@]}"}; do
  case "$tool" in
    claude)  wire_claude "$CLAUDE_DIR" ;;
    agents|agents.md)
      printf '\nAGENTS.md:\n'
      if [ -z "$AGENTS_FILE" ]; then warn "AGENTS.md is per-project — run this inside a project"
      else wire_brain_file "$AGENTS_FILE" "$BRAIN/AGENTS.md"; fi ;;
    cursor)
      if [ "$SCOPE" = global ]; then printf '\nCursor:\n'; warn "Cursor rules are per-project — run this inside a project"
      else printf '\nCursor:\n'; wire_cursor; fi ;;
    codex)
      printf '\nCodex:\n'
      # Project scope: Codex reads the repo's own AGENTS.md — the same file `agents` wires, so
      # naming either tool gets Codex working. Global scope has its own file.
      if [ "$SCOPE" = global ]; then wire_codex_global
      else wire_brain_file "$AGENTS_FILE" "$BRAIN/AGENTS.md"; fi ;;
    gemini|copilot)
      warn "$tool is no longer wired automatically — MasterMind is plain Markdown, so point it at $([ "$ISOLATED" = 1 ] && echo '.mastermind/CLAUDE.md' || echo '~/.mastermind/CLAUDE.md') and it works the same." ;;
    *) warn "skipping unknown tool: $tool";;
  esac
done

# The doctor used to infer the expected tool set from artifacts that still existed, so deleting
# one removed it from the check and a broken install reported "healthy". Record what this run
# wired; --check reads it and can then tell "not installed" apart from "installed and missing".
if [ "$MODE" = install ] && [ "$SCOPE" = project ] && [ "$ISOLATED" = 1 ] && [ -d "$PROJECT/.mastermind" ]; then
  # MERGE, never replace. Re-running with one tool named ("install.sh claude" to repair Claude)
  # rewrote the record as claude-only, so the doctor forgot Cursor had ever been wired and
  # called a broken install healthy again — the same blind spot the record exists to remove.
  # Uninstall is what removes a tool from the record; a partial install only ever adds.
  _rec_prev=""
  [ -f "$PROJECT/.mastermind/.installed" ] &&
    _rec_prev="$(sed -n 's/^tools=//p' "$PROJECT/.mastermind/.installed")"
  _rec_all="$(printf '%s %s\n' "$_rec_prev" "${TOOLS[*]}" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')"
  _rec_all="${_rec_all% }"
  { printf 'version=%s\n' "$(cat "$REPO/VERSION" 2>/dev/null || echo unknown)"
    printf 'scope=%s\n' "$SCOPE"
    printf 'tools=%s\n' "$_rec_all"
  } > "$PROJECT/.mastermind/.installed"
fi

# In an isolated project, verify routes.map resolves: every context exists, names a field
# that ships, and its anchor is present. A bad map means an app silently loads the wrong
# knowledge — exactly what this feature exists to prevent — so it counts as an issue.
check_routes() {
  local map="$BRAIN/routes.map"
  [ -f "$map" ] || return 0
  local glob ctx line adir field
  while IFS= read -r line; do
    line="${line//$'\r'/}"; line="${line%%#*}"; line="$(printf '%s' "$line" | awk '{$1=$1};1')"
    [ -n "$line" ] || continue
    if [ "$(printf '%s' "$line" | wc -w | tr -d ' ')" != 2 ]; then
      bad "routes.map: '$line' is not '<glob> <context>'"; ISSUES=$((ISSUES + 1)); continue
    fi
    glob="${line%% *}"; ctx="${line##* }"
    if [ ! -d "$BRAIN/engineering/contexts/$ctx" ]; then
      bad "routes.map: context '$ctx' has no dir — re-run install.sh"; ISSUES=$((ISSUES + 1)); continue
    fi
    field="$(sed -n 's/^field:[[:space:]]*//p' "$BRAIN/engineering/contexts/$ctx/field.md" 2>/dev/null | head -1)"
    [ -d "$BRAIN/engineering/fields/$field" ] || { bad "routes.map: context '$ctx' names missing field '$field'"; ISSUES=$((ISSUES + 1)); continue; }
    adir="${glob%/\*\*}"; adir="${adir%/\*}"; adir="${adir%/}"
    case "$adir" in ''|'*'|'.'|'**') continue ;; esac
    [ -d "$PROJECT/$adir" ] || continue
    if [ -f "$PROJECT/$adir/CLAUDE.md" ] && grep -q 'MASTERMIND:START' "$PROJECT/$adir/CLAUDE.md"; then
      ok "route $adir/ → $ctx ($field)"
    else bad "route $adir/ → $ctx: anchor missing — re-run install.sh"; ISSUES=$((ISSUES + 1)); fi
  done < "$map"
}
[ "$MODE" = check ] && [ "$ISOLATED" = 1 ] && { printf '\nRoutes:\n'; check_routes; }

# --- Report ------------------------------------------------------------------
if [ "$MODE" = check ]; then
  echo
  if [ "$ISSUES" -eq 0 ]; then
    printf '%s✓ MasterMind is healthy here — every wired tool resolves.%s\n' "$g" "$x"
    # An isolated project pins its own copy, so it can drift behind the clone silently.
    # Surface it: the whole point of isolation is that updates are the user's choice, which
    # only works if they can see there is one to make.
    if [ "$ISOLATED" = 1 ] && [ -f "$BRAIN/VERSION" ]; then
      pv="$(cat "$BRAIN/VERSION")"; cv="$(cat "$REPO/VERSION" 2>/dev/null || echo "$pv")"
      if [ "$pv" != "$cv" ]; then
        printf '  %s⬆ this project is on v%s; the clone has v%s.%s  Refresh:  ~/.mastermind/install.sh\n' "$y" "$pv" "$cv" "$x"
      else
        printf '  isolated brain v%s — up to date with the clone.\n' "$pv"
      fi
    fi
    check_updates; exit 0
  else printf '%s✖ %d issue(s). Re-run the installer to repair.%s\n' "$r" "$ISSUES" "$x"; exit 1; fi
fi

if [ "$SCOPE" = project ]; then
  printf '\n%sActive in THIS project.%s  Add another: cd there && ~/.mastermind/install.sh   ·   Claude Code everywhere: --global\n' "$g" "$x"
  printf 'On another tool? It reads AGENTS.md, or point it at %s.\n' "$([ "$ISOLATED" = 1 ] && echo '.mastermind/CLAUDE.md' || echo '~/.mastermind/CLAUDE.md')"
fi
printf 'Update: cd ~/.mastermind && git pull && ~/.mastermind/install.sh   ·   Verify: ~/.mastermind/install.sh --check\n'
printf "\nDone — now RESTART your tool. (Until you restart, the brain isn't loaded yet.)\n"
