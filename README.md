# Omarchy Quicklinks

Named URLs that open in your **default browser**, reachable by name from the
Omarchy menu and the app launcher.

Omarchy already ships **Web Apps**, which install a launcher that opens a site
in a dedicated Chromium `--app` window. Quicklinks are the other half of that
idea: same install flow, same icons, same app-launcher integration, but the link
opens as a normal tab in whatever browser `xdg-settings` says is your default.

Use it for links you want to reach fast by a logical name — `Invoices`,
`Standup Notes`, `Staging` — rather than sites you want as standalone apps.

## Requirements

Omarchy 4.x. Everything else it depends on (`gum`, `omarchy-menu-select`,
`omarchy-launch-browser`, `omarchy-webapp-install`) already ships with Omarchy.

## Install

```bash
git clone <this-repo> ~/src/omarchy-quicklinks
cd ~/src/omarchy-quicklinks
./install.sh
```

`install.sh` symlinks two commands into `~/.local/bin` and adds four entries to
`~/.config/omarchy/extensions/omarchy-menu.jsonc`. Symlinks mean `git pull`
updates the installed commands; pass `--copy` if you would rather it copy them
and not depend on this checkout staying put.

Nothing is written outside `$HOME`, so `omarchy update` will not clobber it.

## Use

| What | Where |
| --- | --- |
| Add a quicklink | Menu → Install → Quicklink |
| Open one | Menu → Quicklinks, or search its name in the app launcher (SUPER + SPACE) |
| Rename / change URL | Menu → Setup → Quicklinks |
| Delete one | Menu → Remove → Quicklink |

From a terminal:

```bash
omarchy-quicklinks new "Invoices" "https://books.example.com/invoices"
omarchy-quicklinks open Invoices
omarchy-quicklinks list
omarchy-quicklinks remove Invoices
```

`new` prompts for a name and URL when you give it none. A URL without a scheme
gets `https://` prepended.

### Optional keybinding

Add to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + U", "Quicklinks", "omarchy-quicklinks open")
```

Check for a conflict first with `omarchy menu keybindings --print`. The
installer deliberately does not touch your bindings file.

## How it works

Each quicklink is an ordinary desktop entry in
`~/.local/share/applications/<Name>.desktop`:

```ini
[Desktop Entry]
Name=Invoices
Exec=omarchy-launch-quicklink "https://books.example.com/invoices"
Icon=invoices
Type=Application
```

Storing them as desktop entries means they show up in the app launcher with a
real icon for free, and the URL lives in the entry itself rather than in a
parallel data file that could drift.

The entry is written by Omarchy's own `omarchy-webapp-install`, using its
documented fourth argument to override the `Exec` line. That way icon fetching
(apple-touch-icon → `/apple-touch-icon.png` → Google's favicon service) and the
`.desktop` format stay byte-identical to Web Apps. If no icon can be fetched,
the quicklink is still created with a generic themed icon.

`omarchy-launch-quicklink` is what makes it a quicklink rather than a web app.
It hands the URL to `omarchy-launch-browser`, which resolves your default
browser, launches it under a transient systemd unit, and focuses the window.

Because the `Exec` marker differs from `omarchy-launch-webapp`, quicklinks never
appear in Omarchy's web-app removal picker, and web apps never appear in this
plugin's — the two features stay cleanly separated.

## Uninstall

```bash
./uninstall.sh            # keeps your quicklinks
./uninstall.sh --purge    # deletes them too
```

## Notes and limits

- Renaming a quicklink keeps its existing icon file, which is still named after
  the original name. Harmless, but it is why renaming never re-downloads.
- A name that collides with a non-quicklink desktop entry is refused rather than
  overwritten, so you cannot clobber a web app or a real application.
- `omarchy refresh config omarchy/extensions/omarchy-menu.jsonc` resets the menu
  extension file. Re-run `./install.sh` to restore the entries.

## See also

[Omarchy Layouts](https://github.com/micull199/omarchy-layouts) — open a whole
group of apps at once. The two plugins share the same menu-splice convention and
can be installed side by side.

## License

MIT. See [LICENSE](LICENSE).
