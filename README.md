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

Remove it with `omarchy plugin remove micull199.quicklinks` (run
`bin/quicklinks menu-uninstall` first for a spotless removal).

## Three ways to reach a quicklink

**App launcher (`SUPER + SPACE`)** — type the name and press Enter. Every
quicklink is an ordinary desktop entry, exactly like an Omarchy web app, so it
is searchable alongside your applications.

**Omarchy menu** — `Quicklinks` opens the panel, `Install > Quicklink` adds one,
`Remove > Quicklink` deletes one (after asking).

**Bar icon** — click it for the searchable panel below.

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

## Menu rows

The Omarchy menu is driven by a single JSONC file and has no plugin API, so the
plugin adds its rows itself: it runs `menu-install` each time it loads, which
does nothing when the rows are already correct.

```bash
bin/quicklinks menu-install     # add the three rows
bin/quicklinks menu-uninstall   # take them away again
```

It splices a marker-delimited block into
`~/.config/omarchy/extensions/omarchy-menu.jsonc`, backing the file up first.
Every row carries a `when` guard testing for this script, so if you remove the
plugin without running `menu-uninstall` the rows stop appearing rather than
erroring. `Quicklinks` and `Remove > Quicklink` additionally ask
`bin/quicklinks any`, so they only appear once there is a quicklink to show.

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
Exec=omarchy-launch-browser "https://books.example.com/invoices"
Icon=invoices
Type=Application
X-Omarchy-Quicklink=true
```

Two deliberate choices there:

- **The `Exec` line calls `omarchy-launch-browser`,** an Omarchy built-in, not
  anything owned by this plugin. So if you remove the plugin, your quicklinks
  keep working as launcher entries — you just lose the panel that manages them.
  Nothing is ever left dangling.
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
bin/quicklinks menu-install
bin/quicklinks menu-uninstall
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

`omarchy plugin remove micull199.quicklinks` deletes the plugin folder and its
`shell.json` entry. Your quicklinks stay — they're your data, and they still
work. Delete them from the panel first if you want them gone.

## See also

[Layouts](https://github.com/micull199/omarchy-layouts) — launch a named group
of apps at once.

## License

MIT. See [LICENSE](LICENSE).
