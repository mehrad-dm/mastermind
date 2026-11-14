#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MODE=install; SCOPE=project; TOOLS=(); ISOLATED=0; SHARED=0; MODE_FLAG=""

usage() {
  cat <<'USAGE'
MasterMind installer

  install.sh [tools...]        wire this project (default: the tools it detects)
  install.sh --check           report what is wired here and what is broken
  install.sh --uninstall       remove our links and hand back anything of yours
  install.sh --sync            deliver the active field pack to the wired tools, offline
  install.sh --version         print the brain version

Tools:   claude · cursor · codex · agents
Flags:   --global   wire your account instead of this project
         --shared   use the shared brain rather than a copy inside the project
         --isolated keep a copy of the brain in the project (the default)

Requires: bash, git, and Node 18 or newer. On Windows, run it inside WSL.
USAGE
}

for a in "$@"; do
  case "$a" in
    --help|-h)   usage; exit 0 ;;
    --version|-V)
      # The clone may not exist yet; report whichever VERSION is actually readable.
      for _v in "$REPO/VERSION" "$HOME/.mastermind/VERSION"; do
        [ -f "$_v" ] && { cat "$_v"; exit 0; }
      done
      printf 'unknown (no VERSION file found)\n'; exit 0 ;;
    --check|--uninstall|--sync)
      _m="${a#--}"
      if [ -n "$MODE_FLAG" ] && [ "$MODE_FLAG" != "$_m" ]; then
        printf '%s and --%s do different things: pick one.\n' "--$MODE_FLAG" "$_m" >&2; exit 2
      fi
      MODE_FLAG="$_m"; MODE="$_m" ;;
    --global)    SCOPE=global ;;
    --isolated)  ISOLATED=1 ;;   # (now the default; kept so existing commands still work)
    --shared)    SHARED=1 ;;
    --*)         printf 'unknown flag: %s\n' "$a" >&2; exit 2 ;;
    *)           TOOLS+=("$a") ;;
  esac
done

for _t in ${TOOLS+"${TOOLS[@]}"}; do
  case "$_t" in
    claude|cursor|codex|agents|gemini|copilot) : ;;
    *) printf 'unknown tool: %s (expected: claude, cursor, codex, agents)\n' "$_t" >&2; exit 2 ;;
  esac
done

if [ "$ISOLATED" = 1 ] && [ "$SHARED" = 1 ]; then
  printf '%s\n' '--isolated and --shared are opposite modes: pick one.' >&2
  exit 2
fi

g=$'\033[0;32m'; y=$'\033[0;33m'; r=$'\033[0;31m'; x=$'\033[0m'

[ "$ISOLATED" = 1 ] && [ "$SCOPE" = global ] && {
  printf '%s✖ --isolated is per-project by definition; drop --global.%s\n' "$r" "$x" >&2; exit 2
}
ok()   { printf '  %s✓%s %s\n' "$g" "$x" "$*"; }
warn() { printf '  %s⚠%s %s\n' "$y" "$x" "$*"; }
bad()  { printf '  %s✖%s %s\n' "$r" "$x" "$*"; }
ISSUES=0; LINK_FAILED=0; LINKED_SKILLS=0; LINKED_AGENTS=0; PRUNED=0; RENAMED=0; SKIPPED=0; UNFINISHED=0
HINT='Follow ~/.mastermind/CLAUDE.md: the MasterMind brain (skills, agents, engineering rigor).'
HINT_GLOBAL="$HINT"
HINT_ISOLATED='Follow ./.mastermind/CLAUDE.md: the MasterMind brain for this project (skills, agents, engineering rigor).'
# Every release up to 0.31.2 wrote these with an em dash. Cleanup matches the whole line, so
# dropping the old forms would strand our pointer in the files of everyone who installed before.
HINT_LEGACY_GLOBAL='Follow ~/.mastermind/CLAUDE.md — the MasterMind brain (skills, agents, engineering rigor).'
HINT_LEGACY_ISOLATED='Follow ./.mastermind/CLAUDE.md — the MasterMind brain for this project (skills, agents, engineering rigor).'
# Set once $BRAIN/$PROJECT are known (below): an isolated project must point at its OWN brain.
mm_hint() {
  if [ "$ISOLATED" = 1 ]; then
    printf 'Follow ./.mastermind/CLAUDE.md: the MasterMind brain for this project (skills, agents, engineering rigor).'
  else
    printf '%s' "$HINT"
  fi
}
MM_STATE="${MM_STATE_DIR:-$HOME/.mastermind-state}"
mm_record_file() {
  local state="$MM_STATE"
  if [ "$SCOPE" = global ]; then
    printf '%s/global' "$state"
  elif [ -f "$PROJECT/.mastermind/VERSION" ]; then
    printf '%s/.mastermind/.installed' "$PROJECT"
  else
    mm_state_record
  fi
}

mm_state_record() {
  local state="$MM_STATE"
  {
    # Hashed, not sanitised: replacing every unsafe character with _ made /a/b and /a_b the
    # same file, so two projects shared one record and each inherited the other's tools.
    local key legacy
    key="$(printf '%s' "$PROJECT" | mm_hash_stdin | cut -c1-16)"
    legacy="$state/projects/$(printf '%s' "$PROJECT" | tr -c 'A-Za-z0-9._-' '_')"
    # A record written before the key changed is still the truth for this project, as long as it
    # says so; a legacy file from a colliding path names a different project and is ignored.
    if [ ! -f "$state/projects/$key" ] && [ -f "$legacy" ] &&
       grep -qxF "project=$PROJECT" "$legacy" 2>/dev/null; then
      printf '%s' "$legacy"
    else
      printf '%s/projects/%s' "$state" "$key"
    fi
  }
}

mm_routes_ledger() { printf '%s/.routes.generated' "$BRAIN"; }

mm_ledger_add() {
  local f; f="$(mm_routes_ledger)"
  mkdir -p "$(dirname "$f")"
  grep -qxF "$1" "$f" 2>/dev/null || printf '%s\n' "$1" >> "$f"
}

mm_ledger_dirs() {
  local f; f="$(mm_routes_ledger)"
  [ -f "$f" ] || return 0        # no ledger is not an error; set -e would abort the caller
  cat "$f"
}

mm_hash_stdin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1
  else cksum | cut -d' ' -f1
  fi
}

mm_hash() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" 2>/dev/null | cut -d' ' -f1
  else cksum "$1" 2>/dev/null | cut -d' ' -f1
  fi
}

MM_START='<!-- MASTERMIND:START -->'
MM_END='<!-- MASTERMIND:END -->'
MM_KSTART='<!-- MASTERMIND:KERNEL:START -->'
MM_KEND='<!-- MASTERMIND:KERNEL:END -->'
# Codex stops reading project instructions at project_doc_max_bytes, 32 KiB by default.
MM_CODEX_DOC_MAX=32768

find_project_root() {
  local d="$PWD" gitroot=""
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

if [ "$MODE" = check ] && [ "$SCOPE" = project ] && { [ "$PROJECT" -ef "$HOME" ] || [ "$PROJECT" -ef "$REPO" ]; }; then
  SCOPE=global
  CHECK_SCOPE_SWITCHED=1
fi

if [ "$SCOPE" = global ]; then
  CLAUDE_DIR="$HOME/.claude"; AGENTS_FILE=""
else
  CLAUDE_DIR="$PROJECT/.claude";  AGENTS_FILE="$PROJECT/AGENTS.md"
fi
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
CODEX_GLOBAL="$CODEX_HOME_DIR/AGENTS.md"

# A record in the state directory is a shared install's: a plain re-run keeps that mode.
if [ "$MODE" = install ] && [ "$SCOPE" = project ] && [ "$SHARED" = 0 ] && [ "$ISOLATED" = 0 ] &&
   [ ! -f "$PROJECT/.mastermind/VERSION" ]; then
  _recf="$(mm_state_record)"
  if [ -f "$_recf" ] && [ "$(sed -n 's/^mode=//p' "$_recf" | head -1)" != isolated ]; then SHARED=1; fi
  unset _recf
fi
if [ "$SCOPE" = project ] && [ "$SHARED" = 0 ] && [ "$MODE" = install ]; then ISOLATED=1; fi
if [ "$SCOPE" = project ] && { [ "$ISOLATED" = 1 ] || { [ "$SHARED" = 0 ] && [ -f "$PROJECT/.mastermind/VERSION" ] && [ ! -L "$PROJECT/.mastermind" ]; }; }; then
  BRAIN="$PROJECT/.mastermind"; ISOLATED=1
else
  BRAIN="$REPO"
fi

# A project's own copy of the brain carries this file for --check, --sync and --uninstall only.
if [ "$(basename "$REPO")" = .mastermind ] && [ -f "$REPO/.manifest" ] && [ "$MODE" = install ]; then
  printf '%s✖ this is a project'"'"'s own copy of the brain (%s).%s Install and update run from the shared clone:\n' "$r" "$REPO" "$x" >&2
  printf '  npx mastermind-brain      (or ~/.mastermind/install.sh)\n' >&2
  exit 2
fi

if [ "$MODE" = install ] || [ "$MODE" = sync ]; then
  if ! command -v node >/dev/null 2>&1 ||
     ! node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 18 ? 0 : 1)' >/dev/null 2>&1; then
    printf '%s✖ MasterMind needs Node 18 or newer on PATH:%s it registers the session hooks and edits their JSON files with it.\n' "$r" "$x" >&2
    printf '  Nothing was changed. Install Node (https://nodejs.org), then re-run.\n' >&2
    exit 1
  fi
  for _w in "$PROJECT" "$PROJECT/.mastermind" "$PROJECT/.claude" "$PROJECT/.cursor" "$PROJECT/.agents" "$PROJECT/.codex"; do
    if [ -d "$_w" ] && [ ! -L "$_w" ] && ! [ -w "$_w" ]; then
      printf '%s✖ %s is not writable,%s so MasterMind cannot be installed there. Nothing was changed.\n' "$r" "$_w" "$x" >&2
      printf '  Fix the permissions (or run it as the folder'"'"'s owner), then re-run.\n' >&2
      exit 1
    fi
  done
  unset _w
fi

mm_assert_no_symlink_path() {
  local base="$1"
  local rel="$2"
  local cur="$base"
  local rest="$rel"
  local seg real rbase
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
    # The whole chain, not this hop's text: a relative link can point at one that leaves.
    real="$(mm_realpath "$cur")" || {
      printf '%s! %s is a broken or cyclic symlink chain.%s Refusing to write through it.\n' \
        "$r" "${cur#"$PROJECT"/}" "$x" >&2
      exit 1
    }
    rbase="$(cd -P "$base" 2>/dev/null && pwd -P)" || rbase=""
    if [ -z "$rbase" ] || ! mm_inside "$rbase" "$real"; then
      printf '%s! %s points outside the brain (-> %s).%s Refusing to write through it.\n' \
        "$r" "${cur#"$PROJECT"/}" "$real" "$x" >&2
      exit 1
    fi
  done
  return 0
}

mm_resolve_path() {
  local p="$1" tail="" real
  while [ ! -e "$p" ] && [ ! -L "$p" ]; do
    case "$p" in ""|/|.) break ;; esac
    tail="/$(basename "$p")$tail"; p="$(dirname "$p")"
  done
  if [ "$p" = / ]; then printf '%s' "$tail"; return 0; fi
  real="$(mm_realpath "$p")" || return 1
  printf '%s%s' "$real" "$tail"
}

mm_sync_cmd() { if [ "$ISOLATED" = 1 ]; then printf '.mastermind/bin/mastermind sync'; else printf '~/.mastermind/bin/mastermind sync'; fi; }

mm_scope_word() { if [ "$SCOPE" = global ]; then printf 'your home directory'; else printf 'the project'; fi; }

# Kinds: own (a file only we write), file (one we share with the user), link (an entry we create
# or remove without following it), dir, kernel (a brain link or a file inside), brain.
MM_GATE_WHY=""
mm_gate_ok() {
  local kind="$1" path="$2" root="${3:-$PROJECT}" rroot real subject _d _r
  MM_GATE_WHY=""
  rroot="$(mm_resolve_path "$root")" || { MM_GATE_WHY="cannot be checked: $root does not resolve"; return 1; }
  subject="$path"
  case "$kind" in
    own|file)
      if [ -L "$path" ]; then
        real="$(mm_realpath "$path" 2>/dev/null)" || real=""
        # A home directory is the user's own: their dotfiles link is followed while it stays inside.
        if [ "$kind" = file ] && [ "$SCOPE" = global ] && [ -n "$real" ] && mm_inside "$rroot" "$real"; then return 0; fi
        MM_GATE_WHY="is a symlink (-> ${real:-unresolvable})"; return 1
      fi
      subject="$(dirname "$path")" ;;
    link) subject="$(dirname "$path")" ;;
  esac
  real="$(mm_resolve_path "$subject")" || { MM_GATE_WHY="is an unresolvable symlink chain"; return 1; }
  mm_inside "$rroot" "$real" && return 0
  if [ "$kind" = kernel ]; then
    for _d in "$BRAIN/CLAUDE.md" "$BRAIN/AGENTS.md" "$REPO/CLAUDE.md" "$REPO/AGENTS.md"; do
      _r="$(mm_resolve_path "$_d" 2>/dev/null)" || continue
      [ "$real" = "$_r" ] && return 0
    done
  fi
  MM_GATE_WHY="resolves outside $(mm_scope_word) (-> $real)"
  return 1
}

mm_gate() {
  if [ "$1" = brain ]; then mm_assert_no_symlink_path "$PROJECT/.mastermind" "$2"; return 0; fi
  mm_gate_ok "$@" && return 0
  local shown="${2#"$PROJECT"/}"
  if [ "$MODE" = uninstall ]; then
    mm_left "$shown" "it $MM_GATE_WHY"
    return 1
  fi
  case "$MM_GATE_WHY" in
    'is a symlink'*) printf '%s! %s %s.%s Refusing to write through it: remove the link and re-run.\n' "$r" "$shown" "$MM_GATE_WHY" "$x" >&2 ;;
    *) printf '%s! %s %s.%s Refusing to write there.\n' "$r" "$shown" "$MM_GATE_WHY" "$x" >&2 ;;
  esac
  printf '  A repository cannot be allowed to redirect the installer onto paths you did not choose.\n' >&2
  exit 1
}

MM_LEFT_LIST=""
mm_left() {                         # $1 path shown, $2 why: something of ours that stays in place
  warn "left $1 alone: $2"
  UNFINISHED=$((UNFINISHED + 1))
  MM_LEFT_LIST="$MM_LEFT_LIST    $1
"
}

# A surface the installer would write but refused, because it is a symlink or leads outside.
REFUSED=0; MM_REFUSED_LIST=""; MM_REFUSED_KINDS=""
mm_refused() {                      # $1 path shown, $2 message, $3 link (default) or block
  if [ "$MODE" = check ]; then bad "$2"; ISSUES=$((ISSUES + 1)); else warn "$2"; fi
  REFUSED=$((REFUSED + 1))
  MM_REFUSED_LIST="$MM_REFUSED_LIST $1"
  MM_REFUSED_KINDS="$MM_REFUSED_KINDS ${3:-link}"
}

