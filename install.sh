#!/bin/bash

# Install the Omarchy Quicklinks plugin for the current user.
#
# Everything this touches lives under $HOME, so `omarchy update` cannot clobber
# it. Safe to re-run: the menu block is replaced rather than appended.

set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$REPO_DIR/lib/menu-splice.sh"

MARKER="omarchy-quicklinks"
BIN_DIR="$HOME/.local/bin"
MODE="symlink"

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--copy]

  --copy   Copy the scripts into ~/.local/bin instead of symlinking them.
           Symlinks (the default) mean `git pull` updates the installed
           commands, but they break if you move or delete this repo.
USAGE
}

for arg in "$@"; do
  case "$arg" in
  --copy) MODE="copy" ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown option: $arg" >&2
    usage >&2
    exit 1
    ;;
  esac
done

mkdir -p "$BIN_DIR"

for script in "$REPO_DIR"/bin/*; do
  name=$(basename "$script")
  chmod +x "$script"
  if [[ $MODE == "symlink" ]]; then
    ln -sfn "$script" "$BIN_DIR/$name"
  else
    install -Dm755 "$script" "$BIN_DIR/$name"
  fi
  echo "Installed $name"
done

menu_splice_apply "$MARKER" "$REPO_DIR/menu/menu-entries.jsonc"
echo "Added the Quicklinks entries to $OMARCHY_MENU_EXTENSION"

if command -v omarchy >/dev/null 2>&1; then
  omarchy menu refresh >/dev/null 2>&1 || true
fi

case ":$PATH:" in
*":$BIN_DIR:"*) ;;
*) echo "Warning: $BIN_DIR is not on your PATH; the menu entries will not work until it is." >&2 ;;
esac

cat <<'DONE'

Quicklinks installed.

  Add one:   Menu > Install > Quicklink
  Open one:  Menu > Quicklinks, or search its name in the app launcher
DONE
