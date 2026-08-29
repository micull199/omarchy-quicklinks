# Implementation Plan: Omarchy "Quicklinks" Plugin

Quicklinks = named URLs that open in the **default browser** (unlike Web Apps, which open a
dedicated chromium `--app` window). Purpose: fast keyboard access to URLs by logical name.

## 0. Research findings (ground truth on this machine)

- Omarchy **4.0.1-1** is installed at `/usr/share/omarchy/` (package-owned, read-only;
  `~/.local/share/omarchy/` does not exist). All `omarchy-*` binaries are on PATH.
- **Web Apps install**: `/usr/share/omarchy/bin/omarchy-webapp-install`
  - Interactive mode uses `gum input` for `Name>` and `URL>`, auto-prefixes `https://` when the
    URL lacks a scheme (regex `^[a-zA-Z][a-zA-Z0-9+.-]*:`).
  - Icon auto-fetch via `fetch_site_icon()`: apple-touch-icon `<link>` → `<origin>/apple-touch-icon.png`
    → Google favicon service (`https://www.google.com/s2/favicons?domain=...&sz=256`). Icons land in
    `~/.local/share/icons/hicolor/256x256/apps/<safe-name>.png`, then `gtk-update-icon-cache`.
  - Writes `~/.local/share/applications/$APP_NAME.desktop` with `Exec=omarchy-launch-webapp $APP_URL`
    — **critically, arg 4 is an optional `CUSTOM_EXEC` that replaces that Exec line**, and passing an
    empty arg 3 still triggers icon auto-fetch. This lets Quicklinks reuse the entire install machinery.
- **Web Apps remove**: `/usr/share/omarchy/bin/omarchy-webapp-remove` identifies web apps by grepping
  desktop files for `^Exec=.*(omarchy-launch-webapp|omarchy-webapp-handler)`, offers a picker via
  `omarchy-menu-select`, deletes the `.desktop` + icon, notifies with `omarchy-notification-send`, runs
  `update-desktop-database`. Quicklinks with a distinct Exec marker will **not** appear in web-app
  removal — clean separation for free.