MM_TOUCHED=""
mm_touched() { MM_TOUCHED="$MM_TOUCHED$1
"; }

MM_CREATED=""
mm_note_created() {
  path_exists "$1" && return 0
  case "$1" in "$PROJECT"/*) MM_CREATED="$MM_CREATED${1#"$PROJECT"/}
" ;; esac
  return 0
}

mm_mkdir() {
  local d="$1" p="$1" missing="" rp
  rp="$(cd -P "$PROJECT" 2>/dev/null && pwd -P)" || rp="$PROJECT"
  while [ ! -d "$p" ] && [ "$p" != "$PROJECT" ] && [ "$p" != / ] && [ "$p" != . ]; do
    missing="$p
$missing"; p="$(dirname "$p")"
  done
  mkdir -p "$d"
  # A route's folder arrives resolved, so the project's real path names it too.
  while IFS= read -r p; do
    case "$p" in
      "$PROJECT"/*) MM_CREATED="$MM_CREATED${p#"$PROJECT"/}
" ;;
      "$rp"/*) MM_CREATED="$MM_CREATED${p#"$rp"/}
" ;;
    esac
  done <<EOF
$missing
EOF
}

mm_realpath() {
  local p="$1" n=0 t d b
  while [ -L "$p" ] && [ "$n" -lt 40 ]; do
    t="$(readlink "$p")"
    case "$t" in /*) p="$t" ;; *) p="$(dirname "$p")/$t" ;; esac
    n=$((n + 1))
  done
  [ "$n" -lt 40 ] || return 1                     # a cycle: refuse rather than loop
  d="$(dirname "$p")"; b="$(basename "$p")"
  d="$(cd -P "$d" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s' "${d%/}" "$b"
}

mm_inside() {                                     # $1 base, $2 candidate
  case "$2" in "$1"|"$1"/*) return 0 ;; *) return 1 ;; esac
}

# Paths from config files are untrusted: resolve, then require containment in $PROJECT.
mm_resolve_inside_project() {
  local real proj
  proj="$(cd -P "$PROJECT" 2>/dev/null && pwd -P)" || return 1
  real="$(cd -P "$1" 2>/dev/null && pwd -P)" || return 1
  case "$real" in "$proj"|"$proj"/*) printf '%s' "$real" ;; *) return 1 ;; esac
}

mm_relpath() {                      # $1 target (absolute), $2 directory the link sits in
  local t="$1" s="$2" up=""
  while [ "$s" != "/" ] && [ "${t#"$s"/}" = "$t" ]; do s="$(dirname "$s")"; up="../$up"; done
  printf '%s%s' "$up" "${t#"$s"/}"
}

mm_link_src() {                     # $1 target, $2 link path -> what to store in the symlink
  local src="$1" dst="$2" proj rsrc dir
  proj="$(cd -P "$PROJECT" 2>/dev/null && pwd -P)" || { printf '%s' "$src"; return; }
  dir="$(cd -P "$(dirname "$dst")" 2>/dev/null && pwd -P)" || { printf '%s' "$src"; return; }
  if [ -d "$src" ]; then rsrc="$(cd -P "$src" 2>/dev/null && pwd -P)" || rsrc="$src"
  else rsrc="$(cd -P "$(dirname "$src")" 2>/dev/null && pwd -P)/$(basename "$src")" || rsrc="$src"; fi
  case "$rsrc" in "$proj"/*) ;; *) printf '%s' "$src"; return ;; esac
  case "$dir"  in "$proj"|"$proj"/*) ;; *) printf '%s' "$src"; return ;; esac
  mm_relpath "$rsrc" "$dir"
}

links_to() {
  local dst="$1" want="$2" got
  [ -L "$dst" ] || return 1
  got="$(mm_realpath "$dst")" || return 1
  want="$(mm_realpath "$want")" || return 1
  [ "$got" = "$want" ]
}

mm_has_pointer() {
  local f="$1"
  [ -f "$f" ] || return 1
  grep -qxF "$HINT_GLOBAL" "$f" && return 0
  grep -qxF "$HINT_ISOLATED" "$f" && return 0
  mm_has_import "$f" && return 0
  grep -qE '^[[:space:]]*Follow .*mastermind/CLAUDE\.md' "$f"
}

is_wired() {
  local f="$1"
  is_ours "$f" || mm_has_pointer "$f" || mm_has_kernel_block "$f"
}

MM_GEN_MARK='Generated by ~/.mastermind/install.sh'

mm_is_generated() { [ -f "$1" ] && grep -qF "$MM_GEN_MARK" "$1"; }

mm_backup_aside() {
  local dst="$1" root="${2:-$PROJECT}" bak
  bak="$dst.bak-$(date +%Y%m%d%H%M%S)-$$"
  mm_gate own "$dst.mm-backup" "$root"
  mm_gate link "$dst" "$root"
  mv "$dst" "$bak"; warn "backed up your existing $(basename "$dst") → $bak"
  printf '%s\n' "$bak" > "$dst.mm-backup"
}

mm_preserve_foreign() {
  local dst="$1"
  [ -e "$dst" ] || return 0
  mm_is_generated "$dst" && return 0
  mm_backup_aside "$dst"
}

mm_remove_generated() {
  local dst="$1"
  [ -f "$dst" ] || return 1
  if ! mm_is_generated "$dst"; then
    warn "left $(basename "$dst") alone: it is not the file we generated"
    return 1
  fi
  mm_gate own "$dst" || return 1
  rm -f "$dst"; ok "removed $(basename "$dst")"; mm_touched "$(dirname "$dst")"
  return 0
}

safe_link() {
  local src="$1" dst="$2"
  if [ "$MODE" = check ]; then
    if is_ours "$dst" && [ -e "$dst" ]; then ok "$(basename "$dst")"
    else bad "$(basename "$dst") is not linked to MasterMind"; ISSUES=$((ISSUES + 1)); fi
    return
  fi
  mm_gate link "$dst"
  if [ -e "$dst" ] && ! mm_ours_link "$dst" "$src"; then mm_backup_aside "$dst"; fi
  ln -sfn "$(mm_link_src "$src" "$dst")" "$dst"
}

is_ours() {
  [ -L "$1" ] || return 1
  local rt rrepo rbrain
  if [ ! -e "$1" ]; then mm_link_targets_brain "$1"; return; fi
  rt="$(mm_realpath "$1")" || return 1
  rrepo="$(cd -P "$REPO" 2>/dev/null && pwd -P)" || rrepo="$REPO"
  rbrain="$(cd -P "$BRAIN" 2>/dev/null && pwd -P)" || rbrain="$BRAIN"
  mm_inside "$rrepo" "$rt" && return 0
  mm_inside "$rbrain" "$rt" && return 0
  return 1
}
path_exists() { [ -e "$1" ] || [ -L "$1" ]; }

# Ours under either brain, so switching between a shared and a project brain replaces the link.
mm_ours_link() {
  links_to "$1" "$2" && return 0
  [ "$BRAIN" != "$REPO" ] || return 1
  case "$2" in "$BRAIN"/*) links_to "$1" "$REPO/${2#"$BRAIN"/}" ;; *) return 1 ;; esac
}

mm_is_clash_copy() {
  local p="$1"
  [ -L "$p" ] && return 1
  if [ -d "$p" ]; then [ ! -L "$p/SKILL.md" ] && mm_is_generated "$p/SKILL.md"; return; fi
  mm_is_generated "$p"
}

mm_remove_clash_copy() {
  local p="$1" e
  mm_is_clash_copy "$p" || return 1
  if [ -d "$p" ]; then
    rm -f "$p/SKILL.md"
    for e in "$p"/*; do
      if [ -L "$e" ] && is_ours "$e"; then rm -f "$e"; fi
    done
    rmdir "$p" 2>/dev/null || true
  else
    rm -f "$p"
  fi
  return 0
}

# A second capability under the user's name would load with the same `name:` as theirs, so the
# renamed one is a generated copy whose name matches its own folder or file.
mm_clash_copy() {
  local src="$1" alt="$2" name="$3" kind="$4" gen from inner want e b
  if [ "$kind" = skill ]; then gen="$alt/SKILL.md"; from="$src/SKILL.md"; inner="$name"
  else gen="$alt"; from="$src"; inner="${name%.md}"; fi
  if ! want="$(mm_cursor_alias "$inner" "$from")"; then
    [ "$MODE" = check ] || warn "$kind $name has no name line to rename and you own '$name': MasterMind's skipped"
    SKIPPED=$((SKIPPED + 1)); return 1
  fi
  if [ "$MODE" = check ]; then
    if mm_is_clash_copy "$alt" && [ "$(cat "$gen")" = "$want" ]; then
      ok "mastermind-$name (your own '$name' kept)"; return 0
    fi
    if links_to "$alt" "$src"; then
      bad "mastermind-$name is a link that still loads under the name '$inner', the same as yours: re-run install.sh"
    elif path_exists "$alt" && ! mm_is_clash_copy "$alt"; then
      warn "you own both '$name' and 'mastermind-$name': MasterMind's $kind is not installed"; return 1
    else
      bad "mastermind-$name is not linked to MasterMind (missing or out of date): re-run install.sh"
    fi
    ISSUES=$((ISSUES + 1)); return 1
  fi
  if path_exists "$alt" && ! mm_ours_link "$alt" "$src" && ! mm_is_clash_copy "$alt"; then
    warn "you own both '$name' and 'mastermind-$name': MasterMind's $kind skipped"
    SKIPPED=$((SKIPPED + 1)); return 1
  fi
  mm_gate link "$alt"
  if [ -L "$alt" ]; then rm -f "$alt"; fi
  mm_gate own "$gen"
  if [ "$kind" = skill ]; then
    mkdir -p "$alt"
    for e in "$src"/*; do
      b="$(basename "$e")"
      case "$b" in SKILL.md|ABOUT.md|about) continue ;; esac
      [ -e "$e" ] || continue
      if path_exists "$alt/$b" && ! is_ours "$alt/$b"; then continue; fi
      ln -sfn "$(mm_link_src "$e" "$alt/$b")" "$alt/$b"
    done
  fi
  if ! printf '%s\n' "$want" > "$gen"; then
    bad "could not write $kind mastermind-$name"; ISSUES=$((ISSUES + 1)); LINK_FAILED=$((LINK_FAILED + 1)); return 1
  fi
  warn "you already have a $kind '$name': installed MasterMind's as 'mastermind-$name' (both work)"
  RENAMED=$((RENAMED + 1))
  return 0
}

link_skill() {
  local src="$1" base="$2" name="$3" kind="$4"
  local dst="$base/$name" alt="$base/mastermind-$name"

  # Ownership is "points at exactly this skill", not "points somewhere inside the brain".
  if path_exists "$dst" && ! mm_ours_link "$dst" "$src"; then
    mm_clash_copy "$src" "$alt" "$name" "$kind"; return
  fi

  if [ "$MODE" = check ]; then
    if links_to "$dst" "$src" && [ -e "$dst" ] && [ "$kind" = skill ] && [ ! -f "$dst/SKILL.md" ]; then
      bad "$name: the brain's skills/$name has no SKILL.md, so no tool can load it: re-run install.sh"
      ISSUES=$((ISSUES + 1)); return 1
    fi
    if links_to "$dst" "$src" && [ -e "$dst" ]; then ok "$name"; return 0; fi
    if [ -L "$dst" ]; then
      bad "$name points at $(readlink "$dst"), not $kind $name"
    else
      bad "$name is not linked to MasterMind"
    fi
    ISSUES=$((ISSUES + 1)); return 1
  fi

  if ! ln -sfn "$(mm_link_src "$src" "$dst")" "$dst"; then
    bad "could not link $kind $name into $base"; ISSUES=$((ISSUES + 1)); LINK_FAILED=$((LINK_FAILED + 1)); return 1
  fi
  # Their colliding file is gone, so ours reclaimed the real name: drop the renamed one.
  if links_to "$alt" "$src"; then rm -f "$alt"; else mm_remove_clash_copy "$alt" || true; fi
  return 0
}

MM_IMPORT_RE='^@((\.\./)*|~/)\.mastermind/CLAUDE\.md$'
mm_has_prose_pointer() {
  grep -qxF -e "$HINT_GLOBAL" -e "$HINT_ISOLATED" -e "$HINT_LEGACY_GLOBAL" -e "$HINT_LEGACY_ISOLATED" "$1" 2>/dev/null
}
mm_has_import() { grep -qE "$MM_IMPORT_RE" "$1" 2>/dev/null; }

mm_import_path() {
  local dir rb
  if [ "$ISOLATED" = 1 ]; then
    dir="$(cd -P "$(dirname "$1")" && pwd -P)"; rb="$(cd -P "$BRAIN" && pwd -P)"
    mm_relpath "$rb/CLAUDE.md" "$dir"
  else
    printf '~/.mastermind/CLAUDE.md'
  fi
}

# The line was appended as "\n<line>\n", so a line glued to the text above it means that text had
# no final newline, and it gets none back.
mm_strip_pointers() {              # $1 file, $2 "imports" to take the import lines as well
  local f="$1" tmp final=1; tmp="$(mktemp)"
  [ -z "$(tail -c 1 "$f")" ] || final=0
  MM_P1="$HINT_GLOBAL" MM_P2="$HINT_ISOLATED" MM_P3="$HINT_LEGACY_GLOBAL" MM_P4="$HINT_LEGACY_ISOLATED" \
  MM_IMP="${2:-}" awk -v final="$final" '
    function ours(l) {
      if (l==ENVIRON["MM_P1"] || l==ENVIRON["MM_P2"] || l==ENVIRON["MM_P3"] || l==ENVIRON["MM_P4"]) return 1
      return (ENVIRON["MM_IMP"]=="imports" && l ~ /^@((\.\.\/)*|~\/)\.mastermind\/CLAUDE\.md$/)
    }
    { L[NR] = $0 }
    END {
      n = 0; skip = 0; kept = 0; glued = 0
      for (i = 1; i <= NR; i++) {
        if (ours(L[i])) {
          if (!skip) { if (n > 0 && out[n] == "") { n--; glued = 0 } else glued = (n > 0) }
          skip = 1; kept = 0; continue
        }
        if (skip && L[i] == "") { skip = 0; continue }
        skip = 0; out[++n] = L[i]; kept = 1
      }
      for (k = 1; k < n; k++) printf "%s\n", out[k]
      if (n > 0) printf "%s", out[n]
      if (n > 0 && (kept ? final : !glued)) printf "\n"
    }' "$f" > "$tmp"
  cat "$tmp" > "$f"; rm -f "$tmp"
}

# A user-owned path may be their own link to a regular file: that file is the one to edit.
mm_edit_target() {
  local t
  MM_TARGET="$1"
  [ -L "$1" ] || return 0
  t="$(mm_realpath "$1" 2>/dev/null)" || return 0
  if [ -f "$t" ] && [ ! -L "$t" ]; then MM_TARGET="$t"; fi
  return 0
}

mm_wire_pointer() {                # $1 file to edit, $2 name shown, $3 root
  local f="$1" shown="$2" root="${3:-$PROJECT}" want stale=0 all mine
  mm_gate file "$f" "$root"
  want="@$(mm_import_path "$f")"
  all="$(grep -cE "$MM_IMPORT_RE" "$f" || true)"
  if [ "$(basename "$f")" = CLAUDE.md ] && mm_has_prose_pointer "$f"; then stale=1; fi
  mine="$(grep -cxF -e "$want" "$f" || true)"
  [ "$all" = "$mine" ] || stale=1
  if [ "$mine" = 1 ] && [ "$stale" = 0 ]; then ok "$shown already wired"; return 0; fi
  if [ "$all" != 0 ] || [ "$stale" = 1 ]; then mm_strip_pointers "$f" imports; fi
  printf '\n%s\n' "$want" >> "$f"
  ok "your $shown now imports the MasterMind kernel ($want)"
}

mm_has_kernel_block() { [ -f "$1" ] && grep -qE "^$MM_KSTART"$'\r?$' "$1"; }

mm_block_body() {                   # $1 file, $2 $3 markers: how many whole blocks, then the first one's text
  awk -v S="$2" -v E="$3" '
    { sub(/\r$/, ""); L[NR] = $0 }
    END {
      blocks = 0
      for (i = 1; i <= NR; i++) {
        if (L[i] != S) continue
        e = 0
        for (j = i + 1; j <= NR; j++) { if (L[j] == S) break; if (L[j] == E) { e = j; break } }
        if (!e) continue
        if (!blocks++) { from = i + 2; to = e - 1 }
        i = e
      }
      print blocks
      if (blocks) for (k = from; k <= to; k++) print L[k]
    }' "$1"
}

MM_KNOTE='The MasterMind kernel, inlined by install.sh for tools that read only this file. Edit above or below, never inside'
# A marker pair is ours only when it is the one pair, outside any code fence, and opens with our note.
mm_kernel_markers_raw() {           # none, ours, or why it is not ours, judged by the markers alone
  [ -f "$1" ] || { printf none; return 0; }
  MM_S="$MM_KSTART" MM_E="$MM_KEND" MM_N="<!-- $MM_KNOTE" awk '
    function ournote(t) {
      if (index(t, ENVIRON["MM_N"]) != 1) return 0
      t = substr(t, length(ENVIRON["MM_N"]) + 1)
      sub(/^ sha256=[0-9a-f]+/, "", t)
      return t == " -->" || t == " (eol=none) -->" || t == " (file=empty) -->"
    }
    { sub(/\r$/, ""); L[NR] = $0 }
    END {
      S = ENVIRON["MM_S"]; E = ENVIRON["MM_E"]; fc = ""; fn = 0; fenced = 0; pairs = 0; foreign = 0
      for (i = 1; i <= NR; i++) {
        t = L[i]
        if (match(t, /^ {0,3}(```+|~~~+)/)) {
          run = substr(t, RSTART, RLENGTH); sub(/^ +/, "", run); c = substr(run, 1, 1); rest = substr(t, RSTART + RLENGTH)
          if (fc == "") {
            if (!(c == "`" && index(rest, "`"))) { fc = c; fn = length(run) }
            continue
          }
          if (c == fc && length(run) >= fn && rest ~ /^[ \t]*$/) { fc = ""; continue }
        }
        if ((L[i] == S || L[i] == E) && fc != "") fenced = 1
      }
      for (i = 1; i <= NR; i++) {
        if (L[i] != S) continue
        e = 0
        for (j = i + 1; j <= NR; j++) { if (L[j] == S) break; if (L[j] == E) { e = j; break } }
        if (!e) continue
        pairs++
        if (!ournote(L[i + 1])) foreign = 1
        i = e
      }
      if (fenced) print "a MasterMind marker sits inside a fenced code block"
      else if (pairs > 1) print "it has " pairs " MasterMind kernel blocks, and only one can be ours"
      else if (foreign) print "its MasterMind kernel markers hold text MasterMind did not write"
      else if (fc != "" && ENVIRON["MM_APPEND"] != "") print "it ends inside an open code fence, so a block appended to it would land inside that fence"
      else if (pairs) print "ours"
      else print "none"
    }' "$1"
}

# Blank lines and trailing whitespace are a formatter's, not an edit: they are left out of the hash.
mm_kernel_norm() { awk '{ sub(/[ \t\r]+$/, "") } $0 != ""'; }
mm_kernel_body_hash() { mm_block_body "$1" "$MM_KSTART" "$MM_KEND" | tail -n +2 | mm_kernel_norm | mm_hash_stdin; }
mm_kernel_note_of() {               # $1 file: the line after the start marker of its marker pair
  awk -v S="$MM_KSTART" -v E="$MM_KEND" '
    { sub(/\r$/, ""); L[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        if (L[i] != S) continue
        for (j = i + 1; j <= NR; j++) { if (L[j] == S) break; if (L[j] == E) { print L[i + 1]; exit } }
      }
    }' "$1"
}

# A block is ours only when its body is exactly what we wrote: the hash in its note says what that was.
mm_kernel_markers() {
  local m want
  m="$(mm_kernel_markers_raw "$1")"
  [ "$m" = ours ] || { printf '%s' "$m"; return 0; }
  want="$(mm_kernel_note_of "$1" | sed -n 's/.* sha256=\([0-9a-f]*\).*$/\1/p')"
  if [ -n "$want" ] && [ "$(mm_kernel_body_hash "$1")" = "$want" ]; then printf ours; return 0; fi
  if [ -z "$want" ] && [ "$(mm_block_body "$1" "$MM_KSTART" "$MM_KEND")" = "1
$(cat "$BRAIN/CLAUDE.md" 2>/dev/null)" ]; then printf ours; return 0; fi
  printf 'the text inside its MasterMind kernel block was edited, and MasterMind will not delete an edit of yours'
}

# The note a block is written with: the hash of its body, so a later edit inside it is recognised.
mm_kernel_note() { printf '%s sha256=%s' "$MM_KNOTE" "$(printf '%s\n' "$1" | mm_kernel_norm | mm_hash_stdin)"; }

mm_kernel_block_state() {           # none, current, stale or foreign
  local m
  m="$(mm_kernel_markers "$1")"
  case "$m" in none|ours) : ;; *) printf foreign; return 0 ;; esac
  if [ "$m" = none ]; then printf none; return 0; fi
  # Compared as the hash is: a formatter's blank lines and trailing spaces do not make it stale.
  if [ "$(mm_block_body "$1" "$MM_KSTART" "$MM_KEND" | head -1)" = 1 ] &&
     [ "$(mm_block_body "$1" "$MM_KSTART" "$MM_KEND" | tail -n +2 | mm_kernel_norm)" = \
       "$(mm_kernel_norm < "$BRAIN/CLAUDE.md" 2>/dev/null)" ]; then printf current
  else printf stale; fi
}

mm_kernel_size_note() {             # $1 file, $2 name shown
  local b; b=$(( $(wc -c < "$1") ))
  if [ "$b" -gt "$MM_CODEX_DOC_MAX" ]; then
    warn "$2 is $b bytes with the kernel block: Codex stops reading project instructions at 32 KiB (project_doc_max_bytes), and the block sits last, so shorten your part or raise that limit"
  fi
  return 0
}

# Codex has no import syntax, so a file of the user's own carries the kernel itself.
mm_wire_kernel_block() {            # $1 file to edit, $2 name shown, $3 root
  local f="$1" shown="$2" root="${3:-$PROJECT}" st old=0
  mm_gate file "$f" "$root"
  st="$(mm_kernel_block_state "$f")"
  if [ "$st" = foreign ]; then
    mm_refused "$shown" "left your $shown untouched: $(mm_kernel_markers "$f"). Move your text out of the markers (or close the code fence), then re-run" block
    return 0
  fi
  if [ "$st" != current ] && [ "$(MM_APPEND=1 mm_kernel_markers_raw "$f")" != ours ] && [ "$(MM_APPEND=1 mm_kernel_markers_raw "$f")" != none ]; then
    mm_refused "$shown" "left your $shown untouched: $(MM_APPEND=1 mm_kernel_markers_raw "$f"). Close the code fence, then re-run" block
    return 0
  fi
  local mine=""
  if mm_has_prose_pointer "$f"; then old=1; mm_strip_pointers "$f"; [ -s "$f" ] || mine=1; fi
  if [ "$st" = current ] && [ "$old" = 0 ]; then ok "$shown already carries the kernel"
  else
    [ "$st" = current ] || MM_FILE_WAS_OURS="$mine" mm_write_block "$f" "$(cat "$BRAIN/CLAUDE.md")" "$MM_KSTART" "$MM_KEND" "$(mm_kernel_note "$(cat "$BRAIN/CLAUDE.md")")"
    if [ "$old" = 1 ]; then ok "your $shown now carries the MasterMind kernel in a marked block (the old pointer line is gone)"
    elif [ "$st" = stale ]; then ok "refreshed the MasterMind kernel block in your $shown"
    else ok "your $shown now carries the MasterMind kernel in a marked block, after your own content"; fi
  fi
  mm_kernel_size_note "$f" "$shown"
}

mm_wire_own_file() {                # $1 file to edit, $2 claude|agents, $3 name shown, $4 root
  if [ "$2" = claude ]; then mm_wire_pointer "$1" "$3" "${4:-$PROJECT}"
  else mm_wire_kernel_block "$1" "$3" "${4:-$PROJECT}"; fi
}

mm_check_brain_file() {
  local dst="$1" src="$2" kind="$3" shown t
  shown="$(basename "$dst")"
  if [ ! -e "$src" ]; then
    bad "$shown: the kernel it loads is missing (${src#"$PROJECT"/}): re-run install.sh"
    ISSUES=$((ISSUES + 1)); return
  fi
  if links_to "$dst" "$src"; then ok "$shown"; return; fi
  mm_edit_target "$dst"; t="$MM_TARGET"
  if [ "$kind" = claude ] && mm_has_import "$t"; then ok "$shown (imports the kernel)"
  elif [ "$kind" = claude ] && mm_has_pointer "$t"; then
    bad "$shown has only a prose pointer, which Claude Code does not load as the kernel: re-run install.sh"
    ISSUES=$((ISSUES + 1))
  elif [ "$kind" = claude ]; then bad "$shown not wired to MasterMind"; ISSUES=$((ISSUES + 1))
  else
    case "$(mm_kernel_block_state "$t")" in
      current) ok "$shown (your file, with the kernel in a marked block)"; mm_kernel_size_note "$t" "$shown" ;;
      stale)
        bad "$shown: the MasterMind block is not the current kernel (edited or out of date): re-run install.sh"
        ISSUES=$((ISSUES + 1)) ;;
      foreign)
        bad "$shown: $(mm_kernel_markers "$t"), so the installer will not write it: move your text out of the markers (or close the code fence)"
        ISSUES=$((ISSUES + 1)) ;;
      *)
        if mm_has_pointer "$t"; then bad "$shown has only the old pointer line, so Codex never reads the kernel: re-run install.sh"
        else bad "$shown does not carry the MasterMind kernel block: re-run install.sh"; fi
        ISSUES=$((ISSUES + 1)) ;;
    esac
  fi
}

wire_brain_file() {
  local dst="$1" src="$2" root="${3:-$PROJECT}" kind=agents shown
  shown="$(basename "$dst")"
  [ "$shown" = CLAUDE.md ] && kind=claude
  if [ "$MODE" = check ]; then mm_check_brain_file "$dst" "$src" "$kind"; return; fi
  mm_gate link "$dst" "$root"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && ! mm_ours_link "$dst" "$src"; then
    mm_edit_target "$dst"
    if [ "$MM_TARGET" != "$dst" ] && mm_gate_ok file "$MM_TARGET" "$root"; then
      mm_wire_own_file "$MM_TARGET" "$kind" "$shown (through your link)" "$root"
      return 0
    fi
    # "resolves somewhere inside the brain" is not ownership: ours is the link that points at
    # exactly what we would create. Anything else of theirs is kept aside and handed back.
    mm_backup_aside "$dst" "$root"
  fi
  if [ ! -e "$dst" ] || [ -L "$dst" ]; then
    ln -sfn "$(mm_link_src "$src" "$dst")" "$dst"; ok "$shown linked"
  else
    mm_wire_own_file "$dst" "$kind" "$shown" "$root"
  fi
}

wire_codex_global() {
  local ovr="$CODEX_HOME_DIR/AGENTS.override.md"
  if [ "$MODE" = check ]; then
    if [ -s "$ovr" ]; then warn "$CODEX_HOME_DIR/AGENTS.override.md takes priority: MasterMind's global file is ignored by Codex"; return 0; fi
    if is_ours "$CODEX_GLOBAL" || [ "$(mm_kernel_block_state "$CODEX_GLOBAL")" = current ]; then
      warn "$CODEX_GLOBAL wired (may not reach project chats: openai/codex#27705)"
      is_ours "$CODEX_GLOBAL" || mm_kernel_size_note "$CODEX_GLOBAL" "$CODEX_GLOBAL"
    elif is_wired "$CODEX_GLOBAL"; then
      bad "$CODEX_GLOBAL does not carry the current kernel block: re-run install.sh --global"; ISSUES=$((ISSUES + 1))
    else bad "$CODEX_GLOBAL not wired to MasterMind"; ISSUES=$((ISSUES + 1)); fi
    return 0
  fi
  wire_brain_file "$CODEX_GLOBAL" "$BRAIN/AGENTS.md" "$CODEX_HOME_DIR"
  [ -s "$ovr" ] && warn "you have AGENTS.override.md: Codex reads that instead, so this file won't apply"
  warn "Codex may not merge global instructions into a project that has its own AGENTS.md (openai/codex#27705): run install.sh inside each project for the reliable path"
  return 0
}

# Codex discovers skills only in .agents/skills (repo) and ~/.agents/skills (user); Cursor reads them too.
MM_AGENT_SKILLS_DONE=""
wire_agent_skills() {
  local base="$1" label="$2" s
  [ "$MM_AGENT_SKILLS_DONE" = "$base" ] && return 0
  MM_AGENT_SKILLS_DONE="$base"
  printf '\nAgent skills (%s):\n' "$label"
  if [ "$SCOPE" = project ] && { [ -L "$PROJECT/.agents" ] || [ -L "$base" ]; }; then
    mm_refused "$label" "$label is a symlink: skipped, so nothing is written outside this project. Codex still reads AGENTS.md, but gets no native skills"
    return 0
  fi
  if [ "$MODE" = check ] && [ ! -d "$base" ]; then
    bad "$label not linked yet: re-run install.sh to add native skills for Codex"; ISSUES=$((ISSUES + 1))
    return 0
  fi
  if [ "$MODE" != check ]; then mm_gate dir "$base"; mm_mkdir "$base"; fi
  prune_dead_links "$base"
  LINKED_SKILLS=0; RENAMED=0; SKIPPED=0
  for s in "$BRAIN"/skills/*/; do
    [ -d "$s" ] || continue
    if link_skill "${s%/}" "$base" "$(basename "$s")" skill; then
      [ "$MODE" = check ] || LINKED_SKILLS=$((LINKED_SKILLS + 1))
    fi
  done
  if [ "$MODE" != check ]; then
    ok "$LINKED_SKILLS skills linked"
    if [ "$RENAMED" -gt 0 ]; then warn "$RENAMED name(s) clashed with your own: yours kept, ours added as mastermind-*"; fi
  fi
  return 0
}

mm_cursor_rule_body() {
  printf -- '---\nalwaysApply: true\n---\n'
  printf -- '<!-- %s: do not edit. Refresh with: npx mastermind-brain -->\n\n' "$MM_GEN_MARK"
  cat "$BRAIN/CLAUDE.md"
}

wire_cursor() {
  local dst="$PROJECT/.cursor/rules/mastermind.mdc"
  if [ "$MODE" = check ]; then
    if ! mm_is_generated "$dst" || ! grep -q 'Prime directives' "$dst"; then
      if [ -f "$dst" ]; then bad ".cursor rule is the old pointer-only shape: re-run install.sh"
      else bad ".cursor rule not set"; fi
      ISSUES=$((ISSUES + 1))
    elif [ "$(cat "$dst")" != "$(mm_cursor_rule_body 2>/dev/null)" ]; then
      bad ".cursor/rules/mastermind.mdc is not the current kernel (edited or out of date): re-run install.sh"
      ISSUES=$((ISSUES + 1))
    else ok ".cursor/rules/mastermind.mdc"; fi
    wire_cursor_field
    wire_cursor_aliases
    wire_cursor_agents
    wire_cursor_hook
    return
  fi
  mm_gate own "$dst"
  mm_mkdir "$PROJECT/.cursor/rules"
  mm_preserve_foreign "$dst"
  mm_cursor_rule_body > "$dst"
  ok ".cursor/rules/mastermind.mdc: full kernel inlined"
  wire_cursor_field
  wire_cursor_aliases
  wire_cursor_agents
  wire_cursor_hook
}

# Cursor drops any skill named exactly `build`, so it gets a renamed, generated copy.
MM_CURSOR_RESERVED="build"
mm_cursor_alias() {                 # $1 name, $2 source: the copy, or nothing when it cannot be renamed
  awk -v n="$1" -v mark="<!-- $MM_GEN_MARK: do not edit. Refresh with: npx mastermind-brain -->" '
    { sub(/\r$/, "") }
    /^---$/ { fences++ }
    fences == 1 && !renamed && $0 == "name: " n { print "name: mastermind-" n; renamed = 1; next }
    { print }
    /^---$/ && fences == 2 && !marked { print mark; marked = 1 }
    END { if (!renamed || !marked) exit 1 }
  ' "$2"
}
wire_cursor_aliases() {
  local n src dst dir want
  for n in $MM_CURSOR_RESERVED; do
    src="$BRAIN/skills/$n/SKILL.md"; dir="$PROJECT/.cursor/skills/mastermind-$n"; dst="$dir/SKILL.md"
    [ -f "$src" ] || continue
    if [ -L "$PROJECT/.cursor/skills" ] || [ -L "$dir" ] || [ -L "$dst" ] || ! mm_gate_ok own "$dst"; then
      mm_refused ".cursor/skills/mastermind-$n" ".cursor/skills/mastermind-$n is a symlink: skipped, so nothing is written outside this project"
      continue
    fi
    if { [ -e "$PROJECT/.cursor/skills" ] && [ ! -d "$PROJECT/.cursor/skills" ]; } || { [ -e "$dir" ] && [ ! -d "$dir" ]; }; then
      warn ".cursor/skills/mastermind-$n: a file is where a folder belongs, so the copy was skipped"
      continue
    fi
    if [ -e "$dst" ] && ! mm_is_generated "$dst"; then
      warn "left .cursor/skills/mastermind-$n alone: it is yours, not the file we generated"
      continue
    fi
    if ! want="$(mm_cursor_alias "$n" "$src")"; then
      warn "skills/$n/SKILL.md has no name line to rename, so Cursor gets no copy"
      continue
    fi
    if [ "$MODE" = check ]; then
      if [ ! -f "$dst" ]; then bad ".cursor/skills/mastermind-$n is missing: re-run install.sh"; ISSUES=$((ISSUES + 1))
      elif [ "$(cat "$dst")" != "$want" ]; then bad ".cursor/skills/mastermind-$n is out of date: re-run install.sh"; ISSUES=$((ISSUES + 1))
      else ok ".cursor/skills/mastermind-$n (Cursor reserves the name '$n')"; fi
      continue
    fi
    mm_mkdir "$dir"
    printf '%s\n' "$want" > "$dst"
    ok ".cursor/skills/mastermind-$n: Cursor reserves the name '$n'"
  done
  return 0
}

wire_cursor_field() {
  local dst="$PROJECT/.cursor/rules/mastermind-field.mdc"
  local field pdir
  field="$(mm_field_name)"

  # No field yet (a fresh install ships none) → nothing to inline, and a stale rule must go.
  if [ -z "$field" ] || [ ! -d "$BRAIN/engineering/fields/$field" ]; then
    if [ "$MODE" = check ]; then
      if mm_is_generated "$dst"; then
        bad ".cursor/rules/mastermind-field.mdc is left over from a field that no longer exists: run  $(mm_sync_cmd)"
        ISSUES=$((ISSUES + 1))
      fi
      return 0
    fi
    mm_remove_generated "$dst" >/dev/null || true
    return 0
  fi
  pdir="$BRAIN/engineering/fields/$field"

  if [ "$MODE" = check ]; then
    if [ ! -f "$pdir/stack-defaults.md" ] && [ ! -f "$pdir/lessons.md" ]; then return 0; fi
    if mm_is_generated "$dst" && grep -qF "$field" "$dst"; then
      ok ".cursor/rules/mastermind-field.mdc: $field pack inlined"
    elif [ -f "$dst" ]; then
      bad ".cursor/rules/mastermind-field.mdc does not carry the '$field' pack: run  $(mm_sync_cmd)"
      ISSUES=$((ISSUES + 1))
    else
      bad "field pack '$field' exists but is not delivered to Cursor: run  $(mm_sync_cmd)"
      ISSUES=$((ISSUES + 1))
    fi
    return 0
  fi

  local f had=0
  mm_gate own "$dst"
  { printf -- '---\nalwaysApply: true\n---\n'
    printf -- '<!-- Generated by ~/.mastermind/install.sh: do not edit. Refresh with: npx mastermind-brain -->\n'
    printf -- '\n# Active field pack: %s\n\nThe stack knowledge for this project. Apply it as your default;\n' "$field"
    printf -- 'the rest of the pack (mentors, curriculum, audit rules) is on disk under\n`.mastermind/engineering/fields/%s/` and loads on demand.\n' "$field"
    for f in stack-defaults.md lessons.md; do
      [ -f "$pdir/$f" ] || continue
      printf -- '\n\n---\n\n<!-- %s -->\n\n' "$f"; cat "$pdir/$f"; had=1
    done
  } > "$dst"

  if [ "$had" = 0 ]; then rm -f "$dst"; return 0; fi
  local kb=$(( $(wc -c < "$dst") / 1024 ))
  ok ".cursor/rules/mastermind-field.mdc: $field pack inlined (${kb}KB)"
  [ "$kb" -gt 60 ] && warn "that pack is large for always-on context: prune it with levelup, or Cursor pays it every request"
  return 0
}

# One reader and writer for every hook file, so install, uninstall and --check agree on which
# entries are ours: quoted or not, with or without the shape argument, by suffix or by real path.
MM_HOOKS_JS=""
IFS= read -r -d '' MM_HOOKS_JS <<'JS' || true
const fs = require("fs");
const [tool, op] = process.argv.slice(1);
const E = process.env, file = E.MM_FILE, cmd = E.MM_CMD || "";
const real = (p) => { try { return fs.realpathSync(p); } catch (e) { return ""; } };
const scripts = (E.MM_HOOK_FILES || "").split("\n").filter(Boolean);
const reals = scripts.map(real).filter(Boolean);
const expand = (p) => p.replace(/^~(?=\/)/, E.HOME || "~")
  .replace(/\$\{?CLAUDE_PROJECT_DIR\}?/g, E.MM_PROJECT || "")
  .replace(/\$\{?MASTERMIND_HOME\}?/g, E.MASTERMIND_HOME || "")
  .replace(/\$\{?HOME\}?/g, E.HOME || "");
const paths = (c) => {
  const t = c.trim(), q = /^"([^"]+)"/.exec(t) || /^'([^']+)'/.exec(t);
  if (q) return [q[1]];
  const out = [t.split(/\s+/)[0]], whole = t.replace(/\s+(claude|cursor|codex|sdk)$/, "");
  if (/^(\/|\.\/|~\/|\$)/.test(whole)) out.push(whole);
  return out;
};
const ownsPath = (p) => scripts.includes(p) || /(^|\/)\.mastermind\/hooks\/session-start\.sh$/.test(p) ||
  (/session-start\.sh$/.test(p) && reals.includes(real(expand(p))));
