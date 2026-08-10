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
    --check|--uninstall)
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
ISSUES=0; LINKED_SKILLS=0; LINKED_AGENTS=0; PRUNED=0; RENAMED=0; SKIPPED=0; UNFINISHED=0
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
mm_record_file() {
  local state="${MM_STATE_DIR:-$HOME/.mastermind-state}"
  if [ "$SCOPE" = global ]; then
    printf '%s/global' "$state"
  elif [ -d "$PROJECT/.mastermind" ]; then
    printf '%s/.mastermind/.installed' "$PROJECT"
  else
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
  fi
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

if [ "$SCOPE" = project ] && [ "$SHARED" = 0 ] && [ "$MODE" = install ]; then ISOLATED=1; fi
if [ "$SCOPE" = project ] && { [ "$ISOLATED" = 1 ] || { [ "$SHARED" = 0 ] && [ -f "$PROJECT/.mastermind/VERSION" ] && [ ! -L "$PROJECT/.mastermind" ]; }; }; then
  BRAIN="$PROJECT/.mastermind"; ISOLATED=1
else
  BRAIN="$REPO"
fi

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

mm_assert_real_file() {
  local path="$1" real
  [ -L "$path" ] || return 0
  real="$(mm_realpath "$path" 2>/dev/null)" || real="unresolvable"
  printf '%s! %s is a symlink (-> %s), and MasterMind writes that file directly.%s\n' \
    "$r" "${path#"$PROJECT"/}" "$real" "$x" >&2
  printf '  Refusing to write through it. Remove the link and re-run.\n' >&2
  exit 1
}

mm_assert_contained() {
  local path="$1" proj real
  [ -e "$path" ] || [ -L "$path" ] || return 0          # not there yet: we create it ourselves
  proj="$(cd -P "$PROJECT" 2>/dev/null && pwd -P)" || {
    printf '%s! cannot resolve the project directory (%s).%s Refusing to write.\n' "$r" "$PROJECT" "$x" >&2
    exit 1
  }
  real="$(mm_realpath "$path")" || {
    printf '%s! %s is an unresolvable symlink chain.%s Refusing to write through it.\n' \
      "$r" "${path#"$PROJECT"/}" "$x" >&2
    exit 1
  }
  mm_inside "$proj" "$real" && return 0

  local rbrain rrepo base
  rbrain="$(cd -P "$BRAIN" 2>/dev/null && pwd -P)" || rbrain=""
  rrepo="$(cd -P "$REPO"  2>/dev/null && pwd -P)" || rrepo=""
  base="$(basename "$path")"
  case "$base" in
    CLAUDE.md|AGENTS.md)
      for _d in ${rbrain:+"$rbrain/CLAUDE.md" "$rbrain/AGENTS.md"} \
                ${rrepo:+"$rrepo/CLAUDE.md" "$rrepo/AGENTS.md"}; do
        _r="$(mm_realpath "$_d" 2>/dev/null)" || _r="$_d"
        [ "$real" = "$_r" ] && { unset _d _r; return 0; }
      done
      unset _d _r ;;
  esac

  printf '%s! %s resolves outside the project (-> %s).%s Refusing to write there.\n' \
    "$r" "${path#"$PROJECT"/}" "${real:-unreadable}" "$x" >&2
  printf '  A repository cannot be allowed to redirect the installer onto paths you did not choose.\n' >&2
  exit 1
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

MM_GEN_MARK='Generated by ~/.mastermind/install.sh'

mm_is_generated() { [ -f "$1" ] && grep -qF "$MM_GEN_MARK" "$1"; }

mm_preserve_foreign() {
  local dst="$1"
  [ -e "$dst" ] || return 0
  mm_is_generated "$dst" && return 0
  local bak="$dst.bak-$(date +%Y%m%d%H%M%S)-$$"
  mv "$dst" "$bak"; warn "backed up your existing $(basename "$dst") → $bak"
  mkdir -p "$(dirname "$dst")" && printf '%s\n' "$bak" > "$dst.mm-backup"
}

mm_remove_generated() {
  local dst="$1"
  [ -f "$dst" ] || return 1
  if ! mm_is_generated "$dst"; then
    warn "left $(basename "$dst") alone: it is not the file we generated"
    return 1
  fi
  rm -f "$dst"; ok "removed $(basename "$dst")"
  return 0
}

safe_link() {
  local src="$1" dst="$2"
  if [ "$MODE" = check ]; then
    if is_ours "$dst" && [ -e "$dst" ]; then ok "$(basename "$dst")"
    else bad "$(basename "$dst") is not linked to MasterMind"; ISSUES=$((ISSUES + 1)); fi
    return
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    local bak="$dst.bak-$(date +%Y%m%d%H%M%S)-$$"
    mv "$dst" "$bak"; warn "backed up your existing $(basename "$dst") → $bak"
    mkdir -p "$(dirname "$dst")" && printf '%s\n' "$bak" > "$dst.mm-backup"
  fi
  ln -sfn "$(mm_link_src "$src" "$dst")" "$dst"
}

is_ours() {
  [ -L "$1" ] || return 1
  local rt rrepo rbrain
  rt="$(mm_realpath "$1")" || return 1
  rrepo="$(cd -P "$REPO" 2>/dev/null && pwd -P)" || rrepo="$REPO"
  rbrain="$(cd -P "$BRAIN" 2>/dev/null && pwd -P)" || rbrain="$BRAIN"
  mm_inside "$rrepo" "$rt" && return 0
  mm_inside "$rbrain" "$rt" && return 0
  return 1
}
path_exists() { [ -e "$1" ] || [ -L "$1" ]; }

link_skill() {
  local src="$1" base="$2" name="$3" kind="$4"
  local dst="$base/$name" alt="$base/mastermind-$name"
  local target="$dst" renamed=0   # separate `local`: same-statement $dst isn't set yet

  if path_exists "$dst" && ! is_ours "$dst"; then target="$alt"; renamed=1; fi

  if [ "$MODE" = check ]; then
    if links_to "$target" "$src" && [ -e "$target" ]; then
      if [ "$renamed" = 1 ]; then ok "mastermind-$name (your own '$name' kept)"; else ok "$name"; fi
      return 0
    fi
    if [ -L "$target" ]; then
      bad "$(basename "$target") points at $(readlink "$target"), not $kind $name"
    else
      bad "$(basename "$target") is not linked to MasterMind"
    fi
    ISSUES=$((ISSUES + 1)); return 1
  fi

  # The project owns BOTH names: refuse rather than clobber anything of theirs.
  if [ "$renamed" = 1 ] && path_exists "$alt" && ! is_ours "$alt"; then
    warn "you own both '$name' and 'mastermind-$name': MasterMind's $kind skipped"
    SKIPPED=$((SKIPPED + 1)); return 1
  fi

  ln -sfn "$(mm_link_src "$src" "$target")" "$target"
  if [ "$renamed" = 1 ]; then
    warn "you already have a $kind '$name': installed MasterMind's as 'mastermind-$name' (both work)"
    RENAMED=$((RENAMED + 1))
  elif is_ours "$alt"; then
    # Their colliding file is gone, so ours reclaimed the real name: drop the alias.
    rm -f "$alt"
  fi
  return 0
}

wire_brain_file() {
  local dst="$1" src="$2"
  if [ "$MODE" = check ]; then
    if links_to "$dst" "$src" || mm_has_pointer "$dst"; then ok "$(basename "$dst")"
    else bad "$(basename "$dst") not wired to MasterMind"; ISSUES=$((ISSUES + 1)); fi
    return
  fi
  mkdir -p "$(dirname "$dst")"
  # "resolves somewhere inside the brain" is not ownership: a project pointing AGENTS.md at
  # .mastermind/prefs.md had that link replaced with no backup and removed on uninstall. Ours
  # is the link that points at exactly what we would create.
  if [ -L "$dst" ] && ! links_to "$dst" "$src"; then
    local bak="$dst.bak-$(date +%Y%m%d%H%M%S)-$$"
    mv "$dst" "$bak"; warn "backed up your existing $(basename "$dst") symlink → $bak"
    printf '%s\n' "$bak" > "$dst.mm-backup"
  fi
  if [ ! -e "$dst" ] || [ -L "$dst" ] || { [ -f "$dst" ] && [ ! -s "$dst" ]; }; then
    ln -sfn "$(mm_link_src "$src" "$dst")" "$dst"; ok "$(basename "$dst") linked"
  elif grep -q 'mastermind/CLAUDE.md' "$dst"; then ok "$(basename "$dst") already wired"
  else printf '\n%s\n' "$(mm_hint)" >> "$dst"; ok "appended MasterMind pointer to your $(basename "$dst")"
  fi
}

wire_codex_global() {
  local ovr="$CODEX_HOME_DIR/AGENTS.override.md"
  if [ "$MODE" = check ]; then
    if [ -s "$ovr" ]; then warn "$CODEX_HOME_DIR/AGENTS.override.md takes priority: MasterMind's global file is ignored by Codex"; return 0; fi
    if is_wired "$CODEX_GLOBAL"; then warn "$CODEX_GLOBAL wired (may not reach project chats: openai/codex#27705)"
    else bad "$CODEX_GLOBAL not wired to MasterMind"; ISSUES=$((ISSUES + 1)); fi
    return 0
  fi
  wire_brain_file "$CODEX_GLOBAL" "$BRAIN/AGENTS.md"
  [ -s "$ovr" ] && warn "you have AGENTS.override.md: Codex reads that instead, so this file won't apply"
  warn "Codex may not merge global instructions into a project that has its own AGENTS.md (openai/codex#27705): run install.sh inside each project for the reliable path"
  return 0
}

# Cursor rule (its own file, always ours): needs alwaysApply frontmatter to load.
wire_cursor() {
  local dst="$PROJECT/.cursor/rules/mastermind.mdc"
  if [ "$MODE" = check ]; then
    if mm_is_generated "$dst" && grep -q 'Prime directives' "$dst"; then ok ".cursor/rules/mastermind.mdc"
    elif [ -f "$dst" ]; then bad ".cursor rule is the old pointer-only shape: re-run install.sh"; ISSUES=$((ISSUES + 1))
    else bad ".cursor rule not set"; ISSUES=$((ISSUES + 1)); fi
    return
  fi
  mkdir -p "$PROJECT/.cursor/rules"
  mm_preserve_foreign "$dst"
  { printf -- '---\nalwaysApply: true\n---\n'
    printf -- '<!-- Generated by ~/.mastermind/install.sh: do not edit. Refresh with: npx mastermind-brain -->\n\n'
    cat "$BRAIN/CLAUDE.md"
  } > "$dst"
  ok ".cursor/rules/mastermind.mdc: full kernel inlined"
  wire_cursor_field
  wire_cursor_hook
}

wire_cursor_field() {
  local dst="$PROJECT/.cursor/rules/mastermind-field.mdc"
  local af="$BRAIN/engineering/active-field.md" field pdir
  field="$(sed -n 's/^[[:space:]]*[-*][[:space:]]*\*\*Field pack:\*\*[[:space:]]*`\([^`]*\)`.*/\1/p' "$af" 2>/dev/null | head -1)"
  field="${field%/}"; field="${field##*/}"

  # No field yet (a fresh install ships none) → nothing to inline, and a stale rule must go.
  if [ -z "$field" ] || [ ! -d "$BRAIN/engineering/fields/$field" ]; then
    if [ "$MODE" = check ]; then
      if mm_is_generated "$dst"; then
        bad ".cursor/rules/mastermind-field.mdc is left over from a field that no longer exists: re-run install.sh"
        ISSUES=$((ISSUES + 1))
      fi
      return
    fi
    mm_remove_generated "$dst" >/dev/null || rm -f "$dst" 2>/dev/null
    return
  fi
  pdir="$BRAIN/engineering/fields/$field"

  if [ "$MODE" = check ]; then
    if mm_is_generated "$dst" && grep -qF "$field" "$dst"; then
      ok ".cursor/rules/mastermind-field.mdc: $field pack inlined"
    elif [ -f "$dst" ]; then
      bad ".cursor/rules/mastermind-field.mdc does not carry the '$field' pack: re-run install.sh"
      ISSUES=$((ISSUES + 1))
    else
      bad "field pack '$field' exists but is not delivered to Cursor: re-run install.sh"
      ISSUES=$((ISSUES + 1))
    fi
    return
  fi

  local f had=0
  { printf -- '---\nalwaysApply: true\n---\n'
    printf -- '<!-- Generated by ~/.mastermind/install.sh: do not edit. Refresh with: npx mastermind-brain -->\n'
    printf -- '\n# Active field pack: %s\n\nThe stack knowledge for this project. Apply it as your default;\n' "$field"
    printf -- 'the rest of the pack (mentors, curriculum, audit rules) is on disk under\n`.mastermind/engineering/fields/%s/` and loads on demand.\n' "$field"
    for f in stack-defaults.md lessons.md; do
      [ -f "$pdir/$f" ] || continue
      printf -- '\n\n---\n\n<!-- %s -->\n\n' "$f"; cat "$pdir/$f"; had=1
    done
  } > "$dst"

  if [ "$had" = 0 ]; then rm -f "$dst"; return; fi
  local kb=$(( $(wc -c < "$dst") / 1024 ))
  ok ".cursor/rules/mastermind-field.mdc: $field pack inlined (${kb}KB)"
  [ "$kb" -gt 60 ] && warn "that pack is large for always-on context: prune it with levelup, or Cursor pays it every request"
  return 0
}

wire_cursor_hook() {
  local dst="$PROJECT/.cursor/hooks.json"
  if [ "$MODE" = check ]; then
    if [ -f "$dst" ] && grep -q 'session-start.sh' "$dst"; then ok ".cursor/hooks.json (unverified upstream)"; fi
    return 0
  fi
  command -v node >/dev/null 2>&1 || return 0
  mkdir -p "$PROJECT/.cursor"
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
      const owns=(c)=>typeof c==="string" && ((mmHooks && c.startsWith(mmHooks)) || /(^|\/)\.mastermind\/hooks\/session-start\.sh$/.test(c.trim().split(/\s+/)[0].replace(/^"|"$/g,"")));
      const mine=(e)=>owns(e&&e.command)||(e&&e.command)===cmd;
      const keep=(s.hooks[ev]||[]).filter(e=>!mine(e));
      keep.push({command: cmd});
      s.hooks[ev]=keep;
    }
    fs.writeFileSync(p, JSON.stringify(s,null,2)+"\n");
  ' 2>/dev/null \
    && ok ".cursor/hooks.json: sessionStart + preCompact (unverified upstream)" \
    || warn "left your .cursor/hooks.json alone (could not parse it)"
  return 0
}

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

  if [ "$MODE" = check ]; then
    if [ -f "$settings" ] && grep -q 'session-start.sh' "$settings"; then ok "bootstrap hook"
    else bad "bootstrap hook not registered (kernel will fade after a compaction)"; ISSUES=$((ISSUES + 1)); fi
    return 0
  fi

  if ! command -v node >/dev/null 2>&1; then
    warn "node not found: skipped the bootstrap hook (brain won't survive a compaction)"
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
    // Drop any previous MasterMind entry, then re-add: keeps other tools hooks intact.
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
    && ok "bootstrap hook: kernel re-injected on startup + compaction" \
    || warn "left your settings.json alone (could not parse it): bootstrap hook not registered"
  return 0
}

