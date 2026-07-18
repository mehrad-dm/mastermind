#!/usr/bin/env bash
# MasterMind one-line install / update. Run it FROM INSIDE a project to wire that
# project (the default, per-project scope); add --global for every project:
#   cd my-project && curl -fsSL https://raw.githubusercontent.com/mehrad-dm/mastermind/master/bootstrap.sh | bash
#   curl -fsSL …/bootstrap.sh | bash -s -- --global
#
# Clones the repo (or updates an existing clone) and runs the self-healing
# installer. Safe to re-run — it's how you both install and upgrade.
set -euo pipefail

REPO_URL="https://github.com/mehrad-dm/mastermind.git"
DIR="${MASTERMIND_DIR:-$HOME/mastermind}"
ORIG_PWD="$PWD"   # where the user ran the one-liner — the project to wire (default scope)

if ! command -v git >/dev/null 2>&1; then
  echo "✖ git is required. Install git, then re-run." >&2; exit 1
fi

if [ -d "$DIR/.git" ]; then
  echo "→ Updating MasterMind in $DIR"
  git -C "$DIR" pull --ff-only
else
  echo "→ Cloning MasterMind → $DIR"
  git clone --depth 1 "$REPO_URL" "$DIR"
fi

# Run the installer from the directory the user invoked us in, so per-project
# wiring targets THAT project (install.sh itself lives in $DIR).
cd "$ORIG_PWD"
"$DIR/install.sh" "$@"
