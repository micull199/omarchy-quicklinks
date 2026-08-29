# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 1.2.0 — 2026-08-29

### Changed

- Quicklinks now appear in the Omarchy menu as their own rows under a
  `Quicklinks` submenu, with the link glyph (a lock for private links) and
  "Quicklinks" shown beneath them in search results instead of "Apps". Each row
  launches the URL directly, so it keeps working without the plugin. Desktop
  entries are written with `NoDisplay=true` so the launcher does not show the
  same link twice; they remain launchable by id.
- The top-level `Quicklinks` menu row is now a submenu; the panel is opened from
  `Quicklinks > Manage quicklinks`.

### Added

- `sync`: upgrades entries written by older versions and regenerates the menu
  rows. The panel runs it on open.

## 1.1.0 — 2026-08-29

### Fixed

- A URL containing `"` produced a desktop entry that both launchers rejected:
  the quote was escaped for the Exec layer only, so after the desktop-file
  string layer decoded it the argument was unbalanced and Quickshell's parser
  dropped the entry. The URL is now encoded through both layers (`\\"` in the
  file), and the test suite checks GLib reads every generated entry back to
  the raw URL. Entries written by 1.0.0 still decode.
- Stricter name validation: names are trimmed, and control characters are
  rejected alongside `/` and a leading dot.
- Adding a quicklink whose name already exists is refused instead of silently
  overwriting it.
- The add form no longer discards your input when the backend fails; the
  builder stays open with the error so it can be retried.
- Deleting a quicklink asks for confirmation.
- Footer buttons rendered as unrelated glyphs and the bar icon was the Chrome
  logo, which suggested the plugin was tied to one browser. They now use the
  Material Design block the rest of the shell uses, and the bar shows a link.

### Added

- Edit (pencil button, `Ctrl+E`): rename, change the URL, or flip the private
  option in one atomic `edit` call. Renaming keeps the fetched icon.
- "Open in a private window" (`--private`, `Ctrl+P` in the builder): the entry
  carries `X-Omarchy-Quicklink-Private=true` and its Exec passes `--private`
  to `omarchy-launch-browser`. Private links show a lock glyph in the panel.
- Site icons in the panel rows.
- `Ctrl+C` copies the highlighted link's URL to the clipboard.
- Keyboard-first builder: Enter moves from name to URL and saves from URL,
  Ctrl+Enter saves, Ctrl+P toggles private, Esc cancels. List view gains
  Ctrl+N, Ctrl+E and Ctrl+C.
- Adding is instant: the entry is written with the themed `web-browser` icon
  and the icon fetch (apple-touch-icon → `/apple-touch-icon.png` → Google
  favicon) runs detached, patching `Icon=` when it lands. `add --icon NAME`
  skips the fetch.
- `info`, `edit`, `open`, `any` and `fetch-icon` backend commands; `list`
  gains a fourth `private` column.
- Backend test suite (`tests/run`), running entirely in a temporary directory.
- `OMARCHY_QUICKLINKS_DESKTOP_DIR` and `OMARCHY_QUICKLINKS_ICON_DIR` overrides,
  alongside the existing `OMARCHY_MENU_EXTENSION`.

### Changed

- The plugin writes desktop entries itself and no longer depends on
  `omarchy-webapp-install`.
- The `Quicklinks` and `Remove > Quicklink` menu rows are guarded by
  `bin/quicklinks any`, so they only appear once a quicklink exists.
- Delete moved from `Shift+Delete` to `Del`, with a confirmation.
- README: the install note no longer misdescribes how `omarchy plugin add`
  works.

## 1.0.0 — 2026-08-29

Initial release: named URLs opened in the default browser from the bar panel,
the Omarchy menu or the app launcher, stored as marked desktop entries written
through `omarchy-webapp-install`.
