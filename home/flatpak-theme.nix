# The desktop's GTK theme inside flatpak sandboxes: Lutris (GTK 3, installed in
# modules/nixos/gaming.nix) and LACT (GTK 4 / libadwaita, modules/nixos/fans.nix).
#
# Flatpak apps can't see the host's ~/.local/share or ~/.config, or follow
# symlinks into /nix/store. So the same adw-gtk3 theme, Miami Wind colours
# (gtk.css), Tulasi icons and Bibata cursor that home/gtk.nix sets up are
# *copied* into each app's own data and config dirs, which GTK in the sandbox
# uses as XDG_DATA_HOME and XDG_CONFIG_HOME. Dark mode and the font name come
# through the settings portal; the font itself is exposed to every flatpak by
# home/firefox.nix (~/.local/share/fonts).
{
  config,
  pkgs,
  lib,
  palette,
  ...
}:
let
  p = palette;
  pyScript = import ../lib/python-script.nix { inherit pkgs lib; };

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

  sync = pyScript "flatpak-miami-wind" { } ''
    """Copy the desktop's GTK theme, icons and cursor into each flatpak app's
    own data and config dirs (see home/flatpak-theme.nix)."""

    import os
    import shutil
    import tempfile
    from pathlib import Path

    APPS = [${lib.concatMapStringsSep ", " (a: ''"${a}"'') apps}]


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


    def copy(src: str, dest: Path) -> None:
        """Real files, recopied only when the store path changes."""
        marker = dest / ".source"
        if marker.is_file() and marker.read_text().strip() == src:
            return
        dest.parent.mkdir(parents=True, exist_ok=True)
        tmp = Path(tempfile.mkdtemp(prefix=".copy.", dir=dest.parent))
        copy_tree(Path(src), tmp)
        (tmp / ".source").write_text(src + "\n")
        shutil.rmtree(dest, ignore_errors=True)
        tmp.rename(dest)


    for app_id in APPS:
        app = Path.home() / ".var/app" / app_id
        copy("${theme}/share/themes/adw-gtk3-dark", app / "data/themes/adw-gtk3-dark")
        copy("${tulasi}/share/icons/Tulasi", app / "data/icons/Tulasi")
        copy("${cursor}/share/icons/Bibata-Modern-Classic", app / "data/icons/Bibata-Modern-Classic")
        install("${gtkSettings}", app / "config/gtk-3.0/settings.ini")
        install("${gtk3Css}", app / "config/gtk-3.0/gtk.css")
        install("${gtkSettings}", app / "config/gtk-4.0/settings.ini")
        install("${gtk4Css}", app / "config/gtk-4.0/gtk.css")
  '';
in
{
  home.packages = [ sync ];

  home.activation.flatpakMiamiWind = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # ~/Games is the only host directory Lutris can see (see gaming.nix).
    run mkdir -p "$HOME/Games"
    run ${sync}/bin/flatpak-miami-wind || true
  '';
}