const owns = (c) => typeof c === "string" && ((cmd !== "" && c === cmd) || paths(c).some(ownsPath));
let raw = null;
const read = () => {
  if (!fs.existsSync(file)) return null;
  let s;
  try { raw = fs.readFileSync(file, "utf8"); s = JSON.parse(raw || "{}"); } catch (e) { process.exit(3); }
  if (!s || typeof s !== "object" || Array.isArray(s)) process.exit(3);
  return s;
};
const hooksOf = (s) => (s.hooks && typeof s.hooks === "object" && !Array.isArray(s.hooks) ? s.hooks : {});
const found = [];
const strip = (s) => {
  const h = hooksOf(s);
  for (const ev of Object.keys(h)) {
    if (!Array.isArray(h[ev])) continue;
    const keep = [];
    let hit = false;
    for (const e of h[ev]) {
      if (tool === "cursor") {
        if (owns(e && e.command)) { found.push([ev, e.command]); hit = true; continue; }
      } else if (e && Array.isArray(e.hooks)) {
        const mine = e.hooks.filter((x) => owns(x && x.command));
        if (mine.length) {
          hit = true;
          for (const x of mine) found.push([ev, x.command, e.matcher]);
          const rest = e.hooks.filter((x) => !owns(x && x.command));
          if (rest.length) keep.push(Object.assign({}, e, { hooks: rest }));
          continue;
        }
      }
      keep.push(e);
    }
    if (keep.length || !hit) h[ev] = keep; else delete h[ev];
  }
};
// The user's own layout is kept as far as JSON allows: their indent, one line, a final newline.
const save = (s) => {
  if (raw === null || raw.trim() === "") return fs.writeFileSync(file, JSON.stringify(s, null, 2) + "\n");
  const eol = /\n$/.test(raw) ? "\n" : "";
  if (!raw.trim().includes("\n")) return fs.writeFileSync(file, JSON.stringify(s) + eol);
  const m = /\n([ \t]+)\S/.exec(raw);
  fs.writeFileSync(file, JSON.stringify(s, null, m ? m[1] : 2) + eol);
};
const CODEX_SOURCES = ["startup", "resume", "clear", "compact", "fork"];
const fires = (m, src) => {
  if (m === undefined || m === "" || m === "*") return true;
  try { return new RegExp(m).test(src); } catch (e) { return false; }
};
const addOurs = (s, c) => {
  if (tool === "cursor") s.version ??= 1;
  if (!s.hooks || typeof s.hooks !== "object" || Array.isArray(s.hooks)) s.hooks = {};
  strip(s);
  if (tool === "cursor") (s.hooks.sessionStart ||= []).push({ command: c });
  else if (tool === "codex") (s.hooks.SessionStart ||= []).push({ matcher: CODEX_SOURCES.join("|"), hooks: [{ type: "command", command: c, timeout: 30 }] });
  else (s.hooks.SessionStart ||= []).push({ matcher: "startup|clear|compact", hooks: [{ type: "command", command: c, async: false }] });
};
const dropOurs = (s) => {
  strip(s);
  if (tool !== "cursor" && s.hooks && !Object.keys(s.hooks).length) delete s.hooks;
};
if (op === "install") {
  const s = read() || {};
  addOurs(s, cmd);
  save(s);
} else if (op === "uninstall") {
  const s = read();
  if (!s) process.exit(1);
  strip(s);
  if (!found.length) process.exit(1);
  if (tool !== "cursor" && s.hooks && !Object.keys(s.hooks).length) delete s.hooks;
  const keys = Object.keys(s);
  const empty = tool === "cursor"
    ? keys.every((k) => k === "version" || k === "hooks") && !Object.keys(hooksOf(s)).length
    : keys.length === 0;
  save(s);
  console.log(empty ? "empty" : "kept");
} else if (op === "same") {
  // Unedited means: the original, put through our install and then our uninstall, is what is there now.
  const s = read();
  let o;
  try { o = JSON.parse(fs.readFileSync(E.MM_ORIG, "utf8") || "{}"); } catch (e) { process.exit(1); }
  if (!s || !o || typeof o !== "object" || Array.isArray(o)) process.exit(1);
  dropOurs(s);
  addOurs(o, '".mastermind/hooks/session-start.sh" ' + tool);
  dropOurs(o);
  process.exit(JSON.stringify(s) === JSON.stringify(o) ? 0 : 1);
} else if (op === "sole") {
  const s = read();
  if (!s) process.exit(1);
  strip(s);
  if (hooksOf(s) === s.hooks && !Object.keys(s.hooks).length) delete s.hooks;
  process.exit(found.length && Object.keys(s).every((k) => tool === "cursor" && k === "version") ? 0 : 1);
} else {
  const s = read();
  if (!s) { console.log("nofile"); process.exit(op === "has" ? 1 : 0); }
  strip(s);
  if (op === "has") process.exit(found.length ? 0 : 1);
  const start = tool === "cursor" ? "sessionStart" : "SessionStart";
  const at = found.filter((f) => f[0] === start);
  if (!found.length) console.log("missing");
  else if (!at.length) console.log("wrongevent " + found[0][0]);
  else if (tool !== "cursor" && !at.some((f) => new RegExp("\\s" + tool + "\\s*$").test(f[1]))) console.log("noshape");
  else if (tool === "codex" && !CODEX_SOURCES.every((src) => at.some((f) => fires(f[2], src)))) console.log("nosource");
  else if (tool === "claude" && !["startup", "clear", "compact"].every((src) => at.some((f) => fires(f[2], src)))) console.log("nosource");
  else console.log("ok");
  if (tool === "cursor" && found.some((f) => f[0] === "preCompact")) console.log("precompact");
}
JS

