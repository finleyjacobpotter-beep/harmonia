# Miami Wind for the flatpak'd Lutris (installed in modules/nixos/gaming.nix).
#
# Lutris is a GTK 3 app, but inside its sandbox it can't see the host's
# ~/.local/share or follow symlinks into /nix/store. So the same adw-gtk3
# theme, Miami Wind colours (gtk.css), Tulasi icons and Bibata cursor that
# home/gtk.nix sets up are *copied* into the app's own data and config dirs,
# which GTK in the sandbox uses as XDG_DATA_HOME and XDG_CONFIG_HOME. The font
# is already exposed to every flatpak by home/zen.nix (~/.local/share/fonts).
{
  config,
  pkgs,
  lib,
  palette,
  ...
}:
let
  p = palette;

  theme = pkgs.adw-gtk3;
  cursor = pkgs.bibata-cursors;
  # Generic build, like Zen's: no need to list host programs to a sandbox.
  tulasi = pkgs.tulasi-icon-theme;

  gtkSettings = pkgs.writeText "lutris-gtk3-settings.ini" ''
    [Settings]
    gtk-theme-name=adw-gtk3-dark
    gtk-icon-theme-name=Tulasi
    gtk-cursor-theme-name=Bibata-Modern-Classic
    gtk-cursor-theme-size=24
    gtk-application-prefer-dark-theme=1
    gtk-font-name=${p.font.name} ${toString (p.font.size - 1)}
  '';
  gtkCss = pkgs.writeText "lutris-gtk.css" config.gtk.gtk3.extraCss;

  sync = pkgs.writeShellApplication {
    name = "lutris-miami-wind";
    text = ''
      app="$HOME/.var/app/net.lutris.Lutris"

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

      copy ${theme}/share/themes/adw-gtk3-dark "$app/data/themes/adw-gtk3-dark"
      copy ${tulasi}/share/icons/Tulasi "$app/data/icons/Tulasi"
      copy ${cursor}/share/icons/Bibata-Modern-Classic "$app/data/icons/Bibata-Modern-Classic"
      install -Dm644 ${gtkSettings} "$app/config/gtk-3.0/settings.ini"
      install -Dm644 ${gtkCss} "$app/config/gtk-3.0/gtk.css"
    '';
  };
in
{
  home.packages = [ sync ];

  # ~/Games is the only host directory Lutris can see (see gaming.nix).
  home.activation.lutrisMiamiWind = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/Games"
    run ${sync}/bin/lutris-miami-wind || true
  '';
}