mm_link_targets_brain() {
  local t; t="$(readlink "$1")" || return 1
  case "$t" in /*) : ;; *) t="$(dirname "$1")/$t" ;; esac
  mm_inside "$REPO" "$t" || mm_inside "$BRAIN" "$t"
}

prune_dead_links() {
  local dir="$1"; [ -d "$dir" ] || return 0
  shopt -s nullglob
  local l
  for l in "$dir"/*; do
    if [ -L "$l" ] && [ ! -e "$l" ] && mm_link_targets_brain "$l"; then
      if [ "$MODE" = check ]; then bad "stale link $(basename "$l") → $(readlink "$l")"; ISSUES=$((ISSUES + 1))
      else rm -f "$l"; PRUNED=$((PRUNED + 1)); fi
    fi
  done
  shopt -u nullglob
}

remove_link() {
  local f="$1"
  if is_ours "$f"; then rm -f "$f"; ok "removed $(basename "$f")"; return 0; fi
  return 1
}

restore_backup() {
  local f="$1" bak=""
  path_exists "$f" && return 0
  [ -f "$f.mm-backup" ] || return 0
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

mm_strip_block() {
  local file="$1" tmp
  [ -f "$file" ] || return 0
  grep -qxF "$MM_START" "$file" || return 1     # exact full line, not a substring mention
  tmp="$(mktemp)"
  awk -v S="$MM_START" -v E="$MM_END" '
    $0==S && !inb { inb=1; buf=""; next }
    inb && $0==E { inb=0; next }
    inb { buf = buf $0 "\n"; next }
    { print }
    END { if (inb) printf "%s", buf }
  ' "$file" > "$tmp"
  if [ -s "$tmp" ] && grep -q '[^[:space:]]' "$tmp"; then mv "$tmp" "$file"
  else rm -f "$tmp" "$file"; fi
  return 0
}

mm_strip_anchor_dir() {
  local adir="$1" abs
  case "$adir" in ''|'*'|'.'|'**') return 0 ;; esac
  case "$adir" in /*|*\\*) return 0 ;; esac
  case "/$adir/" in */../*) return 0 ;; esac
  [ -d "$PROJECT/$adir" ] || return 0
  abs="$(mm_resolve_inside_project "$PROJECT/$adir")" || return 0
  if mm_remove_route_surface claude; then mm_strip_block "$abs/CLAUDE.md" && n=$((n + 1)) || true; fi
  if [ "$MM_REMOVE_ALL_ROUTE_SURFACES" = 1 ] || mm_remove_agents_wiring; then mm_strip_block "$abs/AGENTS.md" || true; fi
  if mm_remove_route_surface cursor; then mm_remove_generated "$abs/.cursor/rules/mastermind.mdc" >/dev/null && n=$((n + 1)) || true; fi
  return 0
}

remove_context_anchors() {
  local map="$BRAIN/routes.map"
  local glob line adir abs
  local led; led="$(mm_ledger_dirs || true)"
  for adir in $led; do mm_strip_anchor_dir "$adir"; done
  [ ${#TOOLS[@]} -eq 0 ] && rm -f "$(mm_routes_ledger)"
  [ -f "$map" ] || return 0
  while IFS= read -r line; do
    line="${line//$'\r'/}"
    case "$line" in \#*) continue ;; esac
    line="${line%%[[:space:]]#*}"; line="$(printf '%s' "$line" | awk '{$1=$1};1')"
    [ -n "$line" ] || continue
    glob="${line% *}"
    adir="${glob%/\*\*}"; adir="${adir%/\*}"; adir="${adir%/}"
    case "$adir" in ''|'*'|'.'|'**') continue ;; esac
    case "$adir" in /*|*\\*) continue ;; esac
    case "/$adir/" in */../*) continue ;; esac
    [ -d "$PROJECT/$adir" ] || continue
    abs="$(mm_resolve_inside_project "$PROJECT/$adir")" || continue
    if mm_remove_route_surface claude; then mm_strip_block "$abs/CLAUDE.md" && n=$((n + 1)) || true; fi
    if [ "$MM_REMOVE_ALL_ROUTE_SURFACES" = 1 ] || mm_remove_agents_wiring; then mm_strip_block "$abs/AGENTS.md" || true; fi
    if mm_remove_route_surface cursor; then mm_remove_generated "$abs/.cursor/rules/mastermind.mdc" >/dev/null && n=$((n + 1)) || true; fi
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

if [ "$MODE" = uninstall ]; then
  printf 'Removing MasterMind from %s%s%s…\n' "$g" "$([ "$SCOPE" = global ] && echo "global (~/.claude)" || echo "this project")" "$x"
  n=0
  if mm_wants claude; then
    remove_link "$CLAUDE_DIR/CLAUDE.md"   && n=$((n + 1))
    remove_link "$CLAUDE_DIR/engineering" && n=$((n + 1))
    shopt -s nullglob
    for l in "$CLAUDE_DIR"/skills/* "$CLAUDE_DIR"/agents/*; do remove_link "$l" && n=$((n + 1)); done
    shopt -u nullglob
  fi
  # AGENTS.md is what Codex reads, so either name owns it.
  if mm_remove_agents_wiring; then
    [ -n "$AGENTS_FILE" ] && { remove_link "$AGENTS_FILE" && n=$((n + 1)); }
  fi
  mm_wants claude && restore_backup "$CLAUDE_DIR/CLAUDE.md"
  # AGENTS.md had no restore path at all, so a preserved original stayed preserved forever.
  if mm_remove_agents_wiring; then [ -n "${AGENTS_FILE:-}" ] && restore_backup "$AGENTS_FILE"; fi
  [ "$SCOPE" = global ] && mm_wants codex && [ -n "${CODEX_GLOBAL:-}" ] && restore_backup "$CODEX_GLOBAL"
  [ "$SCOPE" = global ] && mm_wants claude && restore_backup "$CLAUDE_DIR/engineering"
  # Codex's global file is ours only when it's our symlink; remove_link leaves a real file alone.
  [ "$SCOPE" = global ] && mm_wants codex && { remove_link "$CODEX_GLOBAL" && n=$((n + 1)); }
  if [ "$SCOPE" = project ]; then
    remove_context_anchors    # keeps each app's own CLAUDE.md content
    if mm_wants cursor; then
    mm_remove_generated "$PROJECT/.cursor/rules/mastermind.mdc"       && n=$((n + 1))
    mm_remove_generated "$PROJECT/.cursor/rules/mastermind-field.mdc" && n=$((n + 1))
    restore_backup "$PROJECT/.cursor/rules/mastermind.mdc"
    restore_backup "$PROJECT/.cursor/rules/mastermind-field.mdc"
    fi
    if mm_wants gemini || [ "$MM_REMOVE_ALL_ROUTE_SURFACES" = 1 ]; then remove_link "$PROJECT/GEMINI.md" && n=$((n + 1)); fi
    if mm_wants copilot || [ "$MM_REMOVE_ALL_ROUTE_SURFACES" = 1 ]; then remove_link "$PROJECT/.github/copilot-instructions.md" && n=$((n + 1)); fi
    # Removed on filename alone until now, which destroyed any same-named file the user owned.
    if { mm_wants copilot || [ "$MM_REMOVE_ALL_ROUTE_SURFACES" = 1 ]; } && [ -f "$PROJECT/.github/hooks/mastermind.json" ]; then
      if mm_is_generated "$PROJECT/.github/hooks/mastermind.json" \
         || grep -qF 'hooks/session-start.sh' "$PROJECT/.github/hooks/mastermind.json" 2>/dev/null \
         || [ "$(tr -d '[:space:]' < "$PROJECT/.github/hooks/mastermind.json")" = '{}' ]; then
        rm -f "$PROJECT/.github/hooks/mastermind.json"; ok "removed .github/hooks/mastermind.json"; n=$((n + 1))
      else
        warn "left .github/hooks/mastermind.json alone: it is not ours"
      fi
    fi
    # Cursor's hooks.json is shared: filter our entries out rather than deleting the file.
    if mm_wants cursor && [ -f "$PROJECT/.cursor/hooks.json" ] && ! command -v node >/dev/null 2>&1; then
      warn "node is not installed, so .cursor/hooks.json was left as it is: our hook is still wired there"
      UNFINISHED=$((UNFINISHED + 1))
    fi
    if mm_wants cursor && [ -f "$PROJECT/.cursor/hooks.json" ] && command -v node >/dev/null 2>&1; then
      MM_DST="$PROJECT/.cursor/hooks.json" MM_HOOKS_DIR="$BRAIN/hooks/" node -e '
        const fs=require("fs"); const p=process.env.MM_DST, mmHooks=process.env.MM_HOOKS_DIR||"";
        let s; try { s=JSON.parse(fs.readFileSync(p,"utf8")||"{}"); } catch { process.exit(3); }
        let hit=false;
        for (const ev of Object.keys(s.hooks||{})) {
          const owns=(c)=>typeof c==="string" && ((mmHooks && c.startsWith(mmHooks)) || /(^|\/)\.mastermind\/hooks\/session-start\.sh$/.test(c.trim().split(/\s+/)[0].replace(/^"|"$/g,"")));
          const mine=(e)=>owns(e&&e.command);
          const keep=(s.hooks[ev]||[]).filter(e=>!mine(e));
          if (keep.length !== (s.hooks[ev]||[]).length) hit=true;
          if (keep.length) s.hooks[ev]=keep; else delete s.hooks[ev];
        }
        if (!hit) process.exit(1);
        fs.writeFileSync(p, JSON.stringify(s,null,2)+"\n");
      ' 2>/dev/null && _rc=0 || _rc=$?
      case "$_rc" in
        0) ok "unwired .cursor/hooks.json"; n=$((n + 1)) ;;
        1) : ;;   # nothing of ours in there
        *) warn "could not edit .cursor/hooks.json (unreadable JSON): our hook is still wired there"
           UNFINISHED=$((UNFINISHED + 1)) ;;
      esac
    fi
  fi
  if mm_wants claude && [ -f "$CLAUDE_DIR/settings.json" ] && ! command -v node >/dev/null 2>&1; then
    warn "node is not installed, so settings.json was left as it is: the bootstrap hook is still registered"
    UNFINISHED=$((UNFINISHED + 1))
  fi
  if mm_wants claude && [ -f "$CLAUDE_DIR/settings.json" ] && command -v node >/dev/null 2>&1; then
    MM_SETTINGS="$CLAUDE_DIR/settings.json" MM_HOOKS_DIR="$BRAIN/hooks/" node -e '
      const fs=require("fs"); const p=process.env.MM_SETTINGS;
      let s; try { s=JSON.parse(fs.readFileSync(p,"utf8")||"{}"); } catch { process.exit(3); }
      const list=(s.hooks||{}).SessionStart||[];
      const mmHooks=process.env.MM_HOOKS_DIR||"";
      const owns=(c)=>typeof c==="string" && ((mmHooks && c.startsWith(mmHooks)) || /(^|\/)\.mastermind\/hooks\/session-start\.sh$/.test(c.trim().split(/\s+/)[0].replace(/^"|"$/g,"")));
      const isMine=(e)=>((e&&e.hooks)||[]).some((h)=>owns(typeof (h&&h.command)==="string"?h.command.replace(/^"|"$/g,""):""));
      const keep=list.filter(e=>!isMine(e));
      if (keep.length === list.length) process.exit(1);
      if (keep.length) s.hooks.SessionStart=keep; else delete s.hooks.SessionStart;
      if (s.hooks && !Object.keys(s.hooks).length) delete s.hooks;
      fs.writeFileSync(p, JSON.stringify(s,null,2)+"\n");
    ' 2>/dev/null && _rc=0 || _rc=$?
    case "$_rc" in
      0) ok "unwired the bootstrap hook from settings.json"; n=$((n + 1)) ;;
      1) : ;;
      *) warn "could not edit settings.json (unreadable JSON): the bootstrap hook is still registered"
         UNFINISHED=$((UNFINISHED + 1)) ;;
    esac
  fi
  _cleanup_files=()
  if mm_remove_agents_wiring; then [ -n "${AGENTS_FILE:-}" ] && _cleanup_files+=("$AGENTS_FILE"); fi
  mm_wants claude && _cleanup_files+=("$CLAUDE_DIR/CLAUDE.md")
  if mm_wants gemini || [ "$MM_REMOVE_ALL_ROUTE_SURFACES" = 1 ]; then _cleanup_files+=("$PROJECT/GEMINI.md"); fi
  if mm_wants copilot || [ "$MM_REMOVE_ALL_ROUTE_SURFACES" = 1 ]; then _cleanup_files+=("$PROJECT/.github/copilot-instructions.md"); fi
  [ "$SCOPE" = global ] && mm_wants codex && [ -n "${CODEX_GLOBAL:-}" ] && _cleanup_files+=("$CODEX_GLOBAL")
  for f in ${_cleanup_files[@]+"${_cleanup_files[@]}"}; do
    [ -f "$f" ] || continue                        # symlinks are removed above, not edited
   for HINT in "$HINT_GLOBAL" "$HINT_ISOLATED" "$HINT_LEGACY_GLOBAL" "$HINT_LEGACY_ISOLATED"; do
    grep -qF "$HINT" "$f" || continue
    _pt="$(mktemp)"
      HINT="$HINT" awk 'BEGIN{h=ENVIRON["HINT"]}
        $0==h { blank=0; skip=1; next }
        { if (skip && $0=="") { skip=0; next }
          skip=0
          if (blank) { print ""; blank=0 }
          if ($0=="") { blank=1; next }
          print }
        END { if (blank) print "" }' "$f" > "$_pt"
    if [ -s "$_pt" ] && grep -q "[^[:space:]]" "$_pt"; then
      cat "$_pt" > "$f"; ok "removed the MasterMind pointer from $(basename "$f")"; n=$((n + 1))
    else
      rm -f "$f"; ok "removed $(basename "$f") (it held only our pointer)"; n=$((n + 1))
    fi
    rm -f "$_pt"
   done
  done
  _recf="$(mm_record_file)"
  if [ -f "$_recf" ] && [ ${#TOOLS[@]} -eq 0 ]; then
    rm -f "$_recf"
  elif [ -f "$_recf" ]; then
    _keep="$(sed -n 's/^tools=//p' "$_recf")"
    for _g in ${TOOLS[@]+"${TOOLS[@]}"}; do
      _keep="$(printf '%s' "$_keep" | tr ' ' '\n' | awk -v selected="$_g" '$0 != selected' | tr '\n' ' ')"
    done
    _keep="$(printf '%s' "$_keep" | sed 's/  */ /g; s/^ //; s/ $//')"
    if [ -n "$_keep" ]; then
      _tf="$(mktemp)"; sed "s|^tools=.*|tools=$_keep|" "$_recf" | grep -v '^digest=' > "$_tf"
      cat "$_tf" > "$_recf"
      printf 'digest=%s\n' "$(mm_hash "$_tf")" >> "$_recf"
      rm -f "$_tf"
    else
      rm -f "$_recf"
    fi
  fi
  if [ "${UNFINISHED:-0}" -gt 0 ]; then
    printf '\n%s⚠ removed %d link(s), but %d thing(s) could not be undone (listed above).%s\n' "$y" "$n" "$UNFINISHED" "$x"
    printf '  Fix those, then re-run:  %s --uninstall\n' "$0"
    exit 1
  fi
  printf '\n%s✓ removed %d link(s).%s Your own files were left untouched. (~/.mastermind stays; delete the clone to remove the brain.)\n' "$g" "$n" "$x"
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

if [ "$MODE" != check ]; then
  mm_link="$HOME/.mastermind"
  mm_link_real=""
  [ -e "$mm_link" ] && mm_link_real="$(cd "$mm_link" 2>/dev/null && pwd -P || true)"

  if [ "$mm_link_real" = "$REPO" ]; then
    :
  elif [ -d "$mm_link" ] && [ ! -L "$mm_link" ]; then
    printf '%s✖ %s is a different brain%s (%s).\n' "$r" "$mm_link" "$x" "${mm_link_real:-unreadable}" >&2
    printf '  Remove or move it first, then re-run: refusing to write inside someone else'"'"'s clone.\n' >&2
    exit 1
  else
    ln -sfn "$REPO" "$mm_link"
  fi
fi

if [ "$SCOPE" = project ] && [ -n "${PROJECT:-}" ]; then
  for _t in "$PROJECT/.claude" "$PROJECT/.claude/skills" "$PROJECT/.claude/agents" \
            "$PROJECT/.cursor" "$PROJECT/.cursor/rules" "$PROJECT/.mastermind" \
            "$PROJECT/.github/hooks" "$PROJECT/AGENTS.md" "$PROJECT/CLAUDE.md" \
            "$PROJECT/.claude/CLAUDE.md"; do
    mm_assert_contained "$_t"
  done
  # Files we write content into: never a symlink, wherever it points.
  for _t in "$PROJECT/.claude/settings.json" "$PROJECT/.cursor/hooks.json" \
            "$PROJECT/.cursor/rules/mastermind.mdc" "$PROJECT/.cursor/rules/mastermind-field.mdc" \
            "$PROJECT/.github/hooks/mastermind.json" "$PROJECT/.mastermind/VERSION" \
            "$PROJECT/.mastermind/.manifest" "$PROJECT/.mastermind/.installed"; do
    mm_assert_contained "$_t"
    mm_assert_real_file "$_t"
  done
  unset _t
fi

# --- Per-project sanity: need a real project dir, not the clone or ~ ----------
if [ "$SCOPE" = project ] && [ "$MODE" = install ] && { [ "$PROJECT" -ef "$REPO" ] || [ "$PROJECT" -ef "$HOME" ]; }; then
  printf 'MasterMind brain → ~/.mastermind  %s✓ ready%s\n\n' "$g" "$x"
  printf 'Now add it to a project:\n'
  printf '  cd your-project && ~/.mastermind/install.sh      (just that project: recommended)\n'
  printf '  ~/.mastermind/install.sh --global                (Claude Code, every project)\n'
  exit 0
fi

ISO_ENGINE=(CLAUDE.md AGENTS.md engineering/core skills agents hooks bin cli
            scripts/build-router.mjs scripts/check-integrity.mjs)
ISO_OWNED=(engineering/active-field.md engineering/ROUTER.md)
ISO_STATE=(VERSION routes.map .manifest .manifest.hashes .installed .routes.generated
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
  for d in "${ISO_ENGINE[@]}" "${ISO_OWNED[@]}" "${ISO_STATE[@]}"; do
    mm_assert_no_symlink_path "$dst" "$d"
  done

  local ef erel
  for d in "${ISO_ENGINE[@]}"; do
    [ -e "$REPO/$d" ] || continue
    if [ -d "$REPO/$d" ] && [ ! -L "$REPO/$d" ]; then
      while IFS= read -r ef; do
        erel="${ef#"$REPO/$d/"}"
        mm_assert_no_symlink_path "$dst" "$d/$erel"
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
      done < <(find "$REPO/$d" \( -type f -o -type l \) ! -name ABOUT.md ! -path '*/about/*')
    else
      mkdir -p "$(dirname "$dst/$d")"
      mm_preserve_engine_directory "$dst/$d" "$d"
      mm_preserve_untracked_engine_file "$dst/$d" "$d" "$HASHES"
      rm -f "$dst/${d:?}"
      cp -Rp "$REPO/$d" "$dst/$d"
      printf '%s\n' "$d" >> "$SHIPPED"
    fi
  done

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
    [ -f "$dst/$file" ] || continue
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
    local gone
    while IFS= read -r gone; do
      [ -n "$gone" ] || continue
      case "$(basename "$gone")" in lessons.md|stack-defaults.md|active-field.md|prefs.md|ROUTER.md|journal.md) continue ;; esac
      case "$gone" in engineering/fields/*) continue ;; esac
      case "$gone" in /*|*..*|*\\*) warn "manifest: refusing to act on '$gone'"; continue ;; esac
      if [ -e "$dst/$gone" ] && ! grep -qxF "$gone" "$newman"; then
        mm_assert_no_symlink_path "$dst" "$gone"
        rm -f "$dst/$gone"
      fi
    done < "$manifest"
      find "$dst" -mindepth 1 -type d -empty -delete 2>/dev/null || true
  fi

  # The manifest records the state we just installed, minus the project's own files.
  cp "$newman" "$manifest"
  rm -f "$newman" "$SHIPPED"

  printf '%s\n' "$(cat "$REPO/VERSION")" > "$dst/VERSION"
}


mm_rel_prefix() {
  local dir="$1" pfx="" part
  IFS='/' read -ra part <<< "$dir"
  for _ in "${part[@]+"${part[@]}"}"; do pfx="../$pfx"; done
  printf '%s' "$pfx"
}

mm_write_block() {
  local file="$1" body="$2" tmp kept=""
  mkdir -p "$(dirname "$file")"
  tmp="$(mktemp)"
  if [ -f "$file" ]; then
    kept="$(awk -v S="$MM_START" -v E="$MM_END" '
      $0==S && !inb { inb=1; buf=""; next }
      inb && $0==E { inb=0; next }
      inb { buf = buf $0 "\n"; next }
      { print }
      END { if (inb) printf "%s", buf }
    ' "$file")"
  fi
  [ -n "$kept" ] && printf '%s\n\n' "$kept" >> "$tmp"
  {
    printf '%s\n' "$MM_START"
    printf '<!-- generated by install.sh: edit above or below, never inside -->\n'
    printf '%s\n' "$body"
    printf '%s\n' "$MM_END"
  } >> "$tmp"
  mv "$tmp" "$file"
}

generate_context_anchors() {
  local map="$BRAIN/routes.map"
  [ -f "$map" ] || return 0
  local first_field default_field=""
  if [ -f "$BRAIN/engineering/active-field.md" ]; then
    default_field="$(sed -n 's/^## Current field: \*\*\(.*\)\*\*$/\1/p' \
      "$BRAIN/engineering/active-field.md" | head -1)"
    case "$default_field" in ''|'none yet'|none|_*) default_field="" ;; esac
    # Declared but not actually built: fall through rather than template against a missing pack.
    [ -n "$default_field" ] && [ ! -d "$BRAIN/engineering/fields/$default_field" ] && default_field=""
  fi
  case "$default_field" in *[!A-Za-z0-9_-]*)
    warn "field name '$default_field' has characters that cannot be templated: ignoring it"
    default_field="" ;;
  esac
  if [ -z "$default_field" ]; then
    first_field="$(find "$BRAIN/engineering/fields" -maxdepth 1 -mindepth 1 -type d ! -name '_*' 2>/dev/null | sort | head -1)"
    [ -n "$first_field" ] && default_field="$(basename "$first_field")"
  fi

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
    local abs="$PROJECT/$adir"
    mm_assert_contained "$abs"
    for _gt in "$abs/CLAUDE.md" "$abs/AGENTS.md" "$abs/.cursor/rules/mastermind.mdc"; do
      mm_assert_contained "$_gt"
    done
    mm_assert_real_file "$abs/.cursor/rules/mastermind.mdc"
    unset _gt
    if [ ! -d "$abs" ]; then warn "routes.map: '$glob' → no directory $adir/: skipped"; continue; fi
    if ! abs="$(mm_resolve_inside_project "$abs")"; then
      warn "routes.map: '$glob' resolves outside the project: skipped"; ISSUES=$((ISSUES + 1)); continue
    fi

    # Seed the context from the template on first use, then read the field it names.
    local cdir="$BRAIN/engineering/contexts/$ctx"
    # $ctx comes from routes.map, so the repository names this path, not us.
    mm_assert_no_symlink_path "$BRAIN" "engineering/contexts/$ctx"
    if [ ! -d "$cdir" ]; then
      local tpl="$BRAIN/engineering/_context_template"; [ -d "$tpl" ] || tpl="$REPO/engineering/_context_template"
      mkdir -p "$cdir"
      sed "s/<field>/$default_field/g; s/<name>/$ctx/g" "$tpl/field.md" > "$cdir/field.md"
      sed "s/<name>/$ctx/g" "$tpl/lessons.md" > "$cdir/lessons.md"
    fi
    local field; field="$(sed -n 's/^field:[[:space:]]*//p' "$cdir/field.md" | head -1)"; field="${field:-$default_field}"
    if [ -z "$field" ] || [ ! -d "$BRAIN/engineering/fields/$field" ]; then
      warn "context '$ctx' needs a field this brain doesn't have yet (${field:-none set}). Run init to build a field, then re-run install: skipped for now."
      ISSUES=$((ISSUES + 1)); continue
    fi

    local pfx; pfx="$(mm_rel_prefix "$adir")"
    local imports="@${pfx}.mastermind/CLAUDE.md
@${pfx}.mastermind/engineering/fields/${field}/field.md
@${pfx}.mastermind/engineering/contexts/${ctx}/field.md
@${pfx}.mastermind/engineering/contexts/${ctx}/lessons.md"

    mm_ledger_add "$adir"
    mm_write_block "$abs/CLAUDE.md" "$imports"
    mm_write_block "$abs/AGENTS.md" "$imports"
    mkdir -p "$abs/.cursor/rules"
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

if [ "$ISOLATED" = 1 ] && [ "$MODE" = install ]; then
  sync_isolated_brain
  ok "isolated brain → .mastermind/ (v$(cat "$BRAIN/VERSION")): this project's own field, lessons and stack"
  seed_routes_example
  generate_context_anchors
fi

if [ "$MODE" != check ]; then
  printf 'MasterMind → %s%s%s\n' "$g" "$([ "$SCOPE" = global ] && echo "global: every project" || echo "this project")" "$x"
fi

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
  grep -qE '^[[:space:]]*Follow .*mastermind/CLAUDE\.md' "$f"
}