- **App-mode launch** (what we're NOT doing): `omarchy-launch-webapp` forces a chromium-family browser
  with `--app="$url"`.
- **Default-browser launch** (what we ARE doing): `/usr/share/omarchy/bin/omarchy-launch-browser`
  already exists — resolves `xdg-settings get default-web-browser`, launches via
  `systemd-run --user ... uwsm-app`, then focuses the browser window with `omarchy-hyprland-focus-app`.
  On this machine the default browser is `chromium.desktop`; `xdg-open` exists, `handlr` is **not
  installed**. `omarchy-launch-browser` is the most Omarchy-native open mechanism (better than raw
  `xdg-open`: proper systemd scoping + window focus).
- **Menu system**: the menu is the Quickshell `omarchy.menu` plugin. Definitions live in
  `/usr/share/omarchy/default/omarchy/omarchy-menu.jsonc`; user extensions go in
  `~/.config/omarchy/extensions/omarchy-menu.jsonc` (verified in
  `/usr/share/omarchy/shell/plugins/menu/Menu.qml` lines 50–51: `defaultMenuPath` / `userMenuPath`;
  user entries win, and the file hot-reloads on save). The existing entries to mirror:
  - `"install.webapp": {"icon":"","label":"Web App","action":"omarchy-launch-floating-terminal-with-presentation omarchy-webapp-install"}`
  - `"remove.webapp": {..., "when":"grep -qE '^Exec=.*(omarchy-launch-webapp|omarchy-webapp-handler)' $HOME/.local/share/applications/*.desktop", "action":"omarchy-webapp-remove"}`
- **No formal plugin API for CLI features exists.** `omarchy plugin ...` manages Quickshell *shell/bar*
  plugins (QML) only, and menu `provider`s are **hardcoded** in `Menu.qml` (`fonts`, `power-profiles`,
  plus the QML-native `apps`) — a third-party dynamic provider cannot be registered. The real
  extension points, all update-safe, are:
  1. Scripts in `~/.local/bin/` (confirmed on PATH)
  2. `~/.config/omarchy/extensions/omarchy-menu.jsonc`
  3. `.desktop` entries in `~/.local/share/applications/` (appear in the SUPER+SPACE launcher and the
     menu's `apps` provider automatically)
  4. Keybindings via `o.bind(...)` in `~/.config/hypr/bindings.lua`
     (helper source: `/usr/share/omarchy/default/hypr/helpers.lua`)
- Picker UI: `omarchy-menu-select <prompt> [options...]` (rows may be `<glyph>\t<label>`; returns
  label). `gum` and `jq` are installed.

## 1. Architecture decisions

### Storage: `.desktop` entries (recommended)

Store each quicklink as `~/.local/share/applications/<Name>.desktop` with
`Exec=omarchy-launch-quicklink <url>` as the identifying marker — exactly the web-app pattern.

- **Pros**: free fuzzy-search launcher integration (SUPER+SPACE and menu → Apps show it instantly,
  icon included); the URL is embedded in the Exec line so no second data file to keep in sync;
  remove/list flows are a one-line grep, identical to `omarchy-webapp-remove`; survives updates.
- **Cons vs. a flat data file** (e.g. `~/.config/quicklinks/quicklinks.tsv`): a data file is easier to
  bulk-edit/sync via dotfiles and is one source of truth — but it would need a custom listing UI, gets
  **no** launcher integration, and a dynamic menu submenu isn't possible anyway (providers aren't
  extensible).
- **Verdict**: `.desktop` entries. Power users can still bulk-manage them as files.

### Launch mechanism

`omarchy-launch-quicklink` (tiny wrapper): normalize scheme, then `exec omarchy-launch-browser "$url"`,
falling back to `setsid uwsm-app -- xdg-open "$url"` if `omarchy-launch-browser` is ever absent. The
wrapper exists (rather than putting `omarchy-launch-browser` directly in Exec) so the marker
`^Exec=omarchy-launch-quicklink` uniquely identifies quicklinks for list/remove flows.

### Install flow: delegate to `omarchy-webapp-install`

Phase 1 reuses the upstream script non-interactively:
`omarchy-webapp-install "$NAME" "$URL" "" "omarchy-launch-quicklink $URL"` — empty arg 3 triggers the
full icon auto-fetch chain, arg 4 swaps the Exec. This keeps UX and icon behavior byte-identical to
Web Apps. (Risk: positional-arg contract could change upstream; Phase 3 optionally vendors the
icon/desktop logic for independence.)

## 2. Repository layout

```
Quicklinks Plugin/
├── README.md                      # what it is, install, usage, keybinding snippet
├── install.sh                     # symlink bin/, patch menu jsonc, refresh menu
├── uninstall.sh                   # reverse of install.sh (+ optional purge of links)
├── bin/
│   ├── omarchy-launch-quicklink   # open URL in default browser
│   ├── omarchy-quicklink-install  # gum-driven add flow
│   ├── omarchy-quicklink-remove   # picker-driven remove flow
│   ├── omarchy-quicklink-open     # fuzzy pick a quicklink → open it   (Phase 2)
│   └── omarchy-quicklink-edit     # pick → re-prompt name/URL          (Phase 3)
└── menu/
    └── menu-entries.jsonc         # canonical copy of the entries install.sh injects
```

Scripts follow Omarchy conventions: bash, `set -e`/`set -euo pipefail`, header comments
`# omarchy:summary=` / `# omarchy:args=` (harmless outside the package, self-documenting).

## 3. Script specifications

### `bin/omarchy-launch-quicklink`

```bash
#!/bin/bash
# omarchy:summary=Open a quicklink URL in the default browser
url="$1"
[[ $url =~ ^[a-zA-Z][a-zA-Z0-9+.-]*: ]] || url="https://$url"
if command -v omarchy-launch-browser >/dev/null; then
  exec omarchy-launch-browser "$url"
else
  exec setsid uwsm-app -- xdg-open "$url"
fi
```

### `bin/omarchy-quicklink-install`

Mirrors `omarchy-webapp-install`'s interactive UX:

1. `gum input --prompt "Name> "`, `gum input --prompt "URL> "`; apply the same scheme-prefix regex.
2. **Duplicate check**: if `~/.local/share/applications/$NAME.desktop` exists, inspect it — if it's an
   existing quicklink, `gum confirm "Replace quicklink '$NAME'?"`; if it belongs to something else (a
   web app, a real app), refuse and ask for another name (prevents silently clobbering a web app,
   which upstream would do).
3. Escape `%` in the URL as `%%` (desktop-entry Exec field code rule — upstream doesn't do this; URLs
   with `%20` etc. would otherwise break).
4. Delegate: `omarchy-webapp-install "$NAME" "$URL" "" "omarchy-launch-quicklink $ESCAPED_URL"`.
5. Echo the same closing hint: "You can now find $NAME using the app launcher (SUPER + SPACE)".

Also accept non-interactive args `omarchy-quicklink-install <name> <url> [icon]` for scripting, same
as upstream.

### `bin/omarchy-quicklink-remove`

Direct adaptation of `omarchy-webapp-remove` with the grep marker changed to
`^Exec=omarchy-launch-quicklink`:

- enumerate matching `.desktop` files → sorted names → `omarchy-menu-select "Select quicklink to remove" ...`
- `rm` the desktop file and its icon (`safe_icon_name` transform: lowercase, non-alnum → `-`) from
  `~/.local/share/icons/hicolor/256x256/apps/`
- `omarchy-notification-send -g "Quicklink removed" "$NAME"`; `update-desktop-database`.

### `bin/omarchy-quicklink-open` (Phase 2)

The "type Quicklinks → pick Invoices" flow:

- grep quicklink desktop files, build rows `<glyph>\t<Name>` (e.g. a link glyph), pipe to
  `omarchy-menu-select "Quicklink"`
- extract the URL from the chosen file's `Exec=omarchy-launch-quicklink ...` line (unescape `%%`),
  `exec omarchy-launch-quicklink "$url"`.

### `bin/omarchy-quicklink-edit` (Phase 3)

Picker (same enumeration) → `gum input` prefilled via `--value` with current name/URL → remove old
entry (keep icon if name unchanged) → reinstall.

## 4. Menu integration

`install.sh` injects into `~/.config/omarchy/extensions/omarchy-menu.jsonc`, between marker comments
inserted before the closing `}` so uninstall can remove them surgically. Entries (also kept in
`menu/menu-entries.jsonc`):

```jsonc
// >>> omarchy-quicklinks (managed by Quicklinks plugin install.sh — do not edit inside)
"quicklinks": {"icon":"","label":"Quicklinks","aliases":["quicklink","links","bookmarks"],"action":"omarchy-quicklink-open"},
"install.quicklink": {"icon":"","label":"Quicklink","action":"omarchy-launch-floating-terminal-with-presentation omarchy-quicklink-install"},
"remove.quicklink": {"icon":"","label":"Quicklink","when":"grep -qE '^Exec=omarchy-launch-quicklink' $HOME/.local/share/applications/*.desktop","action":"omarchy-quicklink-remove"}
// <<< omarchy-quicklinks
```

The root `"quicklinks"` entry makes SUPER+ALT+SPACE (menu) → type "quick" → Enter → fuzzy-pick flow
work; aliases make it findable as "bookmarks" too. The file hot-reloads on save; `install.sh`
additionally runs `omarchy menu refresh`. Note also that each quicklink is *already* individually
fuzzy-searchable in the SUPER+SPACE app launcher by its own name — the fastest path of all.

> **Marker convention is shared with the Layouts plugin.** Both plugins splice into this same file,
> so the marker names must be plugin-scoped and the splice logic byte-identical in both installers.

### Optional keybinding

Documented in README (not auto-installed — `~/.config/hypr/bindings.lua` is personal config):

```lua
o.bind("SUPER + SHIFT + U", "Quicklinks", "omarchy-quicklink-open")
```

with a note to check conflicts via `omarchy menu keybindings --print` first.

## 5. Plugin install / uninstall / update-survival

**`install.sh`**:

1. `ln -sf` each `bin/*` into `~/.local/bin/` (symlinks so `git pull` in the repo updates the live
   scripts; document the tradeoff that moving the repo breaks them — offer `--copy` flag).
2. `chmod +x bin/*`.
3. Idempotently inject the marker block into `~/.config/omarchy/extensions/omarchy-menu.jsonc`
   (create the file with `{}` scaffold if missing; skip if markers already present). Back up the file
   first (`.bak.$(date +%s)`), matching skill guidance.
4. `omarchy menu refresh`.

**`uninstall.sh`**: delete the symlinks; sed out the marker block; `gum confirm "Also remove all
quicklinks?"` → if yes, remove every desktop file matching the Exec marker plus its icon;
`update-desktop-database`; `omarchy menu refresh`.

**Update survival**: every touched path is user-owned (`~/.local/bin`, `~/.local/share/applications`,
`~/.local/share/icons`, `~/.config/omarchy/extensions`) — `omarchy update` never touches them. One
documented caveat: `omarchy refresh config omarchy/extensions/omarchy-menu.jsonc` would reset the menu
file (it backs up first); re-running `install.sh` restores the entries.

## 6. Icon handling

Phase 1: inherited entirely from `omarchy-webapp-install` (apple-touch-icon → well-known path → Google
favicon, stored in `~/.local/share/icons/hicolor/256x256/apps/`, `gtk-update-icon-cache`). Interactive
fallback prompt for an icon URL/name when fetch fails also comes free. Phase 3 (optional): vendor
`fetch_site_icon`/`safe_icon_name`/`download_icon` into a `lib/icons.sh` to decouple from upstream's
positional-arg contract.

## 7. Edge cases

| Case | Handling |
|---|---|
| Duplicate quicklink name | `gum confirm` overwrite (install step 2) |
| Name collides with an existing web app / real `.desktop` | Refuse + re-prompt (upstream would silently clobber) |
| URL missing scheme | Same regex + `https://` prefix as upstream, applied in both install and launch wrapper (defense in depth) |
| Names with spaces/special chars | Fine as filenames (upstream ships `Google Maps.desktop`); icon name goes through `safe_icon_name`; names containing `/` must be rejected |
| `%` in URLs | Escape to `%%` for the Exec field; unescape in `omarchy-quicklink-open` |
| No quicklinks yet | `remove.quicklink`/root menu `when` conditions hide entries; scripts print "No quicklinks" via `omarchy-notification-send` and exit 0 |
| handlr absent / non-chromium default browser | `omarchy-launch-browser` handles any xdg default browser (incl. Firefox); `xdg-open` fallback |
| Clean uninstall | Marker-delimited menu block, symlink removal, optional purge prompt |

## 8. Phased build sequence

**Phase 1 — minimal working version** (usable end-to-end):

1. `bin/omarchy-launch-quicklink`
2. `bin/omarchy-quicklink-install` (interactive + non-interactive, delegating to `omarchy-webapp-install`)
3. `bin/omarchy-quicklink-remove`
4. `install.sh` (symlinks + menu injection of `install.quicklink` / `remove.quicklink`) and
   `menu/menu-entries.jsonc`
5. Smoke test: install "Invoices" → confirm it appears in SUPER+SPACE launcher with icon → opens in
   chromium (default browser, normal window, not `--app` mode) → remove it.

**Phase 2 — dedicated Quicklinks flow**:

6. `bin/omarchy-quicklink-open` + root `"quicklinks"` menu entry
7. `uninstall.sh`
8. `README.md` incl. optional keybinding snippet

**Phase 3 — polish**:

9. `bin/omarchy-quicklink-edit`
10. `%`-escaping + duplicate/collision guards hardened; `omarchy-quicklink-remove --all`
11. Optional: vendor icon-fetch logic into `lib/icons.sh`; `--copy` install mode

## 9. Open questions

1. **Keybinding**: should `install.sh` offer to append the `o.bind` line to
   `~/.config/hypr/bindings.lua`, or stay README-only (recommended, since that file is personal
   config)? Which key — `SUPER+SHIFT+U` is a placeholder.
2. **Desktop filename prefix**: keep upstream's raw `Name.desktop` (recommended, matches web apps), or
   prefix `quicklink-` to make collisions with web apps structurally impossible at the cost of
   divergence?
3. **Launch semantics**: always a new tab in the browser (current design), or attempt
   focus-if-already-open? Tab-level focus isn't feasible; `omarchy-launch-browser` already focuses the
   browser window after opening.
4. **Should `omarchy-quicklink-open` also be reachable as `omarchy quicklink open`?** The `omarchy` CLI
   dispatches to `omarchy-*` binaries on PATH via `omarchy:group=`/`omarchy:name=` headers — worth
   testing whether user-installed `~/.local/bin` scripts with those headers are picked up by
   `omarchy commands`.
5. **Storage divergence from Layouts**: Quicklinks stores state as `.desktop` files, Layouts stores it
   in `~/.config/omarchy/layouts/`. This is deliberate (Quicklinks wants launcher integration; Layouts
   doesn't) but worth confirming.

## Critical files for implementation

- `/usr/share/omarchy/bin/omarchy-webapp-install` — install UX, icon fetch, .desktop format,
  `CUSTOM_EXEC` arg to reuse
- `/usr/share/omarchy/bin/omarchy-webapp-remove` — remove-flow pattern to adapt
- `/usr/share/omarchy/bin/omarchy-launch-browser` — default-browser launch mechanism
- `~/.config/omarchy/extensions/omarchy-menu.jsonc` — menu integration point; format documented in-file
- `/usr/share/omarchy/default/omarchy/omarchy-menu.jsonc` — reference entries `install.webapp` /
  `remove.webapp` to mirror
