# Theming and add-ons for the flatpak'd Firefox (installed in
# modules/nixos/flatpak.nix): vertical tabs, uBlock Origin, Vimium, and Miami
# Wind on the browser, its about: pages and Vimium's link hints, HUD and
# Vomnibar.
#
# The sandbox can't follow symlinks into /nix/store, so everything here is
# *copied* into the app's own data dir (~/.var/app/org.mozilla.firefox) and
# into ~/.local/share/fonts, which flatpak exposes to apps as
# /run/host/user-fonts.
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
    /* Miami Wind for Firefox */
    :root {
      --toolbar-bgcolor: ${p.bgDark} !important;
      --toolbar-color: ${p.fg} !important;
      --toolbar-field-background-color: ${p.bg} !important;
      --toolbar-field-color: ${p.fg} !important;
      --toolbar-field-focus-background-color: ${p.bg} !important;
      --toolbar-field-focus-color: ${p.fg} !important;
      --toolbar-field-focus-border-color: ${p.pink} !important;
      --toolbarbutton-icon-fill: ${p.fg} !important;
      --lwt-accent-color: ${p.bgDark} !important;
      --lwt-text-color: ${p.fg} !important;
      --tabpanel-background-color: ${p.bg} !important;
      --tab-selected-bgcolor: ${p.surface} !important;
      --tab-selected-textcolor: ${p.fg} !important;
      --tab-hover-background-color: ${p.bgAlt} !important;
      --sidebar-background-color: ${p.bgDark} !important;
      --sidebar-text-color: ${p.fg} !important;
      --sidebar-border-color: ${p.surface} !important;
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

    /* The vertical tab strip (sidebar.verticalTabs) and the sidebar beside it. */
    #sidebar-main,
    #sidebar-box,
    #vertical-tabs,
    #navigator-toolbox {
      background-color: ${p.bgDark} !important;
      color: ${p.fg} !important;
    }

    .tabbrowser-tab[selected] .tab-background,
    .tabbrowser-tab[multiselected] .tab-background {
      background-color: ${p.surface} !important;
      box-shadow: inset 3px 0 0 ${p.pink} !important;
    }

    .tab-label {
      color: ${p.fg} !important;
    }

    .tabbrowser-tab:not([selected]) .tab-label {
      color: ${p.fgDim} !important;
    }

    ::selection {
      background-color: ${p.pink} !important;
      color: ${p.bgDark} !important;
    }
  '';

  # Vimium draws its link hints straight into the page, and its HUD and
  # Vomnibar as its own extension pages, so all three are restyled here, where
  # a user sheet's !important beats the add-on's own CSS.
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

    /* Vimium link hints (f / F / yf). */
    div.internal-vimium-hint-marker {
      background: ${p.bgDark} !important;
      border: 1px solid ${p.pink} !important;
      border-radius: 3px !important;
      box-shadow: 0 2px 6px rgba(0, 0, 0, 0.5) !important;
    }
    div.internal-vimium-hint-marker span {
      color: ${p.fg} !important;
      font-family: "${p.font.mono}", monospace !important;
      text-shadow: none !important;
    }
    div.internal-vimium-hint-marker > .matchingCharacter {
      color: ${p.pink} !important;
    }
    div > .vimiumActiveHintMarker span {
      color: ${p.pink} !important;
    }
    div.internal-vimium-input-hint {
      background-color: ${p.selection} !important;
      border: 1px solid ${p.pink} !important;
    }

    /* Vimium's HUD (find bar, messages) and Vomnibar (o / O / b / T). */
    @-moz-document regexp("moz-extension://[^/]+/pages/(hud|vomnibar)_page\\.html.*") {
      :root {
        --vimium-background-color: ${p.bgDark} !important;
        --vimium-background-text-color: ${p.fg} !important;
        --vimium-foreground-color: ${p.bgAlt} !important;
        --vimium-foreground-text-color: ${p.fg} !important;
        --vimium-link-color: ${p.cyan} !important;
      }
      body, input, span, div, li {
        font-family: "${p.font.mono}", monospace !important;
      }
      #hud-container,
      #vomnibar {
        background-color: ${p.bgDark} !important;
        color: ${p.fg} !important;
        border: 1px solid ${p.pink} !important;
      }
      #hud,
      #vomnibar input,
      #vomnibar-search-area {
        background-color: ${p.bg} !important;
        color: ${p.fg} !important;
        border-color: ${p.surface} !important;
      }
      #vomnibar li {
        background-color: ${p.bgDark} !important;
        border-color: ${p.surface} !important;
      }
      #vomnibar li.selected {
        background-color: ${p.surface} !important;
      }
      #vomnibar li .title,
      #vomnibar li em {
        color: ${p.fg} !important;
      }
      #vomnibar li .url,
      #vomnibar li .source {
        color: ${p.cyan} !important;
      }
      #vomnibar li .match,
      #vomnibar li em .match,
      #vomnibar li .title .match {
        color: ${p.pink} !important;
      }
      #vomnibar input::selection {
        background-color: ${p.pink} !important;
        color: ${p.bgDark} !important;
      }
    }
  '';

  userJs = pkgs.writeText "user.js" ''
    // Managed by home-manager (home/firefox.nix) — changes here are overwritten.
    user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
    user_pref("layout.css.prefers-color-scheme.content-override", 0);
    user_pref("ui.systemUsesDarkTheme", 1);
    user_pref("browser.theme.content-theme", 0);
    user_pref("browser.theme.toolbar-theme", 0);
    user_pref("browser.display.background_color.dark", "${p.bg}");
    user_pref("font.name.monospace.x-western", "${p.font.mono}");
    user_pref("font.name.sans-serif.x-western", "${p.font.name}");
    user_pref("font.name.serif.x-western", "${p.font.name}");
    user_pref("font.default.x-western", "sans-serif");
    user_pref("widget.use-xdg-desktop-portal.file-picker", 1);

    // Vertical tabs in the sidebar, always shown.
    user_pref("sidebar.revamp", true);
    user_pref("sidebar.verticalTabs", true);
    user_pref("sidebar.visibility", "always-show");

    // Keyboard: enable the side-loaded uBlock Origin and Vimium without a
    // prompt, and keep Firefox features that eat bare keys out of Vimium's way.
    user_pref("extensions.autoDisableScopes", 0);
    user_pref("extensions.enabledScopes", 15);
    user_pref("accessibility.typeaheadfind", false);
    user_pref("accessibility.typeaheadfind.manual", false);
    user_pref("ui.key.menuAccessKeyFocuses", false);
    user_pref("browser.tabs.warnOnClose", false);
  '';

  font = pkgs.nerd-fonts.departure-mono;

  # Add-ons, side-loaded into every profile. Pinned as in nix-community's
  # firefox-addons (rycee/nur-expressions).
  addons = {
    # uBlock Origin: the ad and tracker blocker, with its default filter lists.
    ublock-origin = {
      id = "uBlock0@raymondhill.net";
      xpi = pkgs.fetchurl {
        url = "https://addons.mozilla.org/firefox/downloads/file/5034826/ublock_origin-1.75.0.xpi";
        sha256 = "5b74415860456370644bd80f16125e865b0e6c356bb5dfcfb84069967eaa5287";
      };
    };
    # Vimium: vim keys for the web (j/k scroll, f link hints, J/K tabs, H/L
    # history, o/O open, T tab search, / find, x/X close/restore tab, ? help).
    vimium = {
      id = "{d7742d87-e61d-4b78-b8a1-b469842139fa}";
      xpi = pkgs.fetchurl {
        url = "https://addons.mozilla.org/firefox/downloads/file/4717567/vimium_ff-2.4.2.xpi";
        sha256 = "131e2a67580e7ae9125ab19781159e61409fac47b441fc2782aab76396ead196";
      };
    };
  };

  # { "<add-on id>": "<xpi in the store>" }, read by the sync script below.
  addonXpis = builtins.toJSON (
    lib.listToAttrs (map (a: lib.nameValuePair a.id "${a.xpi}") (lib.attrValues addons))
  );

  # Icons inside the sandbox. Firefox may read and write its own
  # ~/.var/app/org.mozilla.firefox, and GTK in the sandbox looks for icon
  # themes in its data/icons (XDG_DATA_HOME) and reads its config/gtk-3.0
  # (XDG_CONFIG_HOME). So Tulasi goes there — no new flatpak permission.
  # This is the *generic* build (no appPackages): the per-machine build lists
  # every installed program's icon name, which the browser has no need to see.
  tulasi = pkgs.tulasi-icon-theme;

  gtkSettings = pkgs.writeText "firefox-gtk3-settings.ini" ''
    [Settings]
    gtk-icon-theme-name=Tulasi
    gtk-application-prefer-dark-theme=1
    gtk-font-name=${p.font.name} ${toString (p.font.size - 1)}
  '';

  sync = pyScript "firefox-miami-wind" { } ''
    """Copy the Miami Wind theme into the Firefox flatpak's own data dir:
    Tulasi icons, GTK settings, and userChrome.css, userContent.css, user.js,
    uBlock Origin and Vimium into every Firefox profile."""

    import json
    import os
    import shutil
    import sys
    import tempfile
    from pathlib import Path

    TULASI = "${tulasi}"
    ADDONS = json.loads('${addonXpis}')
    APP = Path.home() / ".var/app/org.mozilla.firefox"
    # Profiles live in ~/.mozilla/firefox, or in the XDG location newer
    # Firefox uses for fresh installs (~/.config inside the sandbox).
    ROOTS = [APP / ".mozilla/firefox", APP / "config/mozilla/firefox"]


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
        print("firefox-miami-wind: installed Tulasi icons into the sandbox")
    install("${gtkSettings}", APP / "config/gtk-3.0/settings.ini")

    profiles = []
    for root in ROOTS:
        if not root.is_dir():
            continue
        for profile in sorted(root.iterdir()):
            if (profile / "prefs.js").is_file() or (profile / "times.json").is_file():
                profiles.append(profile)
    if not profiles:
        print("firefox-miami-wind: no Firefox profile yet — start Firefox once, then re-run.", file=sys.stderr)
        sys.exit(0)
    for profile in profiles:
        install("${userChrome}", profile / "chrome/userChrome.css")
        install("${userContent}", profile / "chrome/userContent.css")
        install("${userJs}", profile / "user.js")
        for addon_id, xpi in ADDONS.items():
            install(xpi, profile / "extensions" / f"{addon_id}.xpi")
        print(f"firefox-miami-wind: themed {profile}/")
  '';
in
{
  home.packages = [ sync ];
  programs.bash.shellAliases.firefox = "flatpak run org.mozilla.firefox";

  home.activation.firefoxMiamiWind = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Real copies of the font for flatpak apps (symlinks into /nix/store are
    # invisible inside the sandbox).
    fontdir="$HOME/.local/share/fonts/departure-mono-nerd"
    run mkdir -p "$fontdir"
    run find ${font}/share/fonts -type f -name '*.otf' -exec install -m644 -t "$fontdir" {} +

    run ${sync}/bin/firefox-miami-wind || true
  '';
}
