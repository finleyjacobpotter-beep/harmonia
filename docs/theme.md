# Theme

Colours, icons and wallpaper.


## Colours

`theme/miami-wind.nix` holds the palette from
[hanakin/miami-wind-vscode](https://github.com/hanakin/miami-wind-vscode):
editor background `#1e1e2e`, foreground `#cdd6f4`, accent pink `#f472b6`,
secondary cyan `#22d3ee`, and the theme's `terminal.ansi*` colours for the
16-colour palette (used by alacritty, the Linux console, ranger and tuigreet).

## Icons

Tulasi is the only icon theme. Instead of upstream's breeze/Adwaita
fallback, every icon Tulasi doesn't draw resolves to one of its own generic
icons (`pkgs/tulasi-icon-theme.nix`): apps → the purple "?" tile, files →
a document, folders → a folder, hardware → a computer, anything else → "?".
This covers every standard icon name and every `Icon=` in the desktop files
of installed packages, so the theme is rebuilt when your package set changes.

**Inside the Firefox sandbox** the same icons are used without opening the jail:
Tulasi is copied (as real files) into Firefox's own private data dir,
`~/.var/app/org.mozilla.firefox/data/icons`, and a sandbox-local
`config/gtk-3.0/settings.ini` selects it. Firefox already owns that directory, so
no flatpak permission is added. The copy is the generic build, without the
list of your installed programs. Firefox's launcher icon, notifications and file
picker are drawn on the host and use Tulasi anyway.

## Wallpaper

`assets/wallpaper.png` is scaled to fit and centred on the background colour `#1e1e2e`.
It was recoloured to the Miami Wind palette with
[lutgen](https://github.com/ozwaldorf/lutgen-rs), using every colour in
`theme/miami-wind.nix`:

```
lutgen apply -P -L 0.5 -o wallpaper.png original.jpg -- <palette colours>
```

and its black outer margin was then flood-filled with `#1e1e2e` so the image
blends into the background.
