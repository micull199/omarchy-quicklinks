# Quicklinks

An Omarchy shell plugin. Named URLs that open in your **default browser**,
searchable from a bar icon.

Omarchy's built-in **Web Apps** install a launcher that opens a site in a
dedicated Chromium `--app` window. Quicklinks are the other half of that idea:
the link opens as a normal tab in whatever browser `xdg-settings` says is your
default. Use it for links you want to reach fast by a logical name — `Invoices`,
`Standup Notes`, `Staging`.

## Install

```bash
omarchy plugin add https://github.com/micull199/omarchy-quicklinks --enable
```

Omarchy asks which bar section to put the icon in. The menu rows install
themselves the first time the plugin loads. If they don't appear, run
`omarchy restart shell`.

Remove it with `bin/quicklinks uninstall --remove-plugin`; see
[Uninstall](#uninstall).

## Three ways to reach a quicklink

**Omarchy menu / app launcher (`SUPER + SPACE`)** — type the name and press
Enter. Every quicklink is a row of its own in the menu, under `Quicklinks`: it
shows the link glyph 󰌷 (󰒃 for a private link), the name, and "Quicklinks"
beneath it in search results — not "Apps", which is what a desktop entry would
say. `Quicklinks > Manage quicklinks` opens the panel; `Install > Quicklink`
adds one, `Remove > Quicklink` deletes one (after asking) and
`Remove > Quicklinks plugin` removes the plugin itself with everything it owns.

**Bar icon** — click it for the searchable panel below.

**Keyboard** — bind the panel directly; see below.

## Use

Click the bar icon. The panel opens with the search box focused:

| Key | Does |
| --- | --- |
| Type | Filter by name or URL |
| `Enter` | Open the highlighted link |
| `↑` / `↓` | Move the highlight |
| `Ctrl+N` | New quicklink (opens the builder) |
| `Ctrl+E` | Edit the highlighted link |
| `Ctrl+C` | Copy the highlighted link's URL to the clipboard |
| `Ctrl+S` | Export every quicklink to a JSON file (see below) |
| `Del` | Delete the highlighted link, after a confirmation |
| `Esc` | Close |

Each row shows the site's icon, its name and URL, and a lock glyph when the
link opens in a private window.

### Building a quicklink

The footer's new button, `Ctrl+N`, or `Install > Quicklink` in the menu opens
the builder; the pencil button or `Ctrl+E` opens it with the highlighted link
filled in. It is meant to be driven from the keyboard:

| Key | Does |
| --- | --- |
| `Enter` | In the name field: move to the URL field. In the URL field: save |
| `Ctrl+Enter` | Save from anywhere |
| `Ctrl+P` | Flip "Open in a private window" |
| `Esc` | Cancel |

A URL without a scheme gets `https://` prepended. Names are trimmed and cannot
contain `/`, control characters or start with a dot; adding a name that already
exists is refused, and so is renaming onto one. If saving fails the builder
stays open with your input so you can fix it and try again.

`Install > Quicklink` in the Omarchy menu does the same thing without the
panel — it asks for a name, then a URL, using the menu's own prompts.

### Private links

Tick **Open in a private window** (or `Ctrl+P`) and the link opens in the
browser's private or incognito window instead of a normal tab. The desktop
entry carries a second marker, `X-Omarchy-Quicklink-Private=true`, and its
`Exec` passes `--private` to `omarchy-launch-browser`, which maps that to
whatever the default browser calls it (`--incognito`, `--private-window`,
`--inprivate`). Panel rows show these links with a lock glyph.

### Export and import

The footer's export button, or `Ctrl+S`, writes every quicklink to
`~/Downloads/omarchy-quicklinks-<date>.json` (or `~` when there is no Downloads
folder) and shows the path in the panel. From a shell you can pick the file:

```bash
bin/quicklinks export                      # ~/Downloads/omarchy-quicklinks-2026-08-29.json
bin/quicklinks export ~/backups/links.json # a path of your own; refuses to overwrite
bin/quicklinks export ~/backups/           # a directory: the default name inside it
bin/quicklinks export --force              # overwrite an existing file
bin/quicklinks export -                    # to stdout
bin/quicklinks import links.json           # add what is missing, skip existing names
bin/quicklinks import links.json --replace # overwrite existing quicklinks of the same name
```

The file is plain JSON, made to be read by hand or by other tools:

```json
{
  "format": "omarchy-quicklinks",
  "version": 1,
  "exported": "2026-08-29T13:00:00Z",
  "quicklinks": [
    { "name": "Invoices", "url": "https://books.example.com/invoices", "private": false },
    { "name": "Wiki", "url": "https://wiki.example.com", "private": false, "icon": "help-browser" }
  ]
}
```

`icon` is only present when you chose a themed icon with `--icon`; icons the
plugin fetched from the site are not exported, and `import` fetches them again.
`import` also accepts a bare JSON array of `{name, url, private?, icon?}`
objects, validates each row the way `add` does, and prints
`imported N skipped M`. Both commands need `jq`, which Omarchy ships.

## Menu rows

The Omarchy menu is driven by a single JSONC file and has no plugin API, so the
plugin adds its rows itself: a `Quicklinks` submenu holding `Manage quicklinks`
and one row per link, plus `Install > Quicklink` and `Remove > Quicklink`. The
rows are regenerated whenever a link is added, edited or removed, and each time
the panel opens (`bin/quicklinks sync`), which touches nothing when they are
already correct.

```bash
bin/quicklinks menu-install     # (re)write the rows
bin/quicklinks menu-uninstall   # take them away again
```

It splices a marker-delimited block into
`~/.config/omarchy/extensions/omarchy-menu.jsonc`, backing the file up first.
Every row in the block — the submenu, its children and each per-link row — is
guarded by the same `when`: `[ -x <plugin folder>/bin/quicklinks ]`. Delete
the plugin folder and every row vanishes on the next menu open, with nothing to
clean up. A link's row runs `omarchy-launch-browser` itself rather than calling
back into the plugin, so opening a link never depends on the script running.

The Layouts plugin writes to the same file inside its own markers; the two
blocks are independent and neither disturbs the other.

### Opening it from the keyboard

The panel registers an IPC target, so you can bind it in
`~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + U", "Quicklinks", "omarchy-shell micull199.quicklinks toggle")
```

Check for conflicts first with `omarchy menu keybindings --print`.

## How it works

Everything the plugin owns lives inside the plugin folder, under `data/`
(git-ignored, so `omarchy plugin update` keeps it):

```
~/.config/omarchy/plugins/micull199.quicklinks/
├── bin/quicklinks
├── data/applications/<Name>.desktop      the real desktop entry
└── data/icons/<slug>.png                 the icon fetched for it
~/.local/share/applications/omarchy-quicklink-<Name>.desktop
                                          a symlink to the entry above
```

Each quicklink is a desktop entry carrying a marker key, reached by the
launcher through the symlink (the prefix makes the symlink unmistakably ours;
the visible `Name=` is the plain name):

```ini
[Desktop Entry]
Name=Invoices
GenericName=Quicklink
Exec=omarchy-launch-browser "https://books.example.com/invoices"
Icon=/home/you/.config/omarchy/plugins/micull199.quicklinks/data/icons/invoices.png
Type=Application
NoDisplay=true
X-Omarchy-Quicklink=true
```

Three deliberate choices there:

- **The `Exec` line calls `omarchy-launch-browser`,** an Omarchy built-in, not
  anything owned by this plugin, so launching never depends on the plugin's
  code running. The entry stays launchable by id
  (`gtk-launch omarchy-quicklink-Invoices`).
- **`NoDisplay=true` keeps the entry out of the app list.** The link is reached
  through its menu row instead, which has an icon and reads "Quicklinks" rather
  than "Apps"; a second row for the same link would only be noise. Other
  launchers that read `~/.local/share/applications` will not list quicklinks.
- **`X-Omarchy-Quicklink=true` is the marker,** rather than the `Exec` command.
  That keeps quicklinks and Omarchy web apps cleanly separate: neither shows up
  in the other's list.

The plugin writes the entry itself, with the same keys `omarchy-webapp-install`
uses, so to the launcher a quicklink is indistinguishable from a web app and
only differs in how it opens the URL. A private link's `Exec` is
`omarchy-launch-browser --private "URL"`.

The URL is always one double-quoted argument, and an `Exec` key is parsed
twice, so it is encoded twice. The desktop-file string layer only understands
`\\`; the Exec layer beneath it allows `\"`, `` \` ``, `\$` and `\\` inside
double quotes and wants a literal `%` written as `%%`. So a `"` in a URL ends
up as `\\"` in the file, and every launcher (Omarchy's shell, `gtk-launch`,
GLib) unwinds both layers before the browser sees it. URLs holding quotes,
spaces, `$` or `%` are all fine; the test suite checks GLib reads every
generated entry back to the raw URL.

The icon never holds up the add. The entry is written instantly with the
themed `web-browser` icon, then `fetch-icon` runs detached in the background:
the site's own apple-touch-icon link, then `/apple-touch-icon.png`, then
Google's favicon service as a last resort. Whatever it finds lands in `data/icons/<slug>.png` and `Icon=` is patched to
that absolute path — the icon theme directories under `~/.local/share/icons`
are never touched. If nothing can be fetched the quicklink keeps the generic
icon. `--icon NAME` skips the fetch and uses a themed icon of your choosing.

### What happens on `omarchy plugin remove`

Omarchy runs no plugin hooks: `omarchy plugin remove` disables the plugin in
`shell.json`, deletes the plugin folder and rescans. The layout above is
designed so that this alone leaves nothing functional behind:

- **Desktop entries.** The real files were in the folder, so they are gone.
  The symlinks in `~/.local/share/applications` now dangle. Quickshell's
  desktop-entry scanner (`src/core/desktopentry.cpp`) does
  `if (!file.open(QFile::ReadOnly)) { qCDebug(...) << "Could not open file"; continue; }`
  — an unreadable entry is skipped, not shown. GLib (`gtk-launch`, GNOME) and
  `update-desktop-database` likewise cannot parse a file that does not exist,
  so the launcher drops every quicklink at once. The test suite checks both.
- **Icons.** Also in the folder, so gone, and nothing references them.
- **Menu rows.** Every row's `when` guard tests for `bin/quicklinks` in the
  plugin folder, so the whole block stops appearing. The text stays in the
  menu file until the plugin is reinstalled (which rewrites it) or
  `uninstall` runs; it is inert.

What does remain is inert: dangling symlinks and a dormant block of JSONC. If
you reinstall the plugin, its first load prunes any dangling
`omarchy-quicklink-*.desktop` symlinks and rewrites the block. For a removal
that leaves not even those, use `bin/quicklinks uninstall --remove-plugin`
(see [Uninstall](#uninstall)).

The first load after upgrading from 1.3 or earlier migrates the old layout:
regular marked `.desktop` files in `~/.local/share/applications` move into
`data/applications/` with a symlink left in their place, their icons move from
`~/.local/share/icons/hicolor/256x256/apps/` into `data/icons/` with `Icon=`
rewritten, and directories that emptied are removed. It is idempotent and runs
from `sync` every time the panel opens.

`QuicklinksPanel.qml` is the bar widget. It shells out to `bin/quicklinks`
inside the plugin folder for everything that touches disk, so the storage rules
live in one place and are testable on their own:

```bash
bin/quicklinks list                                   # name, url, icon, private — tab-separated
bin/quicklinks add "Invoices" "https://books.example.com/invoices"
bin/quicklinks add "Bank" bank.example.com --private  # opens in a private window
bin/quicklinks add "Wiki" wiki.example.com --icon help-browser
bin/quicklinks edit "Invoices" --name "Books"         # rename; the fetched icon follows
bin/quicklinks edit "Books" --url "https://books.example.com/new"
bin/quicklinks edit "Books" --private                 # or --no-private
bin/quicklinks info "Books"                           # url, icon, private — one "key<TAB>value" per line
bin/quicklinks remove "Books"
bin/quicklinks open "Books"                           # what the panel's Enter does
bin/quicklinks any                                    # exit 0 when at least one quicklink exists
bin/quicklinks fetch-icon "Books" "https://books.example.com/new"
bin/quicklinks menu-new                               # name + URL via the menu's own prompts
bin/quicklinks pick-remove                            # pick one from the menu and delete it
bin/quicklinks menu-uninstall-plugin                  # confirm, then uninstall --remove-plugin
bin/quicklinks sync                                   # migrate, heal symlinks, regenerate menu rows
bin/quicklinks export [FILE|DIR|-] [--force]          # write every quicklink to a JSON file
bin/quicklinks import FILE [--replace]                # read one back
bin/quicklinks menu-install
bin/quicklinks menu-uninstall
bin/quicklinks uninstall [--keep-quicklinks] [--remove-plugin]  # remove every trace outside the plugin folder
```

`edit` takes any combination of `--name`, `--url`, `--private` and
`--no-private`; unchanged values are no-ops. A URL change to a different host
starts a fresh icon fetch. `menu-new` and `pick-remove` use the menu's prompts
directly rather than the panel, so they keep working even when the shell is out
of step after an install.

## Development

```bash
tests/run              # backend test suite
bash -n bin/quicklinks # syntax check
```

`tests/run` points every path the script uses (the data dir, the launcher
symlink dir, the legacy icon dir, the menu extension, `HOME`) at a temporary
directory and stubs the tools it shells out to (`curl`,
`update-desktop-database`, `omarchy-launch-browser`, `gum`, ...), so it never
reads or writes your real config and never fetches or launches anything. The
same overrides — `OMARCHY_QUICKLINKS_DATA_DIR`, `OMARCHY_QUICKLINKS_ICON_DIR`,
`OMARCHY_QUICKLINKS_DESKTOP_DIR`, `OMARCHY_QUICKLINKS_LEGACY_ICON_DIR`,
`OMARCHY_MENU_EXTENSION` — work from your own shell.

## Uninstall

A bare `omarchy plugin remove micull199.quicklinks` is safe (see
[above](#what-happens-on-omarchy-plugin-remove)): the entries and icons go with
the folder, the symlinks dangle harmlessly and the menu rows stop showing. For
a removal that leaves not even the inert leftovers, run the plugin's own
cleanup — from the panel's trash-can button, from `Remove > Quicklinks plugin`
in the menu (both ask first), or by hand. It deletes your quicklinks, so
**export first** if you may want them back:

```bash
Q=~/.config/omarchy/plugins/micull199.quicklinks/bin/quicklinks
$Q export                        # ~/Downloads/omarchy-quicklinks-<date>.json
$Q uninstall --remove-plugin     # remove every trace, then the plugin itself
```

`--remove-plugin` finishes with `omarchy plugin remove micull199.quicklinks
--yes`; leave it off to run that step yourself. `--keep-quicklinks` leaves
`data/` and the symlinks in place, so the links stay launchable until the
plugin folder itself is removed.

Everything the plugin writes, and what `uninstall` does with it:

| Written | Where | `uninstall` | `--keep-quicklinks` |
| --- | --- | --- | --- |
| Real desktop entries and fetched icons | `<plugin>/data/` | deleted | kept |
| Launcher symlinks `omarchy-quicklink-<Name>.desktop` | `~/.local/share/applications/` | removed (only symlinks into the plugin's data dir), then the directory if that emptied it | kept |
| Menu rows (marker-delimited block) | `~/.config/omarchy/extensions/omarchy-menu.jsonc` | removed; the rest of the file is untouched | same |
| The extension file itself, when none existed | same file, written as `{}` | removed, with the directory if that left it empty | same |
| One `.bak` of the menu file, plus `.bak.<epoch>` files from 1.0 | next to the menu file | removed when it holds our rows or is the `{}` we wrote; a backup written by something else is kept | same |
| Pre-1.4 entries and icons | `~/.local/share/applications/<Name>.desktop`, `~/.local/share/icons/hicolor/256x256/apps/` | migrated into `data/` first, then handled as above | migrated |
| The plugin's enabled state | `~/.config/omarchy/shell.json` | handled by `omarchy plugin remove` | same |

`update-desktop-database` is run after changes so the cache it owns is rebuilt;
the plugin writes nothing else. It never touches `~/.config/hypr/`, adds no
autostart entries, systemd units or files in `~/.local/bin`, and creates no
directories outside its folder beyond the ones above. `uninstall` is
idempotent, deletes nothing it did not create, and removes a directory only
when it is empty. To bring an exported list back after a reinstall, run
`bin/quicklinks import <file>`.

## See also

[Layouts](https://github.com/micull199/omarchy-layouts) — launch a named group
of apps at once.

## License

MIT. See [LICENSE](LICENSE).