mm_hooks_js() {                     # $1 claude|cursor|codex, $2 install|uninstall|check|has|sole, $3 file, $4 command
  MM_FILE="$3" MM_CMD="${4:-}" MM_PROJECT="$PROJECT" MM_HOOK_FILES="$BRAIN/hooks/session-start.sh
$REPO/hooks/session-start.sh
$HOME/.mastermind/hooks/session-start.sh
${MASTERMIND_HOME:+$MASTERMIND_HOME/hooks/session-start.sh}
${MM_RECORDED_BRAIN:+$MM_RECORDED_BRAIN/hooks/session-start.sh}" node -e "$MM_HOOKS_JS" "$1" "$2" 2>/dev/null
}

# The bytes of a user's hook file from before our first edit, so uninstall can hand back exactly those.
mm_original_of() {                  # $1 file -> where its original is kept
  if [ "$SCOPE" = global ]; then
    case "$1" in "$HOME"/*) printf '%s/originals/%s' "$MM_STATE" "${1#"$HOME"/}" ;;
      *) printf '%s/originals/_/%s' "$MM_STATE" "$(printf '%s' "$1" | mm_hash_stdin | cut -c1-16)" ;; esac
  else printf '%s/.mastermind/.originals/%s' "$PROJECT" "${1#"$PROJECT"/}"; fi
}

mm_keep_original() {                # $1 claude|cursor|codex, $2 file
  local o
  [ -f "$2" ] && [ ! -L "$2" ] || return 0
  o="$(mm_original_of "$2")"
  path_exists "$o" && return 0
  mm_hooks_js "$1" has "$2" >/dev/null && return 0
  if [ "$SCOPE" = global ]; then mm_gate own "$o" "$MM_STATE"
  else mm_gate brain ".originals/${2#"$PROJECT"/}"; fi
  mkdir -p "$(dirname "$o")"
  cp -p "$2" "$o"
}

mm_restore_original() {             # $1 claude|cursor|codex, $2 file, $3 name shown, $4 quiet
  local o
  o="$(mm_original_of "$2")"
  [ -f "$o" ] && [ ! -L "$o" ] || return 0
  if [ -f "$2" ] && MM_ORIG="$o" mm_hooks_js "$1" same "$2"; then
    if ! cmp -s "$o" "$2"; then cat "$o" > "$2"; ok "restored your $3 byte for byte"; fi
  elif [ -f "$2" ] && [ -z "${4:-}" ]; then
    warn "your $3 changed since the install: only our entry was removed, the rest is kept in your layout as far as JSON allows"
  fi
  rm -f "$o"
  local d; d="$(dirname "$o")"
  while [ "$(basename "$d")" != .originals ] && [ "$(basename "$d")" != originals ] && rmdir "$d" 2>/dev/null; do d="$(dirname "$d")"; done
  rmdir "$d" 2>/dev/null || true
  return 0
}

# With no saved original, a file git tracks has its committed bytes as the original.
mm_restore_committed() {            # $1 claude|cursor|codex, $2 file, $3 name shown
  local rel="${2#"$PROJECT"/}" tmp rc=1
  [ "$rel" != "$2" ] && command -v git >/dev/null 2>&1 || return 1
  git -C "$PROJECT" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1 || return 1
  tmp="$(mktemp)"
  if git -C "$PROJECT" show "HEAD:./$rel" > "$tmp" 2>/dev/null && ! mm_hooks_js "$1" has "$tmp" >/dev/null &&
     MM_ORIG="$tmp" mm_hooks_js "$1" same "$2"; then
    if ! cmp -s "$tmp" "$2"; then cat "$tmp" > "$2"; ok "restored your $3 as it is committed"; fi
    rc=0
  fi
  rm -f "$tmp"
  return "$rc"
}

mm_check_hook() {                   # $1 claude|cursor|codex, $2 file, $3 name shown
  local tool="$1" f="$2" shown="$3" hookfile="$BRAIN/hooks/session-start.sh" st first
  if ! command -v node >/dev/null 2>&1; then
    bad "$shown cannot be verified: node not found"; ISSUES=$((ISSUES + 1)); return 0
  fi
  st="$(mm_hooks_js "$tool" check "$f")" || st=unparseable
  first="${st%%$'\n'*}"
  case "$first" in
    ok)
      if [ -x "$hookfile" ]; then
        case "$tool" in
          cursor) ok "$shown (unverified upstream)" ;;
          codex)  ok "$shown: SessionStart (runs once Codex trusts the project and you approve it with /hooks)" ;;
          *)      ok "bootstrap hook" ;;
        esac
      else
        bad "$shown runs ${hookfile#"$PROJECT"/}, which is missing or not executable: re-run install.sh"
        ISSUES=$((ISSUES + 1))
      fi ;;
    noshape)
      if [ "$tool" = codex ]; then bad "$shown registers our hook without the codex shape, so it answers for another tool: re-run install.sh"
      else bad "bootstrap hook registered without the claude shape: Claude Code ignores its output (re-run the installer)"; fi
      ISSUES=$((ISSUES + 1)) ;;
    nosource)
      if [ "$tool" = claude ]; then bad "$shown: our hook's matcher no longer covers startup, clear and compact: re-run install.sh"
      else bad "$shown: our hook's matcher no longer covers startup, resume, clear, compact and fork: re-run install.sh"; fi
      ISSUES=$((ISSUES + 1)) ;;
    wrongevent*)
      bad "$shown registers our hook under ${first#wrongevent }, which does not run at session start: re-run install.sh"
      ISSUES=$((ISSUES + 1)) ;;
    unparseable)
      bad "$shown is not valid JSON, so the session hook cannot be read"; ISSUES=$((ISSUES + 1)) ;;
    nofile)
      bad "$shown is missing, so no MasterMind hook runs at session start: re-run install.sh"
      ISSUES=$((ISSUES + 1)) ;;
    *)
      case "$tool" in
        cursor) bad "$shown has no MasterMind sessionStart entry: re-run install.sh" ;;
        codex)  bad "$shown has no MasterMind SessionStart entry: re-run install.sh" ;;
        *)      bad "bootstrap hook not registered (no MasterMind framing or init nudge at session start)" ;;
      esac
      ISSUES=$((ISSUES + 1)) ;;
  esac
  case "$st" in *precompact*)
    bad "$shown still has our preCompact entry, which cannot reload anything: re-run install.sh"
    ISSUES=$((ISSUES + 1)) ;;
  esac
  return 0
}

wire_cursor_hook() {
  local dst="$PROJECT/.cursor/hooks.json" _hookcmd
  if [ "$MODE" = check ]; then mm_check_hook cursor "$dst" .cursor/hooks.json; return 0; fi
  command -v node >/dev/null 2>&1 || return 0
  mm_gate file "$dst"
  mm_mkdir "$PROJECT/.cursor"
  mm_note_created "$dst"
  mm_keep_original cursor "$dst"
  if [ "$ISOLATED" = 1 ]; then _hookcmd='"./.mastermind/hooks/session-start.sh" cursor'
  else _hookcmd="\"$BRAIN/hooks/session-start.sh\" cursor"; fi
  if mm_hooks_js cursor install "$dst" "$_hookcmd"; then ok ".cursor/hooks.json: sessionStart (unverified upstream)"
  else warn "left your .cursor/hooks.json alone (could not parse it)"; fi
  return 0
}

# hooks.json beside the active config layer: <repo>/.codex/ for a project, ~/.codex/ for the user.
MM_CODEX_HOOK_DONE=""; MM_CODEX_HOOK_NOTE=0
wire_codex_hook() {
  local dir="$PROJECT/.codex" root="$PROJECT" shown=.codex/hooks.json dst cmd top
  if [ "$SCOPE" = global ]; then dir="$CODEX_HOME_DIR"; root="$CODEX_HOME_DIR"; shown="$CODEX_HOME_DIR/hooks.json"; fi
  dst="$dir/hooks.json"
  [ "$MM_CODEX_HOOK_DONE" = "$dst" ] && return 0
  MM_CODEX_HOOK_DONE="$dst"
  if [ "$MODE" = check ]; then mm_check_hook codex "$dst" "$shown"; return 0; fi
  if ! command -v node >/dev/null 2>&1; then
    warn "node not found: skipped the Codex session hook (AGENTS.md still carries the kernel)"
    return 0
  fi
  mm_gate dir "$dir" "$root"; mm_gate file "$dst" "$root"
  mm_mkdir "$dir"
  mm_note_created "$dst"
  mm_keep_original codex "$dst"
  # Codex starts a hook in the session's directory, which can be below the project root.
  if [ "$ISOLATED" = 1 ]; then
    top="$(git -C "$PROJECT" rev-parse --show-toplevel 2>/dev/null)" || top=""
    if [ -n "$top" ] && [ "$top" -ef "$PROJECT" ]; then cmd='"$(git rev-parse --show-toplevel)/.mastermind/hooks/session-start.sh" codex'
    else cmd='"./.mastermind/hooks/session-start.sh" codex'; fi
  else cmd="\"$BRAIN/hooks/session-start.sh\" codex"; fi
  if mm_hooks_js codex install "$dst" "$cmd"; then
    ok "$shown: SessionStart, so the framing comes back after a compaction"
    MM_CODEX_HOOK_NOTE=1
  else warn "left your $shown alone (could not parse it): Codex session hook not registered"; fi
  return 0
}

MM_CURSOR_READONLY="code-reviewer tech-scout"
mm_cursor_agent() {                 # $1 source: Cursor's frontmatter fields only, the marker, the body
  local ro=0
  case " $MM_CURSOR_READONLY " in *" $(basename "$1" .md) "*) ro=1 ;; esac
  awk -v ro="$ro" -v mark="<!-- $MM_GEN_MARK: do not edit. Refresh with: npx mastermind-brain -->" '
    { sub(/\r$/, "") }
    /^---$/ && fences < 2 {
      fences++
      if (fences == 2) { print "model: inherit"; if (ro == 1) print "readonly: true"; print; print mark } else print
      next
    }
    fences == 1 {
      if ($0 ~ /^name:/) { print; named = 1; keep = 1 }
      else if ($0 ~ /^description:/) { print; described = 1; keep = 1 }
      else if ($0 ~ /^[ \t]/ && keep) print
      else keep = 0
      next
    }
    { print }
    END { if (fences < 2 || !named || !described) exit 1 }
  ' "$1"
}

wire_cursor_agents() {
  local dir="$PROJECT/.cursor/agents" a n dst want made=0
  for a in "$BRAIN"/agents/*.md; do
    [ -f "$a" ] || continue
    n="$(basename "$a")"; dst="$dir/$n"
    if [ -L "$dst" ]; then
      mm_refused ".cursor/agents/$n" ".cursor/agents/$n is a symlink: left alone, so nothing is written through it"
      continue
    fi
    if [ -e "$dst" ] && ! mm_is_generated "$dst"; then
      warn "left .cursor/agents/$n alone: it is yours, so Cursor uses your '${n%.md}' and not MasterMind's"
      continue
    fi
    if ! want="$(mm_cursor_agent "$a")"; then
      warn "agents/$n has no name and description to copy, so Cursor gets no subagent from it"
      continue
    fi
    if [ "$MODE" = check ]; then
      if [ ! -f "$dst" ]; then bad ".cursor/agents/$n is missing: re-run install.sh"; ISSUES=$((ISSUES + 1))
      elif [ "$(cat "$dst")" != "$want" ]; then bad ".cursor/agents/$n is out of date: re-run install.sh"; ISSUES=$((ISSUES + 1))
      else ok ".cursor/agents/$n"; fi
      continue
    fi
    mm_gate dir "$dir"; mm_gate own "$dst"
    mm_mkdir "$dir"
    printf '%s\n' "$want" > "$dst"
    made=$((made + 1))
  done
  [ "$MODE" = check ] || [ "$made" = 0 ] || ok ".cursor/agents: $made subagents (code-reviewer and tech-scout are read-only)"
  return 0
}

# A real marker pair, ours or not: a lone marker, or one shown inside a code fence, is the user's text.
mm_root_block_pair() {
  case "$(mm_kernel_markers_raw "$1")" in ours|*"kernel blocks"*|*"did not write"*) return 0 ;; *) return 1 ;; esac
}

# AGENTS.md -> CLAUDE.md: the kernel block written through that link already loads in Claude Code
# from the root CLAUDE.md, so a second copy through .claude/CLAUDE.md would load it twice.
mm_kernel_in_root_claude() {
  local t c
  [ "$SCOPE" = project ] && [ -n "$AGENTS_FILE" ] && [ -L "$AGENTS_FILE" ] || return 1
  [ ${#TOOLS[@]} -eq 0 ] || mm_wants agents || mm_wants codex || mm_root_block_pair "$PROJECT/CLAUDE.md" || return 1
  [ -f "$PROJECT/CLAUDE.md" ] && [ ! -L "$PROJECT/CLAUDE.md" ] || return 1
  t="$(mm_realpath "$AGENTS_FILE" 2>/dev/null)" || return 1
  c="$(mm_realpath "$PROJECT/CLAUDE.md" 2>/dev/null)" || return 1
  [ "$t" = "$c" ]
}

wire_claude_through_root() {        # $1 .claude/CLAUDE.md
  local f="$1"
  if [ "$MODE" = check ]; then
    if [ "$(mm_kernel_block_state "$PROJECT/CLAUDE.md")" = current ]; then ok "CLAUDE.md (the kernel block in your root CLAUDE.md, through your AGENTS.md link)"
    elif [ "$(mm_kernel_block_state "$PROJECT/CLAUDE.md")" = foreign ]; then
      bad "CLAUDE.md: your root CLAUDE.md: $(mm_kernel_markers "$PROJECT/CLAUDE.md"). Move your text out of the markers, then re-run install.sh"; ISSUES=$((ISSUES + 1))
    else bad "CLAUDE.md: your root CLAUDE.md, which AGENTS.md links to, does not carry the current kernel block: re-run install.sh"; ISSUES=$((ISSUES + 1)); fi
    if links_to "$f" "$BRAIN/CLAUDE.md" || mm_has_import "$f"; then
      bad ".claude/CLAUDE.md also loads the kernel, so Claude Code reads it twice: re-run install.sh"; ISSUES=$((ISSUES + 1))
    fi
    return 0
  fi
  if links_to "$f" "$BRAIN/CLAUDE.md"; then mm_gate link "$f"; rm -f "$f"
  elif [ -f "$f" ] && [ ! -L "$f" ] && mm_has_import "$f"; then mm_gate file "$f"; mm_strip_pointers "$f" imports; fi
  # The root block is refreshed here too, so naming only claude never leaves it stale or loads it twice.
  if mm_wants agents || mm_wants codex; then
    ok "CLAUDE.md: the kernel goes in your root CLAUDE.md (AGENTS.md links to it), so Claude Code loads it once"
  else
    mm_wire_kernel_block "$PROJECT/CLAUDE.md" "CLAUDE.md (the root file AGENTS.md links to)"
  fi
}

wire_claude() {
  local base="$1"
  if [ "$MODE" != check ]; then
    mm_gate dir "$base/agents"; mm_gate dir "$base/skills"
    mm_mkdir "$base/agents"; mm_mkdir "$base/skills"
  fi
  printf '\nClaude Code:\n'
  if mm_kernel_in_root_claude; then wire_claude_through_root "$base/CLAUDE.md"
  else wire_brain_file "$base/CLAUDE.md" "$BRAIN/CLAUDE.md"; fi
  # Global links engineering into ~/.claude; per-project reads it via ~/.mastermind.
  [ "$SCOPE" = global ] && safe_link "$REPO/engineering" "$base/engineering"
  prune_dead_links "$base/skills"; prune_dead_links "$base/agents"
  LINKED_SKILLS=0; LINKED_AGENTS=0; RENAMED=0; SKIPPED=0
  local a s
  for a in "$BRAIN"/agents/*.md; do
    [ -e "$a" ] || continue
    if link_skill "$a" "$base/agents" "$(basename "$a")" agent; then
      [ "$MODE" = check ] || LINKED_AGENTS=$((LINKED_AGENTS + 1))
    fi
  done
  for s in "$BRAIN"/skills/*/; do
    [ -d "$s" ] || continue
    if link_skill "${s%/}" "$base/skills" "$(basename "$s")" skill; then
      [ "$MODE" = check ] || LINKED_SKILLS=$((LINKED_SKILLS + 1))
    fi
  done
  if [ "$MODE" != check ]; then
    ok "$LINKED_SKILLS skills, $LINKED_AGENTS agents linked · $PRUNED stale removed"
    if [ "$RENAMED" -gt 0 ]; then
      warn "$RENAMED name(s) clashed with your own: yours kept, ours added as mastermind-*"
    fi
  fi
  wire_bootstrap "$base"
}

wire_bootstrap() {
  local base="$1"
  local settings="$base/settings.json" hook="$BRAIN/hooks/session-start.sh"
  [ "$ISOLATED" = 1 ] && hook='$CLAUDE_PROJECT_DIR/.mastermind/hooks/session-start.sh'

  if [ "$MODE" = check ]; then mm_check_hook claude "$settings" settings.json; return 0; fi

  if ! command -v node >/dev/null 2>&1; then
    warn "node not found: skipped the bootstrap hook (no MasterMind framing at session start)"
    return 0
  fi
  mm_gate file "$settings"
  mm_note_created "$settings"
  mm_keep_original claude "$settings"
  # The shape argument is load-bearing: without it the hook cannot tell Claude Code from the
  # SDK and emits a field Claude Code ignores.
  if mm_hooks_js claude install "$settings" "\"$hook\" claude"; then
    ok "bootstrap hook: MasterMind framing on startup + compaction"
  else
    warn "left your settings.json alone (could not parse it): bootstrap hook not registered"
  fi
  return 0
}

# The target may be gone, so its `..` steps are folded as text from the link's real directory.
mm_fold_link() {
  local t d="" rest seg
  t="$(readlink "$1")" || return 1
  rest="${t#/}"
  case "$t" in /*) : ;; *) d="$(cd -P "$(dirname "$1")" 2>/dev/null && pwd -P)" || return 1 ;; esac
  while [ -n "$rest" ]; do
    seg="${rest%%/*}"
    if [ "$seg" = "$rest" ]; then rest=""; else rest="${rest#*/}"; fi
    case "$seg" in ''|.) : ;; ..) d="${d%/*}" ;; *) d="$d/$seg" ;; esac
  done
  printf '%s' "$d"
}

