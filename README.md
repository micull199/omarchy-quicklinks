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
`omarchy restart shell` — `omarchy plugin add` reloads the plugin once per file
as it clones, and that burst can leave the shell out of step.

Remove it with `omarchy plugin remove micull199.quicklinks` (run
`bin/quicklinks menu-uninstall` first for a spotless removal).

## Three ways to reach a quicklink

**App launcher (`SUPER + SPACE`)** — type the name and press Enter. Every
quicklink is an ordinary desktop entry, exactly like an Omarchy web app, so it
is searchable alongside your applications.

**Omarchy menu** — `Quicklinks` opens the panel, `Install > Quicklink` adds one,
`Remove > Quicklink` deletes one.

**Bar icon** — click it for the searchable panel below.

## Use

Click the bar icon. The panel opens with the search box focused:

| Key | Does |
| --- | --- |
| Type | Filter by name or URL |
| `Enter` | Open the highlighted link |
| `↑` / `↓` | Move the highlight |
| `Esc` | Close |
| `Shift+Delete` | Delete the highlighted link |

The **+** button in the footer adds a link: a name, a URL, `Enter` to save. A
URL without a scheme gets `https://` prepended.

`Install > Quicklink` in the Omarchy menu does the same thing without the
panel — it asks for a name, then a URL, using the menu's own prompts.

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
erroring.

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

Entries are written by Omarchy's own `omarchy-webapp-install`, using its
documented custom-exec argument, so icon fetching (apple-touch-icon →
`/apple-touch-icon.png` → Google's favicon service) and the `.desktop` format
are upstream's, not a reimplementation. If no icon can be fetched the quicklink
is still created, with a generic themed icon.

`QuicklinksPanel.qml` is the bar widget. It shells out to `bin/quicklinks`
inside the plugin folder for everything that touches disk, so the storage rules
live in one place and are testable on their own:

```bash
bin/quicklinks list
bin/quicklinks add "Invoices" "https://books.example.com/invoices"
bin/quicklinks remove "Invoices"
bin/quicklinks menu-new         # name + URL via the menu's own prompts
bin/quicklinks pick-remove      # pick one from the menu and delete it
```

`menu-new` and `pick-remove` use the menu's prompts directly rather than the
panel, so they keep working even when the shell is out of step after an
install.

## Uninstall

`omarchy plugin remove micull199.quicklinks` deletes the plugin folder and its
`shell.json` entry. Your quicklinks stay — they're your data, and they still
work. Delete them from the panel first if you want them gone.

## See also

[Layouts](https://github.com/micull199/omarchy-layouts) — launch a named group
of apps at once.

## License

MIT. See [LICENSE](LICENSE).
