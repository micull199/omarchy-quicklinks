#!/bin/bash
# Marker-delimited splicing into the Omarchy user menu extension file.
#
# Shared verbatim between the Omarchy Quicklinks and Layouts plugins. Both write
# to the same ~/.config/omarchy/extensions/omarchy-menu.jsonc, so each owns only
# the region between its own markers and must never disturb another's. Keep this
# file byte-identical across both repos.
#
# Callers set their own `set -euo pipefail`; this library does not.

OMARCHY_MENU_EXTENSION="${OMARCHY_MENU_EXTENSION:-$HOME/.config/omarchy/extensions/omarchy-menu.jsonc}"

# Create a minimal JSONC object if the extension file does not exist yet.
menu_splice_scaffold() {
  local file="${1:-$OMARCHY_MENU_EXTENSION}"
  [[ -f $file ]] && return 0
  mkdir -p "$(dirname "$file")"
  printf '{\n}\n' >"$file"
}

# Drop an existing marker block, if present. Safe to call when absent.
menu_splice_remove() {
  local marker="$1" file="${2:-$OMARCHY_MENU_EXTENSION}"
  [[ -f $file ]] || return 0

  local tmp
  tmp=$(mktemp)
  awk -v begin="// >>> $marker" -v end="// <<< $marker" '
    index($0, begin) == 1 || $0 ~ ("^[[:space:]]*" begin "$") { skip = 1; next }
    skip && (index($0, end) == 1 || $0 ~ ("^[[:space:]]*" end "$")) { skip = 0; next }
    !skip
  ' "$file" >"$tmp" && mv "$tmp" "$file"
}

# Insert the block from entries_file immediately before the final closing brace.
menu_splice_insert() {
  local marker="$1" entries_file="$2" file="${3:-$OMARCHY_MENU_EXTENSION}"

  local tmp
  tmp=$(mktemp)
  awk -v begin="// >>> $marker" -v end="// <<< $marker" '
    NR == FNR { block[FNR] = $0; nb = FNR; next }
    { lines[FNR] = $0; nl = FNR }
    END {
      last = 0
      for (i = 1; i <= nl; i++)
        if (lines[i] ~ /^[[:space:]]*\}[[:space:]]*$/) last = i
      for (i = 1; i <= nl; i++) {
        if (i == last) {
          print "  " begin
          for (j = 1; j <= nb; j++) print block[j]
          print "  " end
        }
        print lines[i]
      }
    }
  ' "$entries_file" "$file" >"$tmp" && mv "$tmp" "$file"
}

# Full idempotent apply: scaffold, validate, back up, replace the block.
menu_splice_apply() {
  local marker="$1" entries_file="$2" file="${3:-$OMARCHY_MENU_EXTENSION}"

  menu_splice_scaffold "$file"

  if ! grep -qE '^[[:space:]]*\}[[:space:]]*$' "$file"; then
    echo "Error: $file has no closing brace on a line of its own." >&2
    echo "Refusing to edit it. Fix the file by hand, then re-run." >&2
    return 1
  fi

  cp "$file" "$file.bak.$(date +%s)"
  menu_splice_remove "$marker" "$file"
  menu_splice_insert "$marker" "$entries_file" "$file"
}

# Remove the block and report whether the file still holds any entries.
menu_splice_revert() {
  local marker="$1" file="${2:-$OMARCHY_MENU_EXTENSION}"
  [[ -f $file ]] || return 0
  cp "$file" "$file.bak.$(date +%s)"
  menu_splice_remove "$marker" "$file"
}
