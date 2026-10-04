# Dionysus's home. The same Sway desktop as harmonia (home/*.nix), but the
# flatpak-only pieces (the Zen browser, Element, the flatpak theme sync and
# the flatpak opencode launcher) are left out, because Dionysus runs its dev
# tools natively (./dev.nix) and must build on aarch64 as well as x86_64.
{
  pkgs,
  lib,
  username,
  system,
  ...
}:
{
  imports = [
    ../sway.nix
    ../eww.nix
    ../alacritty.nix
    ../tmux.nix
    ../bash.nix
    ../ranger.nix
    ../neovim.nix
    ../gtk.nix
    ../tui.nix
    ../keymap.nix
    ../secrets.nix
    ../element.nix # Element theming (the flatpak is in hosts/dionysus/)
    ./dev.nix
  ]
  # Zen has no aarch64 build, so its theming only applies where the flatpak is
  # installed (x86_64); aarch64 uses the native Firefox from ./dev.nix.
  ++ lib.optional (system == "x86_64-linux") ../zen.nix;

  home.username = username;
  home.homeDirectory = "/home/${username}";

  programs.home-manager.enable = true;
  programs.bash.shellAliases.rebuild = "sudo nixos-rebuild switch --flake ~/harmonia#dionysus";
  programs.git.enable = true;

  # XDG base dirs plus the user dirs (Desktop, Documents, ...), created on
  # every activation.
  xdg.enable = true;
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  # ~/Projects is where Blender, Godot and the coding agents work.
  home.activation.projectsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/Projects"
  '';

  # E-book library and reader (GPL; built without unrar, so no unfree bits).
  home.packages = [ pkgs.calibre ];

  home.stateVersion = "26.05";
}