# Every brain a link of ours can point at: this one, the clone, the project's own copy, and the
# brain the install record names (a shared clone that has since moved or been deleted).
MM_RECORDED_BRAIN=""
# The brain a record names widens what uninstall treats as ours, so it is believed only when the
# record could not have been planted: one in the home state directory with an intact digest, or a
# record inside the project that names that project's own brain.
mm_trusted_brain() {                # $1 record file -> the brain it names, or nothing
  local b body want
  b="$(sed -n 's/^brain=//p' "$1" | head -1)"
  [ -n "$b" ] || return 0
  case "$1" in
    "$MM_STATE"/*)
      want="$(sed -n 's/^digest=//p' "$1" | head -1)"
      body="$(mktemp)"; grep -v '^digest=' "$1" > "$body" || true
      if [ -n "$want" ] && [ "$(mm_hash "$body")" = "$want" ]; then printf '%s' "$b"; fi
      rm -f "$body" ;;
    *)
      if [ "$(mm_resolve_path "$b" 2>/dev/null)" = "$(mm_resolve_path "$PROJECT/.mastermind" 2>/dev/null)" ]; then printf '%s' "$b"; fi ;;
  esac
  return 0
}
mm_our_bases() {
  local b
  for b in "$REPO" "$BRAIN" ${PROJECT:+"$PROJECT/.mastermind"} ${MM_RECORDED_BRAIN:+"$MM_RECORDED_BRAIN"}; do
    printf '%s\n' "$b"
    mm_resolve_path "$b" 2>/dev/null && printf '\n'
  done
}

mm_link_targets_brain() {
  local d base
  d="$(mm_fold_link "$1")" || return 1
  while IFS= read -r base; do
    if [ -n "$base" ] && mm_inside "$base" "$d"; then return 0; fi
  done <<EOF
$(mm_our_bases)
EOF
  return 1
}

mm_dangles_to() {                   # $1 link, $2 path under a brain: a dead link that pointed there
  local d base rel="$2"
  [ -L "$1" ] && [ ! -e "$1" ] || return 1
  d="$(mm_fold_link "$1")" || return 1
  case "$rel" in "$BRAIN"/*) rel="${rel#"$BRAIN"/}" ;; "$REPO"/*) rel="${rel#"$REPO"/}" ;; esac
  while IFS= read -r base; do
    if [ -n "$base" ] && [ "$d" = "$base/$rel" ]; then return 0; fi
  done <<EOF
$(mm_our_bases)
EOF
  return 1
}

prune_dead_links() {
  local dir="$1"; [ -d "$dir" ] || return 0
  shopt -s nullglob
  local l
  for l in "$dir"/*; do
    if [ -L "$l" ] && [ ! -e "$l" ] && mm_link_targets_brain "$l"; then
      if [ "$MODE" = check ]; then bad "stale link $(basename "$l") → $(readlink "$l")"; ISSUES=$((ISSUES + 1))
      else mm_gate link "$l"; rm -f "$l"; PRUNED=$((PRUNED + 1)); fi
    fi
  done
  shopt -u nullglob
}

remove_link() {                     # $1 link, $2 what ours points at (empty: anywhere in the brain), $3 root
  local f="$1"
  if [ -n "${2:-}" ]; then mm_ours_link "$f" "$2" || mm_dangles_to "$f" "$2" || return 1; else is_ours "$f" || return 1; fi
  mm_gate link "$f" "${3:-$PROJECT}" || return 1
  rm -f "$f"; ok "removed $(basename "$f")"; mm_touched "$(dirname "$f")"
  return 0
}

# Resolving inside the brain is not ownership: a project's own build -> team-build does too.
mm_is_our_capability() {
  local p="$1" name kind rbrain rrepo got
  [ -L "$p" ] || return 1
  # The parent folder decides: a project under a directory named `agents` matched */agents/* first.
  kind="$(basename "$(dirname "$p")")"
  case "$kind" in agents|skills) : ;; *) return 1 ;; esac
  name="$(basename "$p")"; name="${name#mastermind-}"
  if [ ! -e "$p" ]; then mm_dangles_to "$p" "$kind/$name"; return; fi
  rbrain="$(cd -P "$BRAIN" 2>/dev/null && pwd -P)" || return 1
  rrepo="$(cd -P "$REPO" 2>/dev/null && pwd -P)" || rrepo="$rbrain"
  got="$(mm_realpath "$p")" || return 1
  [ "$got" = "$rbrain/$kind/$name" ] || [ "$got" = "$rrepo/$kind/$name" ]
}

mm_remove_capabilities() {          # $1 directory, $2 prefix for the name shown
  local dir="$1" label="$2" l gated=""
  path_exists "$dir" || return 0
  if ! mm_gate_ok dir "$dir"; then
    mm_left "${dir#"$PROJECT"/}" "it $MM_GATE_WHY, so whatever of ours is inside it stays"
    return 0
  fi
  [ -d "$dir" ] || return 0
  mm_touched "$dir"
  shopt -s nullglob
  for l in "$dir"/*; do
    if ! mm_is_our_capability "$l"; then
      case "$(basename "$l")" in mastermind-*) mm_is_clash_copy "$l" || continue ;; *) continue ;; esac
    fi
    if [ -z "$gated" ]; then
      if mm_gate link "$l"; then gated=yes; else gated=no; fi
    fi
    [ "$gated" = yes ] || break
    if [ -L "$l" ]; then rm -f "$l"; else mm_remove_clash_copy "$l" || continue; fi
    ok "removed $label$(basename "$l")"; n=$((n + 1))
  done
  shopt -u nullglob
  return 0
}

restore_backup() {
  local f="$1" root="${2:-$PROJECT}" bak=""
  path_exists "$f" && return 0
  [ -f "$f.mm-backup" ] && [ ! -L "$f.mm-backup" ] || return 0
  mm_gate link "$f" "$root" || return 0
  bak="$(head -1 "$f.mm-backup")"
  rm -f "$f.mm-backup"
  [ -n "$bak" ] && { [ -e "$bak" ] || [ -L "$bak" ]; } || return 0
  case "$bak" in
    "$(dirname "$f")/$(basename "$f").bak-"*) : ;;
    *) warn "ignored an unrecognized backup pointer for $(basename "$f")"; return 0 ;;
  esac
  mv "$bak" "$f" && ok "restored your original $(basename "$f") (from $(basename "$bak"))"
}

# Tell the user if their clone is behind origin. Network-optional: any failure is silent.
check_updates() {
  command -v git >/dev/null 2>&1 || return 0
  [ -f "$REPO/.manifest" ] && return 0              # a project's copy: its git repo is the project's
  git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  [ -n "${MM_NO_NETWORK:-}" ] && return 0
  GIT_HTTP_LOW_SPEED_LIMIT=1000 GIT_HTTP_LOW_SPEED_TIME=8 GIT_TERMINAL_PROMPT=0 \
    git -C "$REPO" fetch --quiet 2>/dev/null || return 0
  local here up base
  here="$(git -C "$REPO" rev-parse @ 2>/dev/null)"        || return 0
  up="$(git -C "$REPO" rev-parse '@{u}' 2>/dev/null)"     || return 0
  base="$(git -C "$REPO" merge-base @ '@{u}' 2>/dev/null)" || return 0
  if [ "$here" != "$up" ] && [ "$here" = "$base" ]; then
    printf '%s⬆ An update is available.%s  cd ~/.mastermind && git pull && ~/.mastermind/install.sh\n' "$y" "$x"
  fi
}

# What is left is the file as it was before the block: the separator we added goes with it, and a
# last line that had no newline gets none back.
mm_strip_block() {                  # $1 file, $2 keep|exact|"" for a file left empty, $3 $4 markers
  local file="$1" S="${3:-$MM_START}" E="${4:-$MM_END}" tmp final=1
  [ -f "$file" ] || return 0
  grep -qE "^$S"$'\r?$' "$file" || return 1
  [ -z "$(tail -c 1 "$file")" ] || final=0
  MM_WAS_EMPTY=0; grep -qF '(file=empty) -->' "$file" && MM_WAS_EMPTY=1
  tmp="$(mktemp)"
  awk -v S="$S" -v E="$E" -v final="$final" '
    function bare(t) { sub(/\r$/, "", t); return t }
    { L[NR] = $0 }
    END {
      n = 0; atend = 0; noeol = 0
      for (i = 1; i <= NR; i++) {
        e = 0
        if (bare(L[i]) == S)
          for (j = i + 1; j <= NR; j++) {
            if (bare(L[j]) == S) break
            if (bare(L[j]) == E) { e = j; break }
          }
        if (!e) { out[++n] = L[i]; atend = 0; continue }
        if (n > 0 && bare(out[n]) == "") n--
        atend = (e == NR); noeol = (L[i + 1] ~ /\(eol=none\) -->\r?$/)
        i = e
      }
      for (k = 1; k < n; k++) printf "%s\n", out[k]
      if (n > 0) printf "%s", out[n]
      if (n > 0 && (atend ? !noeol : final)) printf "\n"
    }' "$file" > "$tmp"
  # Written in place: a replaced file would take the temp file's 0600 instead of the user's mode.
  if [ "${2:-}" = exact ] || grep -q '[^[:space:]]' "$tmp"; then cat "$tmp" > "$file"
  elif [ "${2:-}" = keep ] || [ "$MM_WAS_EMPTY" = 1 ]; then : > "$file"
  else rm -f "$file"; fi
  rm -f "$tmp"
  return 0
}

mm_strip_anchor_file() {
  local f="$1" t
  mm_edit_target "$f"; t="$MM_TARGET"
  [ -f "$t" ] && [ ! -L "$t" ] || return 1
  grep -qxF "$MM_START" "$t" || return 1
  mm_gate file "$t" || return 1
  if [ "$t" = "$f" ]; then mm_strip_block "$t"; else mm_strip_block "$t" keep; fi
}

mm_strip_anchor_dir() {
  local adir="$1" abs
  case "$adir" in ''|'*'|'.'|'**') return 0 ;; esac
  case "$adir" in /*|*\\*) return 0 ;; esac
  case "/$adir/" in */../*) return 0 ;; esac
  [ -d "$PROJECT/$adir" ] || return 0
  abs="$(mm_resolve_inside_project "$PROJECT/$adir")" || return 0
  if mm_remove_route_surface claude; then mm_strip_anchor_file "$abs/CLAUDE.md" && n=$((n + 1)) || true; fi
  if [ "$MM_REMOVE_ALL_ROUTE_SURFACES" = 1 ] || mm_remove_agents_wiring; then mm_strip_anchor_file "$abs/AGENTS.md" || true; fi
  if mm_remove_route_surface cursor; then mm_remove_generated "$abs/.cursor/rules/mastermind.mdc" >/dev/null && n=$((n + 1)) || true; fi
  return 0
}

remove_context_anchors() {
  local map="$BRAIN/routes.map" led glob line adir
  led="$(mm_routes_ledger)"
  if [ -f "$led" ]; then
    while IFS= read -r adir; do mm_strip_anchor_dir "$adir"; done < "$led"
    if [ ${#TOOLS[@]} -eq 0 ] && mm_gate own "$led" "$BRAIN"; then rm -f "$led"; fi
  fi
  [ -f "$map" ] || return 0
  while IFS= read -r line; do
    line="${line//$'\r'/}"
    case "$line" in \#*) continue ;; esac
    line="${line%%[[:space:]]#*}"; line="$(printf '%s' "$line" | awk '{$1=$1};1')"
    [ -n "$line" ] || continue
    glob="${line% *}"
    adir="${glob%/\*\*}"; adir="${adir%/\*}"; adir="${adir%/}"
    mm_strip_anchor_dir "$adir"
  done < "$map"
}

mm_wants() {
  [ ${#TOOLS[@]} -eq 0 ] && return 0
  local t
  for t in ${TOOLS[@]+"${TOOLS[@]}"}; do [ "$t" = "$1" ] && return 0; done
  return 1
}

MM_REMAINING_TOOLS=""
MM_REMOVE_ALL_ROUTE_SURFACES=0
if [ "$MODE" = uninstall ]; then
  if [ ${#TOOLS[@]} -eq 0 ]; then
    MM_REMOVE_ALL_ROUTE_SURFACES=1
  else
    _before_record="$(mm_record_file)"
    if [ -f "$_before_record" ]; then
      MM_REMAINING_TOOLS="$(sed -n 's/^tools=//p' "$_before_record")"
      for _selected in ${TOOLS[@]+"${TOOLS[@]}"}; do
        MM_REMAINING_TOOLS="$(printf '%s' "$MM_REMAINING_TOOLS" | tr ' ' '\n' | awk -v selected="$_selected" '$0 != selected' | tr '\n' ' ')"
      done
      MM_REMAINING_TOOLS="$(printf '%s' "$MM_REMAINING_TOOLS" | sed 's/  */ /g; s/^ //; s/ $//')"
      [ -z "$MM_REMAINING_TOOLS" ] && MM_REMOVE_ALL_ROUTE_SURFACES=1
    fi
  fi
fi

mm_remove_route_surface() {
  [ "$MM_REMOVE_ALL_ROUTE_SURFACES" = 1 ] || mm_wants "$1"
}

mm_remove_agents_wiring() {
  [ ${#TOOLS[@]} -eq 0 ] && return 0
  { mm_wants agents || mm_wants codex; } || return 1
  case " $MM_REMAINING_TOOLS " in *' agents '*|*' codex '*) return 1 ;; esac
  return 0
}

MM_EMPTIED=""
mm_unwire_json() {                  # $1 claude|cursor|codex, $2 file, $3 name shown, $4 what stays wired, $5 root
  local tool="$1" f="$2" shown="$3" what="$4" out rc=0
  if [ ! -f "$f" ]; then mm_restore_original "$tool" "$f" "$shown" quiet; return 0; fi
  if ! command -v node >/dev/null 2>&1; then
    warn "node is not installed, so $shown was left as it is: $what"
    UNFINISHED=$((UNFINISHED + 1)); return 0
  fi
  mm_hooks_js "$tool" has "$f" >/dev/null || rc=$?
  case "$rc" in
    0) : ;;
    1) mm_restore_original "$tool" "$f" "$shown" quiet; return 0 ;;
    *) warn "could not edit $shown (unreadable JSON): $what"; UNFINISHED=$((UNFINISHED + 1)); return 0 ;;
  esac
  mm_gate file "$f" "${5:-$PROJECT}" || return 0
  if ! out="$(mm_hooks_js "$tool" uninstall "$f")"; then
    warn "could not edit $shown: $what"; UNFINISHED=$((UNFINISHED + 1)); return 0
  fi
  ok "unwired our hook from $shown"; n=$((n + 1))
  if [ -f "$(mm_original_of "$f")" ]; then mm_restore_original "$tool" "$f" "$shown"; return 0; fi
  mm_restore_committed "$tool" "$f" "$shown" && return 0
  if [ "$out" = empty ]; then MM_EMPTIED="$MM_EMPTIED${f#"$PROJECT"/}
"; fi
  return 0
}

mm_unwire_pointer() {               # $1 file, $2 root
  local f="$1" root="${2:-$PROJECT}" t imp="" alone=0 first
  mm_edit_target "$f"; t="$MM_TARGET"
  [ -f "$t" ] && [ ! -L "$t" ] || return 0
  # Import lines are written only into CLAUDE.md files; in any other file they are the user's.
  [ "$(basename "$f")" = CLAUDE.md ] && imp=imports
  mm_has_prose_pointer "$t" || { [ -n "$imp" ] && mm_has_import "$t"; } || return 0
  mm_gate file "$t" "$root" || return 0
  # We append "\n<line>", so a file whose first line is ours is one we wrote, not one of theirs.
  first="$(head -1 "$t")"
  grep -qxE "$MM_IMPORT_RE" <<<"$first" && alone=1
  grep -qxF -e "$HINT_GLOBAL" -e "$HINT_ISOLATED" -e "$HINT_LEGACY_GLOBAL" -e "$HINT_LEGACY_ISOLATED" <<<"$first" && alone=1
  mm_strip_pointers "$t" $imp
  if [ "$t" != "$f" ] || [ "$alone" = 0 ] || grep -q '[^[:space:]]' "$t"; then
    ok "removed the MasterMind pointer from $(basename "$f")"
  else
    rm -f "$t"; ok "removed $(basename "$f") (it held only our pointer)"
  fi
  n=$((n + 1))
  return 0
}

mm_unwire_kernel_block() {          # $1 file, $2 root
  local f="$1" root="${2:-$PROJECT}" t
  mm_edit_target "$f"; t="$MM_TARGET"
  [ -f "$t" ] && [ ! -L "$t" ] || return 0
  [ "$(mm_kernel_markers "$t")" = none ] && return 0
  if [ "$(mm_kernel_markers "$t")" != ours ]; then
    # A start marker with our note, or outside any fence, means our kernel may still be in there.
    if grep -qF "<!-- $MM_KNOTE" "$t" || ! case "$(mm_kernel_markers "$t")" in *'fenced code block'*) true ;; *) false ;; esac; then mm_left "$(basename "$f")" "$(mm_kernel_markers "$t"), so no block in it is provably ours: take the MasterMind block out by hand"
    else warn "left $(basename "$f") untouched: $(mm_kernel_markers "$t"), so no block in it is provably ours"; fi
    return 0
  fi
  mm_gate file "$t" "$root" || return 0
  mm_strip_block "$t" exact "$MM_KSTART" "$MM_KEND" || return 0
  if [ "$t" = "$f" ] && [ ! -s "$t" ] && [ "$MM_WAS_EMPTY" = 0 ]; then rm -f "$t"; ok "removed $(basename "$f") (it held only our block)"
  else ok "removed the MasterMind kernel block from $(basename "$f")"; fi
  n=$((n + 1))
  return 0
}