is_wired() {
  local f="$1"
  is_ours "$f" || mm_has_pointer "$f"
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
      warn "no install record here: checking only what is still present, so a removed integration may go unreported"
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
    [ "$SCOPE" = global ] && { command -v codex >/dev/null 2>&1 || [ -d "$CODEX_HOME_DIR" ]; } && TOOLS+=("codex")
    if [ "$SCOPE" = project ]; then
      { command -v cursor >/dev/null 2>&1 || [ -d "$HOME/.cursor" ]; } && TOOLS+=("cursor")
      TOOLS+=("agents")
    fi
    if [ ${#TOOLS[@]} -eq 0 ]; then
      warn "No supported tool detected."
      echo "  You need an AI coding tool first: e.g. Claude Code: https://claude.com/claude-code"
    fi
  fi
fi

for tool in ${TOOLS[@]+"${TOOLS[@]}"}; do
  case "$tool" in
    claude)  wire_claude "$CLAUDE_DIR" ;;
    agents|agents.md)
      printf '\nAGENTS.md:\n'
      if [ -z "$AGENTS_FILE" ]; then warn "AGENTS.md is per-project: run this inside a project"
      else wire_brain_file "$AGENTS_FILE" "$BRAIN/AGENTS.md"; fi ;;
    cursor)
      if [ "$SCOPE" = global ]; then printf '\nCursor:\n'; warn "Cursor rules are per-project: run this inside a project"
      else printf '\nCursor:\n'; wire_cursor; fi ;;
    codex)
      printf '\nCodex:\n'
      if [ "$SCOPE" = global ]; then wire_codex_global
      else wire_brain_file "$AGENTS_FILE" "$BRAIN/AGENTS.md"; fi ;;
    gemini|copilot)
      warn "$tool is no longer wired automatically: MasterMind is plain Markdown, so point it at $([ "$ISOLATED" = 1 ] && echo '.mastermind/CLAUDE.md' || echo '~/.mastermind/CLAUDE.md') and it works the same." ;;
    *) warn "skipping unknown tool: $tool";;
  esac
