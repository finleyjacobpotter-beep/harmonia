# Theming for the flatpak'd Zen browser (installed in modules/nixos/flatpak.nix).
#
# The sandbox can't follow symlinks into /nix/store, so everything here is
# *copied* into the app's own data dir (~/.var/app/app.zen_browser.zen) and into
# ~/.local/share/fonts, which flatpak exposes to apps as /run/host/user-fonts.
{
  pkgs,
  lib,
  palette,
  ...
}:
let
  p = palette;
  pyScript = import ../lib/python-script.nix { inherit pkgs lib; };

  userChrome = pkgs.writeText "userChrome.css" ''
    /* Miami Wind for Zen */
    :root {
      --zen-primary-color: ${p.pink} !important;
      --zen-colors-primary: ${p.surface} !important;
      --zen-colors-secondary: ${p.surfaceHi} !important;
      --zen-colors-tertiary: ${p.bgAlt} !important;
      --zen-colors-border: ${p.pink} !important;
      --zen-colors-hover-bg: ${p.surface} !important;
      --zen-main-browser-background: ${p.bgDark} !important;
      --zen-main-browser-background-toolbar: ${p.bgDark} !important;
      --zen-themed-toolbar-bg: ${p.bgDark} !important;
      --zen-dialog-background: ${p.bgAlt} !important;
      --zen-urlbar-background: ${p.bg} !important;

      --toolbar-bgcolor: ${p.bgDark} !important;
      --toolbar-color: ${p.fg} !important;
      --toolbar-field-background-color: ${p.bg} !important;
      --toolbar-field-color: ${p.fg} !important;
      --toolbar-field-focus-background-color: ${p.bg} !important;
      --toolbar-field-focus-color: ${p.fg} !important;
      --toolbar-field-focus-border-color: ${p.pink} !important;
      --lwt-accent-color: ${p.bgDark} !important;
      --lwt-text-color: ${p.fg} !important;
      --tab-selected-bgcolor: ${p.surface} !important;
      --tab-selected-textcolor: ${p.fg} !important;
      --arrowpanel-background: ${p.bgAlt} !important;
      --arrowpanel-color: ${p.fg} !important;
      --arrowpanel-border-color: ${p.surface} !important;
      --focus-outline-color: ${p.pink} !important;
      --button-primary-bgcolor: ${p.pink} !important;
      --button-primary-color: ${p.bgDark} !important;
      --color-accent-primary: ${p.pink} !important;
      --urlbarView-highlight-background: ${p.surface} !important;
      --urlbarView-highlight-color: ${p.fg} !important;

      font-family: "${p.font.name}", monospace !important;
    }

    ::selection {
      background-color: ${p.pink} !important;
      color: ${p.bgDark} !important;
    }
  '';

  userContent = pkgs.writeText "userContent.css" ''
    @-moz-document url-prefix("about:") {
      :root {
        --in-content-page-background: ${p.bg} !important;
        --in-content-page-color: ${p.fg} !important;
        --in-content-box-background: ${p.bgAlt} !important;
        --in-content-primary-button-background: ${p.pink} !important;
        --in-content-primary-button-text-color: ${p.bgDark} !important;
        --in-content-accent-color: ${p.pink} !important;
        --newtab-background-color: ${p.bg} !important;
        --newtab-background-color-secondary: ${p.bgAlt} !important;
        --newtab-text-primary-color: ${p.fg} !important;
        --color-accent-primary: ${p.pink} !important;
      }
    }
  '';

  userJs = pkgs.writeText "user.js" ''
    // Managed by home-manager (home/zen.nix) — changes here are overwritten.
    user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
    user_pref("layout.css.prefers-color-scheme.content-override", 0);
    user_pref("ui.systemUsesDarkTheme", 1);
    user_pref("zen.theme.accent-color", "${p.pink}");
    user_pref("browser.display.background_color.dark", "${p.bg}");
    user_pref("font.name.monospace.x-western", "${p.font.mono}");
    user_pref("font.name.sans-serif.x-western", "${p.font.name}");
    user_pref("font.name.serif.x-western", "${p.font.name}");
    user_pref("font.default.x-western", "sans-serif");
    user_pref("widget.use-xdg-desktop-portal.file-picker", 1);

    // Keyboard: enable the side-loaded Vimium without a prompt, and keep
    // Firefox features that eat bare keys out of Vimium's way.
    user_pref("extensions.autoDisableScopes", 0);
    user_pref("extensions.enabledScopes", 15);
    user_pref("accessibility.typeaheadfind", false);
    user_pref("accessibility.typeaheadfind.manual", false);
    user_pref("ui.key.menuAccessKeyFocuses", false);
    user_pref("browser.tabs.warnOnClose", false);
  '';

  font = pkgs.nerd-fonts.departure-mono;

  # Vimium: vim keys for the web (j/k scroll, f link hints, J/K tabs, H/L
  # history, o/O open, T tab search, / find, x/X close/restore tab, ? help).
  # Pinned as in nix-community's firefox-addons (rycee/nur-expressions).
  vimium = {
    id = "{d7742d87-e61d-4b78-b8a1-b469842139fa}";
    xpi = pkgs.fetchurl {
      url = "https://addons.mozilla.org/firefox/downloads/file/4717567/vimium_ff-2.4.2.xpi";
      sha256 = "131e2a67580e7ae9125ab19781159e61409fac47b441fc2782aab76396ead196";
    };
  };

  # Icons inside the sandbox. Zen may read and write its own
  # ~/.var/app/app.zen_browser.zen, and GTK in the sandbox looks for icon
  # themes in its data/icons (XDG_DATA_HOME) and reads its config/gtk-3.0
  # (XDG_CONFIG_HOME). So Tulasi goes there — no new flatpak permission.
  # This is the *generic* build (no appPackages): the per-machine build lists
  # every installed program's icon name, which the browser has no need to see.
  tulasi = pkgs.tulasi-icon-theme;

  gtkSettings = pkgs.writeText "zen-gtk3-settings.ini" ''
    [Settings]
    gtk-icon-theme-name=Tulasi
    gtk-application-prefer-dark-theme=1
    gtk-font-name=${p.font.name} ${toString (p.font.size - 1)}
  '';

  sync = pyScript "zen-miami-wind" { } ''
    """Copy the Miami Wind theme into the Zen flatpak's own data dir: Tulasi
    icons, GTK settings, and userChrome.css, userContent.css, user.js and
    Vimium into every Zen profile."""

    import os
    import shutil
    import sys
    import tempfile
    from pathlib import Path

    TULASI = "${tulasi}"
    APP = Path.home() / ".var/app/app.zen_browser.zen"


    def install(src: str, dest: Path) -> None:
        """A real, writable copy (install -Dm644), replacing whatever is there."""
        dest.parent.mkdir(parents=True, exist_ok=True)
        if dest.is_symlink() or dest.exists():
            dest.unlink()
        shutil.copyfile(src, dest)
        dest.chmod(0o644)


    def copy_tree(src: Path, dest: Path) -> None:
        """cp -r --no-preserve=mode,ownership: links stay links, the rest is writable."""
        for root, dirs, files in os.walk(src):
            target = dest / Path(root).relative_to(src)
            target.mkdir(parents=True, exist_ok=True)
            for name in dirs + files:
                path = Path(root, name)
                if path.is_symlink():
                    (target / name).symlink_to(os.readlink(path))
                elif path.is_file():
                    shutil.copyfile(path, target / name)


    # Tulasi as real files (the sandbox can't follow links into /nix/store);
    # recopied only when the theme changes.
    icons = APP / "data/icons"
    marker = icons / ".tulasi-source"
    if not marker.is_file() or marker.read_text().strip() != TULASI:
        icons.mkdir(parents=True, exist_ok=True)
        tmp = Path(tempfile.mkdtemp(prefix=".tulasi.", dir=icons))
        copy_tree(Path(TULASI, "share/icons/Tulasi"), tmp)
        shutil.rmtree(icons / "Tulasi", ignore_errors=True)
        tmp.rename(icons / "Tulasi")
        marker.write_text(TULASI + "\n")
        print("zen-miami-wind: installed Tulasi icons into the sandbox")
    install("${gtkSettings}", APP / "config/gtk-3.0/settings.ini")

    root = APP / ".zen"
    if not root.is_dir():
        print("zen-miami-wind: no Zen profile yet — start Zen once, then re-run.", file=sys.stderr)
        sys.exit(0)
    for profile in sorted(root.iterdir()):
        if not profile.is_dir():
            continue
        if not ((profile / "prefs.js").is_file() or (profile / "times.json").is_file()):
            continue
        install("${userChrome}", profile / "chrome/userChrome.css")
        install("${userContent}", profile / "chrome/userContent.css")
        install("${userJs}", profile / "user.js")
        install("${vimium.xpi}", profile / "extensions/${vimium.id}.xpi")
        print(f"zen-miami-wind: themed {profile}/")
  '';
in
{
  home.packages = [ sync ];
  programs.bash.shellAliases.zen = "flatpak run app.zen_browser.zen";

  home.activation.zenMiamiWind = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Real copies of the font for flatpak apps (symlinks into /nix/store are
    # invisible inside the sandbox).
    fontdir="$HOME/.local/share/fonts/departure-mono-nerd"
    run mkdir -p "$fontdir"
    run find ${font}/share/fonts -type f -name '*.otf' -exec install -m644 -t "$fontdir" {} +

    run ${sync}/bin/zen-miami-wind || true
  '';
}