# Only what the record says this installer created: an emptied settings file, an empty folder.
MM_CREATED_LEFT=""
mm_remove_created() {
  local recf="$1" list p abs
  MM_CREATED_LEFT=""
  [ -f "$recf" ] || return 0
  list="$(sed -n 's/^created=//p' "$recf" | sort -ru)"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in /*|*..*) continue ;; esac
    abs="$PROJECT/$p"
    if [ -d "$abs" ] && [ ! -L "$abs" ]; then
      if mm_gate_ok dir "$abs"; then rmdir "$abs" 2>/dev/null || true; fi
    elif [ -f "$abs" ] && [ ! -L "$abs" ]; then
      case "$MM_EMPTIED" in *"$p
"*) if mm_gate_ok own "$abs"; then rm -f "$abs"; ok "removed $p (it held only our hook)"; fi ;; esac
    fi
    if path_exists "$abs"; then MM_CREATED_LEFT="$MM_CREATED_LEFT$p
"; fi
  done <<EOF
$list
EOF
  return 0
}

# With no install record, a hook file we emptied is ours unless git shows it once held the user's own.
mm_user_made() {                    # $1 claude|cursor|codex, $2 path relative to the project
  local first tmp rc=0
  command -v git >/dev/null 2>&1 || return 1
  git -C "$PROJECT" ls-files --error-unmatch -- "$2" >/dev/null 2>&1 || return 1
  first="$(git -C "$PROJECT" log --diff-filter=A --format=%H -- "$2" 2>/dev/null | tail -1)"
  [ -n "$first" ] || return 0
  tmp="$(mktemp)"
  if git -C "$PROJECT" show "$first:./$2" > "$tmp" 2>/dev/null && mm_hooks_js "$1" sole "$tmp"; then rc=1; fi
  rm -f "$tmp"
  return "$rc"
}

mm_remove_unrecorded() {
  local p abs tool d
  while IFS= read -r p; do
    case "$p" in .claude/settings.json) tool=claude ;; .cursor/hooks.json) tool=cursor ;; .codex/hooks.json) tool=codex ;; *) continue ;; esac
    abs="$PROJECT/$p"
    [ -f "$abs" ] && [ ! -L "$abs" ] || continue
    if mm_user_made "$tool" "$p"; then warn "kept $p: git history shows it once held settings of your own"; continue; fi
    mm_gate_ok own "$abs" || continue
    rm -f "$abs"; ok "removed $p (it held only our hook)"; mm_touched "$(dirname "$abs")"
  done <<EOF
$MM_EMPTIED
EOF
  for d in .claude/skills .claude/agents .cursor/rules .cursor/skills .cursor/agents .agents/skills .claude .cursor .codex .agents; do
    case "$MM_TOUCHED" in *"$PROJECT/$d"*) : ;; *) continue ;; esac
    [ -d "$PROJECT/$d" ] && [ ! -L "$PROJECT/$d" ] && mm_gate_ok dir "$PROJECT/$d" || continue
    rmdir "$PROJECT/$d" 2>/dev/null || true
  done
  return 0
}

if [ "$MODE" = uninstall ]; then
  printf 'Removing MasterMind from %s%s%s…\n' "$g" "$([ "$SCOPE" = global ] && echo "global (~/.claude)" || echo "this project")" "$x"
  n=0
  _recf="$(mm_record_file)"
  if [ -f "$_recf" ]; then MM_RECORDED_BRAIN="$(mm_trusted_brain "$_recf")"; fi
  if mm_wants claude; then
    remove_link "$CLAUDE_DIR/CLAUDE.md" "$BRAIN/CLAUDE.md"     && n=$((n + 1))
    remove_link "$CLAUDE_DIR/engineering" "$REPO/engineering" && n=$((n + 1))
    mm_remove_capabilities "$CLAUDE_DIR/skills" ""
    mm_remove_capabilities "$CLAUDE_DIR/agents" ""
  fi
  # AGENTS.md is what Codex reads, so either name owns it.
  if mm_remove_agents_wiring; then
    [ -n "$AGENTS_FILE" ] && { remove_link "$AGENTS_FILE" "$BRAIN/AGENTS.md" && n=$((n + 1)); }
    _askills=""
    if [ "$SCOPE" = project ]; then _askills="$PROJECT/.agents/skills"
    elif mm_wants codex; then _askills="$HOME/.agents/skills"; fi
    if [ -n "$_askills" ]; then
      mm_remove_capabilities "$_askills" ".agents/skills/"
      if mm_gate_ok dir "$_askills"; then
        rmdir "$_askills" 2>/dev/null || true
        if [ "$SCOPE" = project ]; then rmdir "$PROJECT/.agents" 2>/dev/null || true; fi
      fi
    fi
    unset _askills
  fi
  mm_wants claude && restore_backup "$CLAUDE_DIR/CLAUDE.md"
  # AGENTS.md had no restore path at all, so a preserved original stayed preserved forever.
  if mm_remove_agents_wiring; then [ -n "${AGENTS_FILE:-}" ] && restore_backup "$AGENTS_FILE"; fi
  [ "$SCOPE" = global ] && mm_wants codex && [ -n "${CODEX_GLOBAL:-}" ] && restore_backup "$CODEX_GLOBAL" "$CODEX_HOME_DIR"
  [ "$SCOPE" = global ] && mm_wants claude && restore_backup "$CLAUDE_DIR/engineering"
  # Codex's global file is ours only when it's our symlink; remove_link leaves a real file alone.
  [ "$SCOPE" = global ] && mm_wants codex && { remove_link "$CODEX_GLOBAL" "$BRAIN/AGENTS.md" "$CODEX_HOME_DIR" && n=$((n + 1)); }
  if [ "$SCOPE" = project ]; then
    remove_context_anchors    # keeps each app's own CLAUDE.md content
    if mm_wants cursor; then
      mm_remove_generated "$PROJECT/.cursor/rules/mastermind.mdc"       && n=$((n + 1))
      mm_remove_generated "$PROJECT/.cursor/rules/mastermind-field.mdc" && n=$((n + 1))
      for _alias in $MM_CURSOR_RESERVED; do
        _ad="$PROJECT/.cursor/skills/mastermind-$_alias"
        mm_remove_generated "$_ad/SKILL.md" && n=$((n + 1))
        if mm_gate_ok dir "$_ad"; then rmdir "$_ad" "$PROJECT/.cursor/skills" 2>/dev/null || true; fi
      done
      unset _alias _ad
      restore_backup "$PROJECT/.cursor/rules/mastermind.mdc"
      restore_backup "$PROJECT/.cursor/rules/mastermind-field.mdc"
    fi
    if mm_wants gemini || [ "$MM_REMOVE_ALL_ROUTE_SURFACES" = 1 ]; then remove_link "$PROJECT/GEMINI.md" && n=$((n + 1)); fi
    if mm_wants copilot || [ "$MM_REMOVE_ALL_ROUTE_SURFACES" = 1 ]; then remove_link "$PROJECT/.github/copilot-instructions.md" && n=$((n + 1)); fi
    # Removed on filename alone until now, which destroyed any same-named file the user owned.
    _gh="$PROJECT/.github/hooks/mastermind.json"
    if { mm_wants copilot || [ "$MM_REMOVE_ALL_ROUTE_SURFACES" = 1 ]; } && [ -f "$_gh" ]; then
      if mm_is_generated "$_gh" || grep -qF 'hooks/session-start.sh' "$_gh" 2>/dev/null ||
         [ "$(tr -d '[:space:]' < "$_gh")" = '{}' ]; then
        if mm_gate own "$_gh"; then rm -f "$_gh"; ok "removed .github/hooks/mastermind.json"; n=$((n + 1)); fi
      else
        warn "left .github/hooks/mastermind.json alone: it is not ours"
      fi
    fi
    unset _gh
    # Cursor's hooks.json is shared: filter our entries out rather than deleting the file.
    if mm_wants cursor; then
      mm_unwire_json cursor "$PROJECT/.cursor/hooks.json" .cursor/hooks.json "our hook is still wired there"
    fi
    if mm_remove_agents_wiring; then
      mm_unwire_json codex "$PROJECT/.codex/hooks.json" .codex/hooks.json "our hook is still wired there"
    fi
  elif mm_wants codex; then
    mm_unwire_json codex "$CODEX_HOME_DIR/hooks.json" "$CODEX_HOME_DIR/hooks.json" "our hook is still wired there" "$CODEX_HOME_DIR"
  fi
  if mm_wants cursor; then
    for _ca in "$PROJECT"/.cursor/agents/*.md; do
      if [ ! -L "$_ca" ] && mm_is_generated "$_ca"; then mm_remove_generated "$_ca" && n=$((n + 1)); fi
    done
    unset _ca
  fi
  if mm_wants claude; then
    mm_unwire_json claude "$CLAUDE_DIR/settings.json" settings.json "the bootstrap hook is still registered"
  fi
  if mm_remove_agents_wiring && [ -n "${AGENTS_FILE:-}" ]; then
    mm_unwire_pointer "$AGENTS_FILE"; mm_unwire_kernel_block "$AGENTS_FILE"
  fi
  if mm_wants claude; then mm_unwire_pointer "$CLAUDE_DIR/CLAUDE.md"; fi
  if mm_wants gemini || [ "$MM_REMOVE_ALL_ROUTE_SURFACES" = 1 ]; then mm_unwire_pointer "$PROJECT/GEMINI.md"; fi
  if mm_wants copilot || [ "$MM_REMOVE_ALL_ROUTE_SURFACES" = 1 ]; then mm_unwire_pointer "$PROJECT/.github/copilot-instructions.md"; fi
  if [ "$SCOPE" = global ] && mm_wants codex && [ -n "${CODEX_GLOBAL:-}" ]; then
    mm_unwire_pointer "$CODEX_GLOBAL" "$CODEX_HOME_DIR"; mm_unwire_kernel_block "$CODEX_GLOBAL" "$CODEX_HOME_DIR"
  fi

  mm_remove_created "$_recf"
  [ -f "$_recf" ] || mm_remove_unrecorded
  if [ -f "$_recf" ] && [ ${#TOOLS[@]} -eq 0 ]; then
    rm -f "$_recf"
  elif [ -f "$_recf" ]; then
    _keep="$(sed -n 's/^tools=//p' "$_recf")"
    for _g in ${TOOLS[@]+"${TOOLS[@]}"}; do
      _keep="$(printf '%s' "$_keep" | tr ' ' '\n' | awk -v selected="$_g" '$0 != selected' | tr '\n' ' ')"
    done
    _keep="$(printf '%s' "$_keep" | sed 's/  */ /g; s/^ //; s/ $//')"
    if [ -n "$_keep" ]; then
      _tf="$(mktemp)"
      { sed "s|^tools=.*|tools=$_keep|" "$_recf" | grep -v -e '^digest=' -e '^created=' || true
        printf '%s' "$MM_CREATED_LEFT" | sed 's/^/created=/'
      } > "$_tf"
      cat "$_tf" > "$_recf"
      printf 'digest=%s\n' "$(mm_hash "$_tf")" >> "$_recf"
      rm -f "$_tf"
    else
      rm -f "$_recf"
    fi
  fi
  case "$_recf" in "$MM_STATE"/*) rmdir "$MM_STATE/projects" "$MM_STATE" 2>/dev/null || true ;; esac
  if [ "${UNFINISHED:-0}" -gt 0 ]; then
    printf '\n%s⚠ removed %d link(s), but %d thing(s) could not be undone (listed above).%s\n' "$y" "$n" "$UNFINISHED" "$x"
    [ -z "$MM_LEFT_LIST" ] || printf '  Still in place:\n%s' "$MM_LEFT_LIST"
    printf '  Fix those, then re-run:  %s --uninstall\n' "$0"
    exit 1
  fi
  printf '\n%s✓ removed %d link(s).%s Your own files were left untouched.\n' "$g" "$n" "$x"
  if [ "$SCOPE" = project ] && [ ${#TOOLS[@]} -eq 0 ] && [ -d "$PROJECT/.mastermind" ] && [ ! -L "$PROJECT/.mastermind" ]; then
    printf '  This project still has .mastermind/ (its lessons, field pack and preferences are yours).\n'
    printf '  To remove that too:  rm -rf "%s/.mastermind"\n' "$PROJECT"
  fi
  printf '  (~/.mastermind stays; delete the clone to remove the brain.)\n'
  exit 0
fi

if [ "$MODE" = install ] && [ "$SHARED" = 1 ] && [ -f "$PROJECT/.mastermind/VERSION" ] && [ ! -L "$PROJECT/.mastermind" ]; then
  printf '%s✖ this project has its own brain at .mastermind/, so --shared cannot take effect.%s\n' "$r" "$x" >&2
  printf '  It holds this project'"'"'s contexts and lessons, so it is not mine to delete.\n' >&2
  printf '  To switch to the shared clone:\n' >&2
  printf '    %s --uninstall\n' "$0" >&2
  printf '    rm -rf %s/.mastermind      # after saving anything you want from it\n' "$PROJECT" >&2
  printf '    %s --shared\n' "$0" >&2
  exit 2
fi

mm_count_skills() {
  local n=0 f
  for f in "$1"/skills/*/SKILL.md; do
    if [ -f "$f" ]; then n=$((n + 1)); fi
  done
  printf '%s' "$n"
}

if [ "$MODE" = install ] && [ "$(mm_count_skills "$REPO")" = 0 ]; then
  printf '%s✖ this brain has no skills (%s/skills holds none).%s Nothing was changed.\n' "$r" "$REPO" "$x" >&2
  printf '  The clone is incomplete: fetch it again, then re-run.\n' >&2
  exit 1
fi

if [ "$MODE" = install ]; then
  mm_link="$HOME/.mastermind"
  mm_link_real=""
  [ -e "$mm_link" ] && mm_link_real="$(cd "$mm_link" 2>/dev/null && pwd -P || true)"

  # A live brain that is not this one is never taken over, directory or symlink. The symlink case
  # used to fall through to the ln below and be redirected in silence, which pointed someone's
  # global brain at a throwaway clone; they found out when the clone was deleted.
  if [ "$mm_link_real" = "$REPO" ]; then
    :
  elif [ -n "$mm_link_real" ]; then
    printf '%s✖ %s is a different brain%s (%s).\n' "$r" "$mm_link" "$x" "$mm_link_real" >&2
    if [ -L "$mm_link" ]; then
      printf '  Refusing to redirect it silently. Repoint it on purpose:  ln -sfn %s %s\n' "$REPO" "$mm_link" >&2
    else
      printf '  Remove or move it first, then re-run: refusing to write inside someone else'"'"'s clone.\n' >&2
    fi
    exit 1
  else
    mm_gate link "$mm_link" "$HOME"
    ln -sfn "$REPO" "$mm_link"
  fi
fi

# --- Per-project sanity: need a real project dir, not the clone or ~ ----------
if [ "$SCOPE" = project ] && [ "$MODE" = install ] && { [ "$PROJECT" -ef "$REPO" ] || [ "$PROJECT" -ef "$HOME" ]; }; then
  printf 'MasterMind brain → ~/.mastermind  %s✓ ready%s\n\n' "$g" "$x"
  printf 'Now add it to a project:\n'
  printf '  cd your-project && ~/.mastermind/install.sh      (just that project: recommended)\n'
  printf '  ~/.mastermind/install.sh --global                (Claude Code, every project)\n'
  exit 0
fi

if [ "$SCOPE" = project ] && [ -n "${PROJECT:-}" ]; then
  for _t in .claude .claude/skills .claude/agents .cursor .cursor/rules .cursor/agents .codex .mastermind .github/hooks; do
    mm_gate dir "$PROJECT/$_t"
  done
  for _t in AGENTS.md CLAUDE.md .claude/CLAUDE.md; do mm_gate kernel "$PROJECT/$_t"; done
  for _t in .claude/settings.json .cursor/hooks.json .codex/hooks.json; do mm_gate file "$PROJECT/$_t"; done
  for _t in .cursor/rules/mastermind.mdc .cursor/rules/mastermind-field.mdc .github/hooks/mastermind.json \
            .mastermind/VERSION .mastermind/.manifest .mastermind/.installed; do
    mm_gate own "$PROJECT/$_t"
  done
  if [ "$MODE" = install ] && [ "$ISOLATED" = 0 ]; then
    for _t in prefs brief; do
      [ -e "$PROJECT/.mastermind/$_t.md" ] || mm_gate own "$PROJECT/.mastermind/$_t.md"
    done
  fi
  unset _t
fi

# cli/bin and cli/package.json, not all of cli: the README there is the npm listing, and it has no
# job inside someone's repo. Dropping a path here prunes it from existing installs on upgrade.
ISO_ENGINE=(CLAUDE.md AGENTS.md install.sh engineering/core engineering/_context_template skills agents hooks bin cli/bin cli/package.json
            scripts/build-router.mjs scripts/check-integrity.mjs)
ISO_OWNED=(engineering/active-field.md engineering/ROUTER.md prefs.md brief.md)
ISO_STATE=(VERSION routes.map .manifest .manifest.hashes .installed .routes.generated .originals
           engineering engineering/contexts engineering/fields)

mm_preserve_engine_directory() {
  local path="$1" rel="$2" keep
  [ -d "$path" ] && [ ! -L "$path" ] || return 0
  keep="$path.yours-$(date +%Y%m%d%H%M%S)-$$"
  mv "$path" "$keep"
  warn "this release needs a file at $rel, where your project had a directory: yours is kept at $(basename "$keep")"
}

mm_preserve_untracked_engine_file() {
  local path="$1" rel="$2" hashes="$3" keep
  [ -f "$path" ] || return 0
  if [ -f "$hashes" ] && awk -v rel="$rel" '$2 == rel { found=1 } END { exit !found }' "$hashes" 2>/dev/null; then return 0; fi
  keep="$path.yours-$(date +%Y%m%d%H%M%S)-$$"
  cp -p "$path" "$keep"
  warn "this release adds $rel, which your project already had: yours is kept at $(basename "$keep")"
}

