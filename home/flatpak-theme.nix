# The desktop's GTK theme inside flatpak sandboxes: Lutris (GTK 3, installed in
# modules/nixos/gaming.nix) and LACT (GTK 4 / libadwaita, modules/nixos/fans.nix).
#
# Flatpak apps can't see the host's ~/.local/share or ~/.config, or follow
# symlinks into /nix/store. So the same adw-gtk3 theme, Miami Wind colours
# (gtk.css), Tulasi icons and Bibata cursor that home/gtk.nix sets up are
# *copied* into each app's own data and config dirs, which GTK in the sandbox
# uses as XDG_DATA_HOME and XDG_CONFIG_HOME. Dark mode and the font name come
# through the settings portal; the font itself is exposed to every flatpak by
# home/firefox.nix (~/.local/share/fonts). The copying itself is
# home/flatpak-files.nix.
{
  config,
  pkgs,
  lib,
  palette,
  ...
}:
let
  p = palette;

  apps = [
    "net.lutris.Lutris"
    "io.github.ilya_zlobintsev.LACT"
  ];

  theme = pkgs.adw-gtk3;
  cursor = pkgs.bibata-cursors;
  # Generic build, like Firefox's: no need to list host programs to a sandbox.
  tulasi = pkgs.tulasi-icon-theme;

  gtkSettings = pkgs.writeText "flatpak-gtk-settings.ini" ''
    [Settings]
    gtk-theme-name=adw-gtk3-dark
    gtk-icon-theme-name=Tulasi
    gtk-cursor-theme-name=Bibata-Modern-Classic
    gtk-cursor-theme-size=24
    gtk-application-prefer-dark-theme=1
    gtk-font-name=${p.font.name} ${toString (p.font.size - 1)}
  '';
  gtk3Css = pkgs.writeText "flatpak-gtk3.css" config.gtk.gtk3.extraCss;
  gtk4Css = pkgs.writeText "flatpak-gtk4.css" config.gtk.gtk4.extraCss;

in
{
  # Copied by flatpak-miami-wind (home/flatpak-files.nix).
  harmonia.flatpakFiles = lib.mergeAttrsList (
    map (
      appId:
      lib.mapAttrs' (dest: lib.nameValuePair ".var/app/${appId}/${dest}") {
        "data/themes/adw-gtk3-dark" = "${theme}/share/themes/adw-gtk3-dark";
        "data/icons/Tulasi" = "${tulasi}/share/icons/Tulasi";
        "data/icons/Bibata-Modern-Classic" = "${cursor}/share/icons/Bibata-Modern-Classic";
        "config/gtk-3.0/settings.ini" = gtkSettings;
        "config/gtk-3.0/gtk.css" = gtk3Css;
        "config/gtk-4.0/settings.ini" = gtkSettings;
        "config/gtk-4.0/gtk.css" = gtk4Css;
      }
    ) apps
  );

  # ~/Games is the only host directory Lutris can see (see gaming.nix).
  home.activation.gamesDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/Games"
  '';
}
