#!/bin/bash

# Remove the Omarchy Quicklinks plugin. Quicklinks you created are kept unless
# you pass --purge, since they are ordinary desktop entries.

set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$REPO_DIR/lib/menu-splice.sh"

MARKER="omarchy-quicklinks"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
PURGE=false

for arg in "$@"; do
  case "$arg" in
  --purge) PURGE=true ;;
  -h | --help)
    echo "Usage: ./uninstall.sh [--purge]"
    echo "  --purge  Also delete every quicklink you created."
    exit 0
    ;;
  *)
    echo "Unknown option: $arg" >&2
    exit 1
    ;;
  esac
done

for name in omarchy-quicklinks omarchy-launch-quicklink; do
  if [[ -e "$BIN_DIR/$name" || -L "$BIN_DIR/$name" ]]; then
    rm -f "$BIN_DIR/$name"
    echo "Removed $BIN_DIR/$name"
  fi
done

menu_splice_revert "$MARKER"
echo "Removed the Quicklinks entries from $OMARCHY_MENU_EXTENSION"

if $PURGE; then
  count=0
  while IFS= read -r -d '' file; do
    if grep -qE '^Exec=omarchy-launch-quicklink' "$file" 2>/dev/null; then
      name=$(basename "${file%.desktop}")
      icon=$(printf '%s\n' "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^[:alnum:]]\+/-/g; s/^-//; s/-$//')
      rm -f "$file"
      rm -f "$HOME/.local/share/icons/hicolor/256x256/apps/$icon.png"
      count=$((count + 1))
    fi
  done < <(find "$DESKTOP_DIR" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
  update-desktop-database "$DESKTOP_DIR" &>/dev/null || true
  echo "Deleted $count quicklink(s)"
else
  echo "Your quicklinks were kept. Re-run with --purge to delete them."
fi

if command -v omarchy >/dev/null 2>&1; then
  omarchy menu refresh >/dev/null 2>&1 || true
fi
