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

  sync = pkgs.writeShellApplication {
    name = "zen-miami-wind";
    text = ''
      root="$HOME/.var/app/app.zen_browser.zen/.zen"
      if [ ! -d "$root" ]; then
        echo "zen-miami-wind: no Zen profile yet — start Zen once, then re-run." >&2
        exit 0
      fi
      for profile in "$root"/*/; do
        [ -f "$profile/prefs.js" ] || [ -f "$profile/times.json" ] || continue
        install -Dm644 ${userChrome} "$profile/chrome/userChrome.css"
        install -Dm644 ${userContent} "$profile/chrome/userContent.css"
        install -Dm644 ${userJs} "$profile/user.js"
        install -Dm644 ${vimium.xpi} "$profile/extensions/${vimium.id}.xpi"
        echo "zen-miami-wind: themed $profile"
      done
    '';
  };
in
{
  home.packages = [ sync ];

  home.activation.zenMiamiWind = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Real copies of the font for flatpak apps (symlinks into /nix/store are
    # invisible inside the sandbox).
    fontdir="$HOME/.local/share/fonts/departure-mono-nerd"
    run mkdir -p "$fontdir"
    run find ${font}/share/fonts -type f -name '*.otf' -exec install -m644 -t "$fontdir" {} +

    run ${sync}/bin/zen-miami-wind || true
  '';
}
