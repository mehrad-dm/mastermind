#!/usr/bin/env bash
# MasterMind one-line install / update:
#   curl -fsSL https://raw.githubusercontent.com/mehrad-dm/mastermind/master/bootstrap.sh | bash
#
# Clones the repo (or updates an existing clone) and runs the self-healing
# installer. Safe to re-run — it's how you both install and upgrade.
set -euo pipefail

REPO_URL="https://github.com/mehrad-dm/mastermind.git"
DIR="${MASTERMIND_DIR:-$HOME/mastermind}"

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

cd "$DIR"
./install.sh "$@"