sync_isolated_brain() {
  local dst="$PROJECT/.mastermind" d
  local SHIPPED; SHIPPED="$(mktemp)"
  local HASHES="$dst/.manifest.hashes" NEWHASH; NEWHASH="$(mktemp)"
  if [ -L "$dst" ]; then
    printf '%s✖ .mastermind is a symlink (→ %s).%s Refusing to write through it: remove it first.\n' \
      "$r" "$(readlink "$dst")" "$x" >&2; exit 1
  fi
  if path_exists "$dst" && [ ! -d "$dst" ]; then
    printf '%s✖ .mastermind exists and is not a directory.%s Move it aside first.\n' "$r" "$x" >&2; exit 1
  fi
  mkdir -p "$dst"

  # Every path this installer writes under the brain, not only the shipped engine files. A
  # dangling symlink at routes.map or .manifest.hashes made the write land outside the project
  # and still exit 0. Anything added below has to be listed here too.
  for d in "${ISO_ENGINE[@]}" "${ISO_OWNED[@]}" "${ISO_STATE[@]}" engineering/fields/_template; do
    mm_gate brain "$d"
  done

  local ef erel
  for d in "${ISO_ENGINE[@]}"; do
    [ -e "$REPO/$d" ] || continue
    if [ -d "$REPO/$d" ] && [ ! -L "$REPO/$d" ]; then
      while IFS= read -r erel; do
        erel="${erel#./}"; ef="$REPO/$d/$erel"
        mm_gate brain "$d/$erel"
        mm_preserve_engine_directory "$dst/$d/$erel" "$d/$erel"
        # A project file where an engine file lands has no trustworthy ownership unless its hash
        # is in our ledger. This includes both a newly added upstream path and the very first install
        # into a pre-existing .mastermind tree.
        mm_preserve_untracked_engine_file "$dst/$d/$erel" "$d/$erel" "$HASHES"
        mkdir -p "$(dirname "$dst/$d/$erel")"
        if [ -f "$dst/$d/$erel" ] && [ -f "$HASHES" ]; then
          # `|| true`: under set -e a grep that matches nothing fails the assignment and kills
          # the installer mid-refresh. A path with no recorded hash is normal, not an error.
          _was="$(awk -v rel="$d/$erel" '$2 == rel { print $1; exit }' "$HASHES" 2>/dev/null || true)"
          if [ -n "$_was" ]; then
            _now="$(mm_hash "$dst/$d/$erel")"
            [ "$_now" = "$_was" ] || warn "replacing your edit to $d/$erel (engine file; copy it out if you need it)"
          fi
        fi
        rm -rf "$dst/$d/${erel:?}.mm-new"
        cp -Rp "$ef" "$dst/$d/$erel.mm-new"
        mv -f "$dst/$d/$erel.mm-new" "$dst/$d/$erel"
        printf '%s\n' "$d/$erel" >> "$SHIPPED"
      done < <(cd "$REPO/$d" && find . \( -type f -o -type l \) ! -name ABOUT.md ! -path '*/about/*')
    else
      mkdir -p "$(dirname "$dst/$d")"
      mm_preserve_engine_directory "$dst/$d" "$d"
      mm_preserve_untracked_engine_file "$dst/$d" "$d" "$HASHES"
      rm -f "$dst/${d:?}"
      cp -Rp "$REPO/$d" "$dst/$d"
      printf '%s\n' "$d" >> "$SHIPPED"
    fi
  done

  if ! grep -q '^skills/[^/]*/SKILL\.md$' "$SHIPPED"; then
    printf '%s✖ no skill was copied from %s.%s Stopped before pruning the brain in .mastermind/.\n' "$r" "$REPO" "$x" >&2
    exit 1
  fi

  local tsrc="$REPO/engineering/fields/_template"
  if [ -d "$tsrc" ] && [ ! -d "$dst/engineering/fields/_template" ]; then
    mkdir -p "$dst/engineering/fields/_template"
    local tf trel
    while IFS= read -r tf; do
      trel="${tf#"$tsrc"/}"
      mm_gate brain "engineering/fields/_template/$trel"
      mkdir -p "$(dirname "$dst/engineering/fields/_template/$trel")"
      cp -p "$tf" "$dst/engineering/fields/_template/$trel"
    done < <(find "$tsrc" -type f)
  fi

  local seed
  for d in "${ISO_OWNED[@]}"; do
    [ -e "$dst/$d" ] && continue
    mkdir -p "$(dirname "$dst/$d")"
    seed="$REPO/${d%.md}.seed.md"
    if [ -f "$seed" ]; then cp -p "$seed" "$dst/$d"; else cp -Rp "$REPO/$d" "$dst/$d"; fi
  done

  local file
  while IFS= read -r file; do
    case "$file" in *.md) ;; *) continue ;; esac
    [ -f "$dst/$file" ] && [ ! -L "$dst/$file" ] || continue
    grep -qI '~/\.mastermind' "$dst/$file" 2>/dev/null || continue
    _lz="$(mktemp)"
    sed 's|~/\.mastermind|.mastermind|g' "$dst/$file" > "$_lz" && cat "$_lz" > "$dst/$file"
    rm -f "$_lz"
  done < "$SHIPPED"

  local manifest="$dst/.manifest" newman; newman="$(mktemp)"
  sort -u "$SHIPPED" > "$newman"
  : > "$NEWHASH"
  while IFS= read -r _mf; do
    [ -n "$_mf" ] && [ -f "$dst/$_mf" ] && printf '%s  %s\n' "$(mm_hash "$dst/$_mf")" "$_mf" >> "$NEWHASH"
  done < "$newman"
  sort -u "$NEWHASH" > "$HASHES"; rm -f "$NEWHASH"

  if [ -f "$manifest" ]; then
    local gone gdir
    while IFS= read -r gone; do
      [ -n "$gone" ] || continue
      case "$(basename "$gone")" in lessons.md|stack-defaults.md|active-field.md|prefs.md|ROUTER.md|journal.md) continue ;; esac
      case "$gone" in engineering/fields/*) continue ;; esac
      case "$gone" in /*|*..*|*\\*) warn "manifest: refusing to act on '$gone'"; continue ;; esac
      if [ -e "$dst/$gone" ] && ! grep -qxF "$gone" "$newman"; then
        mm_gate brain "$gone"
        rm -f "$dst/$gone"
        # Only the folders a retired file leaves empty: an empty folder of the user's stays.
        gdir="$(dirname "$gone")"
        while [ "$gdir" != . ] && [ "$gdir" != / ] && rmdir "$dst/$gdir" 2>/dev/null; do gdir="$(dirname "$gdir")"; done
      fi
    done < "$manifest"
  fi

  # The manifest records the state we just installed, minus the project's own files.
  cp "$newman" "$manifest"
  rm -f "$newman" "$SHIPPED"

  printf '%s\n' "$(cat "$REPO/VERSION")" > "$dst/VERSION"

  # The copy's paths are rewritten, so its hashes differ from the clone's: index what is here.
  if command -v node >/dev/null 2>&1 && [ -f "$dst/scripts/build-router.mjs" ]; then
    node "$dst/scripts/build-router.mjs" >/dev/null 2>&1 ||
      warn ".mastermind/engineering/ROUTER.md could not be regenerated: run  node .mastermind/scripts/build-router.mjs"
  fi
}


mm_rel_prefix() {
  local dir="$1" pfx="" part
  IFS='/' read -ra part <<< "$dir"
  for _ in "${part[@]+"${part[@]}"}"; do pfx="../$pfx"; done
  printf '%s' "$pfx"
}

mm_write_block() {                  # $1 file, $2 body, $3 $4 markers, $5 note
  local file="$1" body="$2" S="${3:-$MM_START}" E="${4:-$MM_END}" sep=""
  local note="${5:-generated by install.sh: edit above or below, never inside}"
  local was=""
  mkdir -p "$(dirname "$file")"
  # An empty file of the user's must come back empty, not be deleted as one we created.
  if [ -z "${MM_FILE_WAS_OURS:-}" ] && [ -f "$file" ] && { [ ! -s "$file" ] || grep -qF '(file=empty) -->' "$file"; }; then was=empty; fi
  mm_strip_block "$file" exact "$S" "$E" || true
  if [ -s "$file" ]; then
    if [ -n "$(tail -c 1 "$file")" ]; then sep=$'\n\n'; note="$note (eol=none)"; else sep=$'\n'; fi
  elif [ "$was" = empty ]; then note="$note (file=empty)"
  fi
  printf '%s%s\n<!-- %s -->\n%s\n%s\n' "$sep" "$S" "$note" "$body" "$E" >> "$file"
}

# The one reader of active-field.md: its "Current field" line, as the hook reads it, else the
# older "Field pack" bullet. Prints nothing when no field is named.
mm_field_name() {
  local af="$BRAIN/engineering/active-field.md" f
  f="$(sed -n -E 's/^[#*[:blank:]]*Current field:[*`[:blank:]]*([^*`]*).*/\1/p' "$af" 2>/dev/null | head -1)"
  f="${f%"${f##*[![:blank:]]}"}"
  case "$f" in ''|'none yet'|none|_*)
    f="$(sed -n 's/^[[:space:]]*[-*][[:space:]]*\*\*Field pack:\*\*[[:space:]]*`\([^`]*\)`.*/\1/p' "$af" 2>/dev/null | head -1)"
    f="${f%/}"; f="${f##*/}" ;;
  esac
  case "$f" in ''|'none yet'|none|_*|*/*) return 0 ;; esac
  printf '%s' "$f"
}

mm_active_field() {                 # the field active-field.md names, when that pack is built
  local f; f="$(mm_field_name)"
  [ -n "$f" ] && [ -d "$BRAIN/engineering/fields/$f" ] && printf '%s' "$f"
  return 0
}

# The field a route falls back to: the active one if it is built, else the first pack on disk.
mm_default_field() {
  local first_field default_field=""
  if [ -f "$BRAIN/engineering/active-field.md" ]; then
    default_field="$(mm_field_name)"
    [ -n "$default_field" ] && [ ! -d "$BRAIN/engineering/fields/$default_field" ] && default_field=""
  fi
  case "$default_field" in *[!A-Za-z0-9_-]*)
    [ "$MODE" = check ] || warn "field name '$default_field' has characters that cannot be templated: ignoring it" >&2
    default_field="" ;;
  esac
  if [ -z "$default_field" ]; then
    first_field="$(find "$BRAIN/engineering/fields" -maxdepth 1 -mindepth 1 -type d ! -name '_*' 2>/dev/null | sort | head -1)"
    [ -n "$first_field" ] && default_field="$(basename "$first_field")"
  fi
  printf '%s' "$default_field"
}

mm_route_field() {                  # $1 context, $2 default field: the field the route uses, or nothing
  local field
  field="$(sed -n 's/^field:[[:space:]]*//p' "$BRAIN/engineering/contexts/$1/field.md" 2>/dev/null | head -1)"
  field="${field%"${field##*[![:space:]]}"}"
  field="${field:-$2}"
  case "$field" in ''|*[!A-Za-z0-9_-]*) return 0 ;; esac
  [ -d "$BRAIN/engineering/fields/$field" ] && printf '%s' "$field"
  return 0
}