done

if [ "$MODE" = install ]; then
  _rec_prev=""; _recf="$(mm_record_file)"
  [ -f "$_recf" ] && _rec_prev="$(sed -n 's/^tools=//p' "$_recf")"
  # Retired names are accepted so `--uninstall gemini` still works, but recording them made the
  # doctor expect wiring that was never created and then report the install healthy.
  _rec_all="$(printf '%s %s\n' "$_rec_prev" "${TOOLS[*]}" | tr ' ' '\n' | grep -v '^$' |
    grep -vxE 'gemini|copilot' | sort -u | tr '\n' ' ')"
  _rec_all="${_rec_all% }"
  mkdir -p "$(dirname "$_recf")"
  { printf 'version=%s\n' "$(cat "$REPO/VERSION" 2>/dev/null || echo unknown)"
    printf 'scope=%s\n' "$SCOPE"
    printf 'tools=%s\n' "$_rec_all"
    printf 'project=%s\n' "$PROJECT"
  } > "$_recf"
  # Tamper-evident, not tamper-proof: signing buys nothing against someone who can already edit
  # install.sh. This only lets the doctor say "this was edited by hand" instead of believing it.
  printf 'digest=%s\n' "$(mm_hash "$_recf")" >> "$_recf"
fi

check_routes() {
  local map="$BRAIN/routes.map"
  [ -f "$map" ] || return 0
  local glob ctx line adir field
  while IFS= read -r line; do
    line="${line//$'\r'/}"
    case "$line" in \#*) continue ;; esac
    line="${line%%[[:space:]]#*}"; line="$(printf '%s' "$line" | awk '{$1=$1};1')"
    [ -n "$line" ] || continue
    if [ "$(printf '%s' "$line" | wc -w | tr -d ' ')" -lt 2 ]; then
      bad "routes.map: '$line' is not '<glob> <context>'"; ISSUES=$((ISSUES + 1)); continue
    fi
    glob="${line% *}"; ctx="${line##* }"
    if [ ! -d "$BRAIN/engineering/contexts/$ctx" ]; then
      bad "routes.map: context '$ctx' has no dir: re-run install.sh"; ISSUES=$((ISSUES + 1)); continue
    fi
    field="$(sed -n 's/^field:[[:space:]]*//p' "$BRAIN/engineering/contexts/$ctx/field.md" 2>/dev/null | head -1)"
    [ -d "$BRAIN/engineering/fields/$field" ] || { bad "routes.map: context '$ctx' names missing field '$field'"; ISSUES=$((ISSUES + 1)); continue; }
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
        bad "route $adir/ → $ctx: $_f anchor missing: re-run install.sh"; _bad=1; continue
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
        bad "route $adir/ → $ctx: the Cursor rule is missing: re-run install.sh"; _bad=1
      fi
    fi
    if [ "$_bad" = 0 ]; then ok "route $adir/ → $ctx ($field)"
    else ISSUES=$((ISSUES + 1)); fi
  done < "$map"
}
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

if [ "$SCOPE" = project ]; then
  printf '\n%sActive in THIS project.%s  Add another: cd there && ~/.mastermind/install.sh   ·   Claude Code everywhere: --global\n' "$g" "$x"
  printf 'On another tool? It reads AGENTS.md, or point it at %s.\n' "$([ "$ISOLATED" = 1 ] && echo '.mastermind/CLAUDE.md' || echo '~/.mastermind/CLAUDE.md')"
fi
printf 'Update: cd ~/.mastermind && git pull && ~/.mastermind/install.sh   ·   Verify: ~/.mastermind/install.sh --check\n'
printf "\nDone: now RESTART your tool. (Until you restart, the brain isn't loaded yet.)\n"
