# Miami Wind for the flatpak'd Element (installed in modules/nixos/element.nix).
#
# Element Desktop reads a config.json from its userData dir and applies it on
# top of the bundled one; in the sandbox that is
# ~/.var/app/im.riot.Riot/config/Element. It defines a "Miami Wind" custom
# theme with the palette and font and makes it the default. The font is
# exposed to every flatpak by home/zen.nix (~/.local/share/fonts).
{
  pkgs,
  lib,
  palette,
  ...
}:
let
  p = palette;

  config = {
    default_theme = "custom-${p.name}";
    setting_defaults.custom_themes = [
      {
        name = p.name;
        is_dark = true;
        fonts = {
          general = "'${p.font.name}', monospace";
          monospace = "'${p.font.mono}', monospace";
        };
        colors = {
          accent-color = p.pink;
          primary-color = p.cyan;
          warning-color = p.redBright;
          sidebar-color = p.bgDark;
          roomlist-background-color = p.bgAlt;
          roomlist-text-color = p.fg;
          roomlist-text-secondary-color = p.fgDim;
          roomlist-highlights-color = p.surface;
          roomlist-separator-color = p.surface;
          timeline-background-color = p.bg;
          timeline-text-color = p.fg;
          timeline-text-secondary-color = p.fgDim;
          timeline-highlights-color = p.bgAlt;
          # 8 each
          username-colors = with p; [ pink cyan yellow purple blue green orange red ];
          avatar-background-colors = with p; [ pink cyan purple blue green orange yellow red ];
        };
        # Element's design tokens for accent text and icons.
        compound = {
          "--cpd-color-text-action-accent" = p.pink;
          "--cpd-color-icon-accent-tertiary" = p.pink;
          "--cpd-color-icon-accent-primary" = p.pink;
          "--cpd-color-bg-accent-rest" = p.pink;
          "--cpd-color-bg-accent-hovered" = p.pinkBright;
          "--cpd-color-bg-accent-pressed" = p.pinkBright;
        };
      }
    ];
  };

  configFile = pkgs.writeText "element-config.json" (builtins.toJSON config);
in
{
  # A real copy: the sandbox can't follow a home-manager symlink into
  # /nix/store.
  home.activation.elementMiamiWind = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -Dm644 ${configFile} "$HOME/.var/app/im.riot.Riot/config/Element/config.json"
  '';
}