generate_context_anchors() {
  local map="$BRAIN/routes.map"
  [ -f "$map" ] || return 0
  local default_field
  default_field="$(mm_default_field)"

  local glob ctx line
  while IFS= read -r line; do
    line="${line//$'\r'/}"
    case "$line" in \#*) continue ;; esac
    line="${line%%[[:space:]]#*}"; line="$(printf '%s' "$line" | awk '{$1=$1};1')"
    [ -n "$line" ] || continue
    if [ "$(printf '%s' "$line" | wc -w | tr -d ' ')" -lt 2 ]; then
      warn "routes.map: '$line' is not '<glob> <context>': skipped"; ISSUES=$((ISSUES + 1)); continue
    fi
    glob="${line% *}"; ctx="${line##* }"
    case "$ctx" in *[!A-Za-z0-9_-]*)
      warn "routes.map: context '$ctx' has invalid characters (use letters, digits, - or _): skipped"
      ISSUES=$((ISSUES + 1)); continue ;;
    esac

    local adir="${glob%/\*\*}"; adir="${adir%/\*}"; adir="${adir%/}"
    case "$adir" in ''|'*'|'.'|'**') continue ;; esac
    # `../outside/**` reproducibly wrote into a sibling directory.
    case "$adir" in /*|*\\*) warn "routes.map: '$glob' must be a relative path inside the project: skipped"; ISSUES=$((ISSUES + 1)); continue ;; esac
    case "/$adir/" in */../*) warn "routes.map: '$glob' may not contain '..': skipped"; ISSUES=$((ISSUES + 1)); continue ;; esac
    local abs="$PROJECT/$adir" ctarget atarget
    mm_gate dir "$abs"
    mm_gate own "$abs/.cursor/rules/mastermind.mdc"
    mm_edit_target "$abs/CLAUDE.md"; ctarget="$MM_TARGET"
    mm_edit_target "$abs/AGENTS.md"; atarget="$MM_TARGET"
    mm_gate file "$ctarget"; mm_gate file "$atarget"
    if [ ! -d "$abs" ]; then warn "routes.map: '$glob' → no directory $adir/: skipped"; continue; fi
    if ! abs="$(mm_resolve_inside_project "$abs")"; then
      warn "routes.map: '$glob' resolves outside the project: skipped"; ISSUES=$((ISSUES + 1)); continue
    fi

    # Seed the context from the template on first use, then read the field it names.
    local cdir="$BRAIN/engineering/contexts/$ctx"
    # $ctx comes from routes.map, so the repository names this path, not us.
    mm_gate brain "engineering/contexts/$ctx"
    if [ ! -d "$cdir" ] && [ -z "$default_field" ]; then
      warn "context '$ctx' ($adir/) is not compiled yet: this brain has no field pack. Say init in your AI tool: it builds one and delivers it here"
      continue
    fi
    if [ ! -d "$cdir" ]; then
      local tpl="$BRAIN/engineering/_context_template"; [ -d "$tpl" ] || tpl="$REPO/engineering/_context_template"
      mkdir -p "$cdir"
      sed "s/<field>/$default_field/g; s/<name>/$ctx/g" "$tpl/field.md" > "$cdir/field.md"
      sed "s/<name>/$ctx/g" "$tpl/lessons.md" > "$cdir/lessons.md"
    elif [ -n "$default_field" ] && grep -qE '^field:[[:space:]]*$' "$cdir/field.md" 2>/dev/null; then
      # A context seeded while no field existed carries an empty field: name the default now.
      sed "s/^field:[[:space:]]*\$/field: $default_field/; s/\*\*\`\`\*\*/**\`$default_field\`**/" "$cdir/field.md" > "$cdir/field.md.mm-new"
      cat "$cdir/field.md.mm-new" > "$cdir/field.md"; rm -f "$cdir/field.md.mm-new"
    fi
    local field; field="$(mm_route_field "$ctx" "$default_field")"
    if [ -z "$field" ]; then
      warn "context '$ctx' names a field pack this brain does not have: skipped. Say init in your AI tool to build it, or fix field: in its field.md and run  $(mm_sync_cmd)"
      continue
    fi

    # The root kernel already loads for every directory below it, so only the field and context
    # are imported here. Codex has no import syntax: its anchor names the same files in prose.
    local pfx; pfx="$(mm_rel_prefix "$adir")"
    local imports="@${pfx}.mastermind/engineering/fields/${field}/field.md
@${pfx}.mastermind/engineering/contexts/${ctx}/field.md
@${pfx}.mastermind/engineering/contexts/${ctx}/lessons.md"
    local prose="Work in this directory uses the MasterMind **${field}** field and the **${ctx}** context.
Before changing anything here, read these files (paths from the repository root):
- .mastermind/engineering/fields/${field}/field.md
- .mastermind/engineering/contexts/${ctx}/field.md
- .mastermind/engineering/contexts/${ctx}/lessons.md"

    mm_ledger_add "$adir"
    if [ "$ctarget" = "$atarget" ]; then
      mm_write_block "$ctarget" "$prose
$imports"
    else
      mm_write_block "$ctarget" "$imports"
      mm_write_block "$atarget" "$prose"
    fi
    mm_mkdir "$abs/.cursor/rules"
    { printf -- '---\nglobs: %s\ndescription: MasterMind context for %s\n---\n' "$glob" "$ctx"
      printf -- '<!-- %s: do not edit. Refresh with: npx mastermind-brain -->\n' "$MM_GEN_MARK"
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
# routes.map: per-app field/context routing (monorepos). One rule per line:
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

mm_sync_router() {                  # $1 brain, $2 name shown
  if [ -f "$1/scripts/build-router.mjs" ] && node "$1/scripts/build-router.mjs" >/dev/null 2>&1; then ok "$2/engineering/ROUTER.md regenerated"
  else warn "$2/engineering/ROUTER.md could not be regenerated: run  node $2/scripts/build-router.mjs"; fi
}

if [ "$MODE" = sync ]; then
  _recf="$(mm_record_file)"
  if [ "$SCOPE" = global ] || { [ "$ISOLATED" = 0 ] && [ ! -f "$_recf" ] && [ -f "$MM_STATE/global" ]; }; then
    # A global brain wires no project files: its field pack and router live in the clone.
    if [ ! -f "$MM_STATE/global" ]; then
      printf '%s✖ MasterMind is not installed globally, so there is nothing to sync.%s Install it:  npx mastermind-brain --global\n' "$r" "$x" >&2
      exit 1
    fi
    printf 'MasterMind sync → %sglobal brain%s (offline)\n' "$g" "$x"
    if [ -z "$(mm_active_field)" ]; then warn "no active field pack yet: say init in your AI tool to build one"; fi
    mm_sync_router "$REPO" '~/.mastermind'
    printf '\n%s✓ synced.%s  Verify: ~/.mastermind/install.sh --check --global\n' "$g" "$x"
    exit 0
  fi
  # An isolated brain outlives an uninstall, so the brain alone is not an install: the record is.
  if [ ! -f "$_recf" ]; then
    printf '%s✖ MasterMind is not installed in this project (no install record), so there is nothing to sync.%s Install it:  npx mastermind-brain\n' "$r" "$x" >&2
    exit 1
  fi
  _rec=" $(sed -n 's/^tools=//p' "$_recf") "
  printf 'MasterMind sync → %sthis project%s (offline)\n' "$g" "$x"
  if [ -z "$(mm_active_field)" ]; then warn "no active field pack yet: say init in your AI tool to build one"; fi
  if [ -f "$PROJECT/.cursor/rules/mastermind.mdc" ] || case "$_rec" in *' cursor '*) true ;; *) false ;; esac; then
    mm_gate dir "$PROJECT/.cursor/rules"; mm_mkdir "$PROJECT/.cursor/rules"
    wire_cursor_field
  fi
  if [ "$ISOLATED" = 1 ]; then
    mm_sync_router "$BRAIN" .mastermind
    generate_context_anchors
  else
    mm_sync_router "$REPO" '~/.mastermind'
  fi
  # What sync created goes into the record, so uninstall takes it back.
  if [ -n "$MM_CREATED" ]; then
    case "$_recf" in "$MM_STATE"/*) mm_gate own "$_recf" "$MM_STATE" ;; *) mm_gate own "$_recf" ;; esac
    _tf="$(mktemp)"
    { grep -v -e '^digest=' -e '^created=' "$_recf" || true
      { sed -n 's/^created=//p' "$_recf"; printf '%s' "$MM_CREATED"; } | grep -v '^$' | sort -u | sed 's/^/created=/' || true
    } > "$_tf"
    cat "$_tf" > "$_recf"
    printf 'digest=%s\n' "$(mm_hash "$_tf")" >> "$_recf"
    rm -f "$_tf"
  fi
  printf '\n%s✓ synced.%s  Verify: %s --check\n' "$g" "$x" "$(if [ "$ISOLATED" = 1 ]; then printf '.mastermind/install.sh'; else printf '~/.mastermind/install.sh'; fi)"
  exit 0
fi

if [ "$ISOLATED" = 1 ] && [ "$MODE" = install ]; then
  sync_isolated_brain
  if [ -n "$(mm_active_field)" ]; then ok "isolated brain → .mastermind/ (v$(cat "$BRAIN/VERSION")): this project's own lessons and stack ($(mm_active_field) field)"
  else ok "isolated brain → .mastermind/ (v$(cat "$BRAIN/VERSION")): this project's own lessons and stack; say init in your AI tool to build its field"; fi
  seed_routes_example
  generate_context_anchors
fi

if [ "$MODE" != check ]; then
  printf 'MasterMind → %s%s%s\n' "$g" "$([ "$SCOPE" = global ] && echo "global: every project" || echo "this project")" "$x"
fi

mm_has_our_links() {
  local l
  for l in "$1"/*; do
    if mm_is_our_capability "$l"; then return 0; fi
  done
  return 1
}

mm_overlap_note() {
  local here keep='Keep one: remove the global one with  ~/.mastermind/install.sh --global --uninstall  or the project one with  ~/.mastermind/install.sh --uninstall  run there.'
  [ "$MODE" = uninstall ] && return 0
  if [ "$SCOPE" = project ]; then
    mm_wants claude || return 0
    if [ -f "$MM_STATE/global" ] || is_wired "$HOME/.claude/CLAUDE.md"; then
      printf '\n'
      warn "MasterMind is also installed globally (~/.claude): Claude Code loads both kernels and both hooks here, and the global skills win over this project's same-named ones. $keep"
    fi
  else
    here="$(find_project_root)"
    # A .mastermind/ left after an uninstall holds the project's lessons, not a live install.
    if [ ! "$here" -ef "$HOME" ] && { [ -f "$here/.mastermind/.installed" ] || is_wired "$here/.claude/CLAUDE.md" ||
         links_to "$here/.claude/CLAUDE.md" "$here/.mastermind/CLAUDE.md"; }; then
      printf '\n'
      warn "$here has its own MasterMind install: Claude Code loads both kernels and both hooks there, and these global skills win over that project's same-named ones. $keep"
    fi
  fi
  return 0
}

# --- Which tools? -------------------------------------------------------------
if [ ${#TOOLS[@]} -eq 0 ]; then
  if [ "$MODE" = check ]; then
    # Say it out loud when we switched scope: a silent switch is its own confusion.
    [ "${CHECK_SCOPE_SWITCHED:-0}" = 1 ] &&
      printf '%sno project here: checking the global install instead.%s\n\n' "$y" "$x"
    _recf="$(mm_record_file)"
    if [ -f "$_recf" ]; then
      _want="$(sed -n 's/^digest=//p' "$_recf" | head -1)"
      if [ -n "$_want" ]; then
        _body="$(mktemp)"; grep -v '^digest=' "$_recf" > "$_body" || true
        [ "$(mm_hash "$_body")" = "$_want" ] ||
          warn "the install record was edited by hand, so what it says SHOULD be wired may not be what was"
        rm -f "$_body"
      fi
      _rec="$(sed -n 's/^tools=//p' "$_recf")"
      for _t in $_rec; do TOOLS+=("$_t"); done
      unset _rec _t
    else
      warn "no install record here: checking every integration that is present, so one removed entirely may go unreported"
    fi
    if [ ${#TOOLS[@]} -eq 0 ]; then
      if is_wired "$CLAUDE_DIR/CLAUDE.md" || mm_has_our_links "$CLAUDE_DIR/skills"; then TOOLS+=("claude"); fi
      if [ -n "$AGENTS_FILE" ] && { is_wired "$AGENTS_FILE" || mm_has_our_links "$PROJECT/.agents/skills"; }; then TOOLS+=("agents"); fi
      if [ "$SCOPE" = project ] && { [ -f "$PROJECT/.cursor/rules/mastermind.mdc" ] ||
           grep -qF 'session-start.sh' "$PROJECT/.cursor/hooks.json" 2>/dev/null; }; then TOOLS+=("cursor"); fi
    fi
    if [ "$SCOPE" = global ] && is_wired "$CODEX_GLOBAL"; then
      case " ${TOOLS[*]-} " in *' codex '*) : ;; *) TOOLS+=("codex") ;; esac
    fi
    if [ ${#TOOLS[@]} -eq 0 ]; then
      bad "MasterMind isn't set up $([ "$SCOPE" = global ] && echo globally || echo 'in this project') yet."
      echo "  Run:  ~/.mastermind/install.sh$([ "$SCOPE" = global ] && echo ' --global')"
      exit 1
    fi
  else
    # install: wire the tools you have
    { command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; } && TOOLS+=("claude")
    [ "$SCOPE" = global ] && { command -v codex >/dev/null 2>&1 || [ -d "$CODEX_HOME_DIR" ]; } && TOOLS+=("codex")
    { command -v cursor >/dev/null 2>&1 || [ -d "$HOME/.cursor" ]; } && TOOLS+=("cursor")
    [ "$SCOPE" = project ] && TOOLS+=("agents")
    # A plain re-run repairs every tool the install record names, detected or not.
    _recf="$(mm_record_file)"
    if [ "$SCOPE" = project ] && [ ! -f "$_recf" ] && [ "$ISOLATED" = 1 ]; then _recf="$(mm_state_record)"; fi
    if [ -f "$_recf" ]; then
      for _t in $(sed -n 's/^tools=//p' "$_recf"); do
        case "$_t" in gemini|copilot) continue ;; esac
        case " ${TOOLS[*]-} " in *" $_t "*) : ;; *) TOOLS+=("$_t") ;; esac
      done
    fi
    unset _recf _t
    if [ ${#TOOLS[@]} -eq 0 ]; then
      warn "No supported tool detected."
      echo "  You need an AI coding tool first: e.g. Claude Code: https://claude.com/claude-code"
    fi
  fi
fi

# A record from before 0.34 lists nothing the installer created. What holds only our wiring now
# is taken to be ours, so an upgraded project can still be handed back as it was.
mm_only_ours() {                    # $1 directory
  local d="$1" e any=0
  [ -d "$d" ] && [ ! -L "$d" ] || return 1
  for e in "$d"/* "$d"/.[!.]*; do
    path_exists "$e" || continue
    if [ -L "$e" ]; then is_ours "$e" || return 1
    elif [ -d "$e" ]; then mm_only_ours "$e" || return 1
    else mm_sole_ours "$e" || return 1; fi
    any=1
  done
  # An empty folder says nothing about who made it, so it stays the user's.
  [ "$any" = 1 ]
}
mm_sole_ours() {                    # $1 file
  mm_is_generated "$1" && return 0
  local rel="${1#"$PROJECT"/}" tool
  case "$rel" in
    .claude/settings.json) tool=claude ;;
    .cursor/hooks.json)    tool=cursor ;;
    .codex/hooks.json)     tool=codex ;;
    *) return 1 ;;
  esac
  # A file the user committed is theirs, whatever our install has since put in it.
  mm_user_made "$tool" "$rel" && return 1
  mm_hooks_js "$tool" sole "$1"
}
mm_adopt_legacy() {
  local rel
  for rel in .claude/settings.json .cursor/hooks.json .codex/hooks.json; do
    if [ -f "$PROJECT/$rel" ] && [ ! -L "$PROJECT/$rel" ] && mm_sole_ours "$PROJECT/$rel"; then MM_CREATED="$MM_CREATED$rel
"; fi
  done
  for rel in .claude/agents .claude/skills .claude .cursor/rules .cursor/skills .cursor/agents .cursor .codex .agents/skills .agents; do
    # In a home directory these three belong to the tools themselves, whatever they hold now.
    case "$SCOPE:$rel" in global:.claude|global:.cursor|global:.codex) continue ;; esac
    if mm_only_ours "$PROJECT/$rel"; then MM_CREATED="$MM_CREATED$rel
"; fi
  done
  return 0
}

# Before anything is wired: what a pre-0.34 install left holding only our wiring is ours.
if [ "$MODE" = install ]; then
  _recf="$(mm_record_file)"
  for _f in "$_recf" "$(mm_state_record)"; do
    if [ -f "$_f" ] && ! grep -q '^mode=' "$_f"; then mm_adopt_legacy; break; fi
  done
  unset _f _recf
fi

for tool in ${TOOLS[@]+"${TOOLS[@]}"}; do
  case "$tool" in
    claude)  wire_claude "$CLAUDE_DIR" ;;
    agents|agents.md)
      printf '\nAGENTS.md:\n'
      if [ -z "$AGENTS_FILE" ]; then warn "AGENTS.md is per-project: run this inside a project"
      else wire_brain_file "$AGENTS_FILE" "$BRAIN/AGENTS.md"; wire_codex_hook; wire_agent_skills "$PROJECT/.agents/skills" .agents/skills; fi ;;
    cursor)
      printf '\nCursor:\n'
      if [ "$SCOPE" = global ]; then
        [ "$MODE" = check ] || warn "Cursor rules are per-project, so run this inside a project for the kernel: only the subagents are wired for your account"
        wire_cursor_agents
      else wire_cursor; fi ;;
    codex)
      printf '\nCodex:\n'
      if [ "$SCOPE" = global ]; then wire_codex_global; wire_codex_hook; wire_agent_skills "$HOME/.agents/skills" "~/.agents/skills"
      else wire_brain_file "$AGENTS_FILE" "$BRAIN/AGENTS.md"; wire_codex_hook; wire_agent_skills "$PROJECT/.agents/skills" .agents/skills; fi ;;
    gemini|copilot)
      warn "$tool is no longer wired automatically: MasterMind is plain Markdown, so point it at $([ "$ISOLATED" = 1 ] && echo '.mastermind/CLAUDE.md' || echo '~/.mastermind/CLAUDE.md') and it works the same." ;;
    *) warn "skipping unknown tool: $tool";;
  esac
done

if [ "$MODE" = install ] && [ "$MM_CODEX_HOOK_NOTE" = 1 ]; then
  printf '\n'
  if [ "$SCOPE" = global ]; then warn "Codex runs a new hook only after you approve it: open Codex and run /hooks once. Until then nothing reminds it of the kernel after a compaction."
  else warn "Codex runs a project's hooks only in a project it trusts, and only after you approve the hook: open Codex here and run /hooks once. Until then AGENTS.md still carries the kernel; only the reminder after a compaction is missing."; fi
fi
mm_overlap_note

if [ "$SCOPE" = global ]; then MM_MODE_NAME=global
elif [ "$ISOLATED" = 1 ]; then MM_MODE_NAME=isolated
else MM_MODE_NAME=shared; fi


if [ "$MODE" = install ]; then
  _rec_prev=""; _recf="$(mm_record_file)"; _rec_old="$_recf"
  [ "$MM_MODE_NAME" = isolated ] && _rec_old="$(mm_state_record)"
  [ -f "$_recf" ] && _rec_prev="$(sed -n 's/^tools=//p' "$_recf")"
  _created="$( { for _f in "$_recf" "$_rec_old"; do
                   if [ -f "$_f" ]; then sed -n 's/^created=//p' "$_f"; fi
                 done; printf '%s' "$MM_CREATED"; } | grep -v '^$' | sort -u || true)"
  case "$_recf" in "$MM_STATE"/*) mm_gate own "$_recf" "$MM_STATE" ;; *) mm_gate own "$_recf" ;; esac
  # Retired names are accepted so `--uninstall gemini` still works, but recording them made the
  # doctor expect wiring that was never created and then report the install healthy.
  # `|| true`: an all-retired list prints nothing, and under pipefail that kills the installer.
  _rec_all="$(printf '%s %s\n' "$_rec_prev" "${TOOLS[*]}" | tr ' ' '\n' | grep -v '^$' |
    grep -vxE 'gemini|copilot' | sort -u | tr '\n' ' ' || true)"
  _rec_all="${_rec_all% }"
  mkdir -p "$(dirname "$_recf")"
  { printf 'version=%s\n' "$(cat "$REPO/VERSION" 2>/dev/null || echo unknown)"
    printf 'scope=%s\n' "$SCOPE"
    printf 'mode=%s\n' "$MM_MODE_NAME"
    printf 'tools=%s\n' "$_rec_all"
    printf 'project=%s\n' "$PROJECT"
    printf 'brain=%s\n' "$BRAIN"
    if [ -n "$_created" ]; then printf '%s\n' "$_created" | sed 's/^/created=/'; fi
  } > "$_recf"
  # Tamper-evident, not tamper-proof: signing buys nothing against someone who can already edit
  # install.sh. This only lets the doctor say "this was edited by hand" instead of believing it.
  printf 'digest=%s\n' "$(mm_hash "$_recf")" >> "$_recf"
  # A project that moved from the shared brain to its own keeps one record, not two.
  if [ "$_rec_old" != "$_recf" ] && [ -f "$_rec_old" ] && grep -qxF "project=$PROJECT" "$_rec_old"; then
    rm -f "$_rec_old"
  fi
  unset _f _created _rec_old
fi

if [ "$MODE" = install ] && [ "$SCOPE" = project ]; then
  for _seed in prefs brief; do
    _dst="$PROJECT/.mastermind/$_seed.md"
    [ -e "$_dst" ] && continue
    [ -f "$REPO/$_seed.seed.md" ] || continue
    mm_gate own "$_dst"
    mkdir -p "$PROJECT/.mastermind"
    cp -p "$REPO/$_seed.seed.md" "$_dst"
    ok ".mastermind/$_seed.md seeded (yours to edit; never overwritten)"
  done
fi

if [ "$MODE" = install ] && [ "$SCOPE" = project ] && [ -d "$PROJECT/.mastermind" ]; then
  _mmgi="$PROJECT/.mastermind/.gitignore"
  _mmgi_mark='# Generated by MasterMind: private and machine state, kept out of git.'
  mm_gate own "$_mmgi"
  if [ -f "$_mmgi" ] && ! grep -qF "$_mmgi_mark" "$_mmgi"; then
    for _need in '/local/' '/private/' '/.installed'; do
      grep -qxF "$_need" "$_mmgi" ||
        warn ".mastermind/.gitignore is yours, and it does not ignore $_need: private material can be committed"
    done
  fi
  if [ ! -f "$_mmgi" ] || grep -qF "$_mmgi_mark" "$_mmgi"; then
    { printf -- '%s\n' "$_mmgi_mark"
      printf -- '# Everything else under .mastermind/ is safe to commit.\n'
      printf -- '/local/\n/private/\n/HANDOFF.md\n'
      printf -- '/.installed\n/.originals/\n'
      printf -- '# .manifest, .manifest.hashes and .routes.generated stay tracked on purpose: the\n'
      printf -- '# updater needs them to know which files are its own and which retired ones to prune.\n'
    } > "$_mmgi"
    ok ".mastermind/.gitignore: private and machine state kept out of git"
  fi
fi

check_routes() {
  local map="$BRAIN/routes.map"
  [ -f "$map" ] || return 0
  local glob ctx line adir field default_field
  default_field="$(mm_default_field)"
  while IFS= read -r line; do
    line="${line//$'\r'/}"
    case "$line" in \#*) continue ;; esac
    line="${line%%[[:space:]]#*}"; line="$(printf '%s' "$line" | awk '{$1=$1};1')"
    [ -n "$line" ] || continue
    if [ "$(printf '%s' "$line" | wc -w | tr -d ' ')" -lt 2 ]; then
      bad "routes.map: '$line' is not '<glob> <context>'"; ISSUES=$((ISSUES + 1)); continue
    fi
    glob="${line% *}"; ctx="${line##* }"
    if [ -z "$default_field" ] && { [ ! -d "$BRAIN/engineering/contexts/$ctx" ] || [ -z "$(mm_route_field "$ctx" "")" ]; }; then
      adir="${glob%/\*\*}"; adir="${adir%/\*}"; adir="${adir%/}"
      warn "route $adir/ → $ctx is not compiled yet: this brain has no field pack. Say init in your AI tool: it builds one and delivers it here"
      continue
    fi
    if [ ! -d "$BRAIN/engineering/contexts/$ctx" ]; then
      bad "routes.map: context '$ctx' has no dir: run  $(mm_sync_cmd)"; ISSUES=$((ISSUES + 1)); continue
    fi
    field="$(mm_route_field "$ctx" "$default_field")"
    if [ -z "$field" ]; then
      bad "routes.map: context '$ctx' names missing field '$(sed -n 's/^field:[[:space:]]*//p' "$BRAIN/engineering/contexts/$ctx/field.md" 2>/dev/null | head -1)': say init in your AI tool to build it, or fix field: in its field.md and run  $(mm_sync_cmd)"
      ISSUES=$((ISSUES + 1)); continue
    fi
    adir="${glob%/\*\*}"; adir="${adir%/\*}"; adir="${adir%/}"
    case "$adir" in ''|'*'|'.'|'**') continue ;; esac
    [ -d "$PROJECT/$adir" ] || continue
    local _bad=0 _f
    for _f in CLAUDE.md AGENTS.md; do
      case "$_f" in
        CLAUDE.md) mm_wants claude || continue ;;
        AGENTS.md) { mm_wants agents || mm_wants codex; } || continue ;;
      esac
      if [ ! -f "$PROJECT/$adir/$_f" ] || ! grep -q 'MASTERMIND:START' "$PROJECT/$adir/$_f"; then
        bad "route $adir/ → $ctx: $_f anchor missing: run  $(mm_sync_cmd)"; _bad=1; continue
      fi
      grep -qF "engineering/contexts/$ctx/" "$PROJECT/$adir/$_f" ||
        { bad "route $adir/ → $ctx: $_f does not import context '$ctx'"; _bad=1; }
      grep -qF "engineering/fields/$field/" "$PROJECT/$adir/$_f" ||
        { bad "route $adir/ → $ctx: $_f does not import field '$field'"; _bad=1; }
    done
    if mm_wants cursor; then
      if mm_is_generated "$PROJECT/$adir/.cursor/rules/mastermind.mdc"; then
        grep -qF "$ctx" "$PROJECT/$adir/.cursor/rules/mastermind.mdc" ||
          { bad "route $adir/ → $ctx: the Cursor rule does not name this context"; _bad=1; }
      else
        bad "route $adir/ → $ctx: the Cursor rule is missing: run  $(mm_sync_cmd)"; _bad=1
      fi
    fi
    if [ "$_bad" = 0 ]; then ok "route $adir/ → $ctx ($field)"
    else ISSUES=$((ISSUES + 1)); fi
  done < "$map"
}
# What every wired surface loads from: a brain with these gone checks healthy and works nowhere.
check_brain() {
  local f missing=0 list
  if [ "$ISOLATED" = 1 ] && [ -f "$BRAIN/.manifest.hashes" ]; then list="$(awk '{ print $2 }' "$BRAIN/.manifest.hashes")"
  else
    list="CLAUDE.md
bin/mastermind
cli/bin/mastermind.mjs
hooks/session-start.sh"
    for f in "$REPO"/engineering/core/*.md; do [ -f "$f" ] && list="$list
engineering/core/${f##*/}"; done
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in /*|*..*) continue ;; esac
    path_exists "$BRAIN/$f" && continue
    bad "the brain is missing $f: re-run install.sh to restore it"; missing=$((missing + 1))
  done <<EOF
$list
EOF
  if [ "$missing" = 0 ]; then ok "brain files present"; else ISSUES=$((ISSUES + missing)); fi
}
if [ "$MODE" = check ]; then printf '\nBrain:\n'; check_brain; fi
[ "$MODE" = check ] && [ "$ISOLATED" = 1 ] && { printf '\nRoutes:\n'; check_routes; }

# --- Report ------------------------------------------------------------------
if [ "$MODE" = check ]; then
  echo
  if [ "$ISSUES" -eq 0 ]; then
    printf '%s✓ MasterMind is healthy here: every wired tool resolves.%s\n' "$g" "$x"
    if [ "$ISOLATED" = 1 ] && [ -f "$BRAIN/VERSION" ]; then
      pv="$(cat "$BRAIN/VERSION")"; cv="$(cat "$REPO/VERSION" 2>/dev/null || echo "$pv")"
      if [ "$pv" != "$cv" ]; then
        printf '  %s⬆ this project is on v%s; the clone has v%s.%s  Refresh:  ~/.mastermind/install.sh\n' "$y" "$pv" "$cv" "$x"
      else
        printf '  isolated brain v%s: up to date with the clone.\n' "$pv"
      fi
    fi
    check_updates; exit 0
  else printf '%s✖ %d issue(s). Re-run the installer to repair.%s\n' "$r" "$ISSUES" "$x"; exit 1; fi
fi

if [ "$REFUSED" -gt 0 ]; then
  _how=""
  case "$MM_REFUSED_KINDS" in *link*) _how="replace each refused link with a real folder or file" ;; esac
  case "$MM_REFUSED_KINDS" in *block*) _how="${_how:+$_how; }fix the MasterMind block in each refused file as described above" ;; esac
  printf '\n%s✖ %d target(s) were refused, so those surfaces are not wired:%s%s. To fix: %s, then re-run.\n' "$r" "$REFUSED" "$x" "$MM_REFUSED_LIST" "$_how"
  exit 1
fi

if [ "$LINK_FAILED" -gt 0 ]; then
  printf '\n%s✖ %d link(s) could not be created, listed above. Fix the permissions and re-run.%s\n' "$r" "$LINK_FAILED" "$x"
  exit 1
fi

if [ "$SCOPE" = project ]; then
  printf '\n%sActive in THIS project.%s  Add another: cd there && ~/.mastermind/install.sh   ·   Claude Code everywhere: --global\n' "$g" "$x"
  printf 'On another tool? It reads AGENTS.md, or point it at %s.\n' "$([ "$ISOLATED" = 1 ] && echo '.mastermind/CLAUDE.md' || echo '~/.mastermind/CLAUDE.md')"
  if [ "$ISOLATED" = 1 ]; then
    printf 'Commit .mastermind/ to pin this brain for your team, or gitignore it and let each of them install.\n'
  else
    printf 'This wiring is per-machine: its links and hook commands hold absolute paths to your clone, so keep .claude/, .cursor/, .agents/, .codex/ and AGENTS.md from this install out of git.\n'
  fi
fi
case "$MM_MODE_NAME" in
  global) _flag=' --global'; _where='' ;;
  shared) _flag=' --shared'; _where=' (from this project)' ;;
  *)      _flag=''; _where=' (from this project)' ;;
esac
printf 'Update%s: git -C ~/.mastermind pull && ~/.mastermind/install.sh%s   ·   Verify: ~/.mastermind/install.sh --check%s\n' \
  "$_where" "$_flag" "$([ "$SCOPE" = global ] && echo ' --global')"
# "restart your tool" is the instruction everyone skips, because it never says what to do. Each
# tool reloads differently, and only a session that is already open is stale.
printf '\n%sTo load it in a session you already have open:%s\n' "$g" "$x"
for _t in ${TOOLS[@]+"${TOOLS[@]}"}; do
  case "$_t" in
    claude)       printf '  Claude Code   type /clear   (or open a new session)\n' ;;
    cursor)       printf '  Cursor        start a new chat\n' ;;
    codex|agents) printf '  Codex         start a new session and trust the project when asked: it reads AGENTS.md at startup only\n' ;;
  esac
done
printf '  Any session you open from now on already has it.\n'
printf '\n%sHow to tell it worked:%s ask it "are you MasterMind?". On anything non-trivial it also opens with a 🧠 line.\n' "$g" "$x"
