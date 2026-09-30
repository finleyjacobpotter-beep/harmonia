# The desktop's GTK theme inside flatpak sandboxes: Lutris (GTK 3, installed in
# modules/nixos/gaming.nix) and LACT (GTK 4 / libadwaita, modules/nixos/fans.nix).
#
# Flatpak apps can't see the host's ~/.local/share or ~/.config, or follow
# symlinks into /nix/store. So the same adw-gtk3 theme, Miami Wind colours
# (gtk.css), Tulasi icons and Bibata cursor that home/gtk.nix sets up are
# *copied* into each app's own data and config dirs, which GTK in the sandbox
# uses as XDG_DATA_HOME and XDG_CONFIG_HOME. Dark mode and the font name come
# through the settings portal; the font itself is exposed to every flatpak by
# home/zen.nix (~/.local/share/fonts).
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
  # Generic build, like Zen's: no need to list host programs to a sandbox.
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

  sync = pkgs.writeShellApplication {
    name = "flatpak-miami-wind";
    text = ''
      # copy <store dir> <dest dir>: real files, recopied only when the
      # store path changes.
      copy() {
        if [ "$(cat "$2/.source" 2>/dev/null || true)" != "$1" ]; then
          mkdir -p "$(dirname "$2")"
          tmp=$(mktemp -d "$(dirname "$2")/.copy.XXXXXX")
          cp -r --no-preserve=mode,ownership "$1/." "$tmp/"
          echo "$1" > "$tmp/.source"
          rm -rf "$2"
          mv "$tmp" "$2"
        fi
      }

      for id in ${lib.escapeShellArgs apps}; do
        app="$HOME/.var/app/$id"
        copy ${theme}/share/themes/adw-gtk3-dark "$app/data/themes/adw-gtk3-dark"
        copy ${tulasi}/share/icons/Tulasi "$app/data/icons/Tulasi"
        copy ${cursor}/share/icons/Bibata-Modern-Classic "$app/data/icons/Bibata-Modern-Classic"
        install -Dm644 ${gtkSettings} "$app/config/gtk-3.0/settings.ini"
        install -Dm644 ${gtk3Css} "$app/config/gtk-3.0/gtk.css"
        install -Dm644 ${gtkSettings} "$app/config/gtk-4.0/settings.ini"
        install -Dm644 ${gtk4Css} "$app/config/gtk-4.0/gtk.css"
      done
    '';
  };
in
{
  home.packages = [ sync ];

  home.activation.flatpakMiamiWind = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # ~/Games is the only host directory Lutris can see (see gaming.nix).
    run mkdir -p "$HOME/Games"
    run ${sync}/bin/flatpak-miami-wind || true
  '';
}
