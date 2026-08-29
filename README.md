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

Remove it with `bin/quicklinks uninstall` followed by
`omarchy plugin remove micull199.quicklinks`; see [Uninstall](#uninstall).

## Three ways to reach a quicklink

**Omarchy menu / app launcher (`SUPER + SPACE`)** — type the name and press
Enter. Every quicklink is a row of its own in the menu, under `Quicklinks`: it
shows the link glyph 󰌷 (󰒃 for a private link), the name, and "Quicklinks"
beneath it in search results — not "Apps", which is what a desktop entry would
say. `Quicklinks > Manage quicklinks` opens the panel; `Install > Quicklink`
adds one and `Remove > Quicklink` deletes one (after asking).

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
A link's row runs `omarchy-launch-browser` itself rather than calling back into
the plugin, so the rows keep working if the plugin is removed — until
`menu-uninstall` takes them away — and each is guarded by `[ -f <its entry> ]`,
so a row disappears the moment its entry does. The plugin's own rows are
guarded by `[ -x bin/quicklinks ]`.

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

Each quicklink is a desktop entry in `~/.local/share/applications/<Name>.desktop`
carrying a marker key:

```ini
[Desktop Entry]
Name=Invoices
GenericName=Quicklink
Exec=omarchy-launch-browser "https://books.example.com/invoices"
Icon=invoices
Type=Application
NoDisplay=true
X-Omarchy-Quicklink=true
```

Three deliberate choices there:

- **The `Exec` line calls `omarchy-launch-browser`,** an Omarchy built-in, not
  anything owned by this plugin. So if you remove the plugin, your quicklinks
  keep working — as menu rows until you run `menu-uninstall`, and always by id
  (`gtk-launch Invoices.desktop`). Nothing is ever left dangling.
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
Google's favicon service as a last resort. Whatever it finds lands in
`~/.local/share/icons/hicolor/256x256/apps/<name>.png` and `Icon=` is patched
to point at it. If nothing can be fetched the quicklink keeps the generic icon.
`--icon NAME` skips the fetch and uses a themed icon of your choosing.

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
bin/quicklinks sync                                   # upgrade older entries, regenerate menu rows
bin/quicklinks export [FILE|DIR|-] [--force]          # write every quicklink to a JSON file
bin/quicklinks import FILE [--replace]                # read one back
bin/quicklinks menu-install
bin/quicklinks menu-uninstall
bin/quicklinks uninstall [--purge]                    # remove every trace outside the plugin folder
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

`tests/run` points every path the script uses (desktop entries, icons, menu
extension, `HOME`) at a temporary directory and stubs the tools it shells out
to (`curl`, `update-desktop-database`, `omarchy-launch-browser`, ...), so it
never reads or writes your real config and never fetches or launches anything.
The same overrides — `OMARCHY_QUICKLINKS_DESKTOP_DIR`,
`OMARCHY_QUICKLINKS_ICON_DIR`, `OMARCHY_MENU_EXTENSION` — work from your own
shell.

## Uninstall

Omarchy runs no hooks when a plugin is removed: `omarchy plugin remove` disables
the plugin in `shell.json`, deletes the plugin folder and rescans. So the plugin
carries its own cleanup command. Run it first, then remove the plugin:

```bash
~/.config/omarchy/plugins/micull199.quicklinks/bin/quicklinks uninstall
omarchy plugin remove micull199.quicklinks
```

Everything the plugin ever writes outside its own folder, and what `uninstall`
does with it:

| Written | Where | `uninstall` | `uninstall --purge` |
| --- | --- | --- | --- |
| Menu rows (marker-delimited block) | `~/.config/omarchy/extensions/omarchy-menu.jsonc` | removed; the rest of the file is untouched | same |
| The extension file itself, when none existed | same file, written as `{}` | removed, with the directory if that left it empty | same |
| One `.bak` of the menu file, plus `.bak.<epoch>` files from 1.0 | next to the menu file | removed when it holds our rows or is the `{}` we wrote; a backup written by something else is kept | same |
| One desktop entry per quicklink | `~/.local/share/applications/<Name>.desktop` | kept — your data, and still launches | removed (only entries carrying `X-Omarchy-Quicklink=true`) |
| Fetched site icons | `~/.local/share/icons/hicolor/256x256/apps/<name>.png` | kept | removed (only icons named after a quicklink), then empty parent directories |
| The plugin's enabled state | `~/.config/omarchy/shell.json` | handled by `omarchy plugin remove` | same |

`update-desktop-database` and `gtk-update-icon-cache` are run after changes so
the caches those tools own are rebuilt; the plugin writes nothing else. It
never touches `~/.config/hypr/`, adds no autostart entries, systemd units or
symlinks, and creates no directories of its own beyond the ones above.
`uninstall` is idempotent, deletes nothing it did not create, and removes a
directory only when it is empty. Without `--purge`, your quicklinks stay and
keep working because their `Exec` line calls `omarchy-launch-browser`, not the
plugin. Run `bin/quicklinks export` first if you want a copy to import later.

## See also

[Layouts](https://github.com/micull199/omarchy-layouts) — launch a named group
of apps at once.

## License

MIT. See [LICENSE](LICENSE).
