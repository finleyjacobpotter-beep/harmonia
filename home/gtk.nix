# GTK / Qt / cursor theming so non-terminal apps pick up Miami Wind too.
{ pkgs, palette, ... }:
let
  p = palette;
  # libadwaita / adw-gtk3 named colours
  css = ''
    @define-color accent_color ${p.pink};
    @define-color accent_bg_color ${p.pink};
    @define-color accent_fg_color ${p.bgDark};
    @define-color destructive_color ${p.redBright};
    @define-color destructive_bg_color ${p.redBright};
    @define-color destructive_fg_color ${p.white};
    @define-color success_color ${p.greenBright};
    @define-color success_bg_color ${p.green};
    @define-color success_fg_color ${p.bgDark};
    @define-color warning_color ${p.yellowBright};
    @define-color warning_bg_color ${p.yellowBright};
    @define-color warning_fg_color ${p.bgDark};
    @define-color error_color ${p.redBright};
    @define-color error_bg_color ${p.redBright};
    @define-color error_fg_color ${p.white};
    @define-color window_bg_color ${p.bg};
    @define-color window_fg_color ${p.fg};
    @define-color view_bg_color ${p.bg};
    @define-color view_fg_color ${p.fg};
    @define-color headerbar_bg_color ${p.bgDark};
    @define-color headerbar_fg_color ${p.fg};
    @define-color headerbar_border_color ${p.surface};
    @define-color headerbar_backdrop_color ${p.bgDark};
    @define-color headerbar_shade_color rgba(0, 0, 0, 0.36);
    @define-color sidebar_bg_color ${p.bgAlt};
    @define-color sidebar_fg_color ${p.fg};
    @define-color sidebar_backdrop_color ${p.bgAlt};
    @define-color sidebar_shade_color rgba(0, 0, 0, 0.36);
    @define-color card_bg_color ${p.bgAlt};
    @define-color card_fg_color ${p.fg};
    @define-color card_shade_color rgba(0, 0, 0, 0.36);
    @define-color dialog_bg_color ${p.bgAlt};
    @define-color dialog_fg_color ${p.fg};
    @define-color popover_bg_color ${p.bgAlt};
    @define-color popover_fg_color ${p.fg};
    @define-color shade_color rgba(0, 0, 0, 0.36);
    @define-color scrollbar_outline_color rgba(0, 0, 0, 0.5);
  '';
in
{
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Tulasi";
      package = pkgs.tulasi-icon-theme;
    };
    font = {
      name = p.font.name;
      size = p.font.size - 1;
    };
    gtk3.extraCss = css;
    gtk4.extraCss = css;
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  # Tulasi inherits from these for any icon it doesn't draw itself.
  home.packages = with pkgs; [
    kdePackages.breeze-icons
    adwaita-icon-theme
    hicolor-icon-theme
  ];

  home.pointerCursor = {
    enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    sway.enable = true;
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "adw-gtk3-dark";
    icon-theme = "Tulasi";
    font-name = "${p.font.name} ${toString (p.font.size - 1)}";
    monospace-font-name = "${p.font.mono} ${toString p.font.size}";
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };
}
