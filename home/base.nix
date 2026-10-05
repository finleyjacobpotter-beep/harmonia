# The home every host shares: the Sway desktop, the terminal tools and their
# Miami Wind theming. home/default.nix (harmonia, cadmus) and
# home/dionysus/default.nix add what only they need.
{
  pkgs,
  lib,
  username,
  ...
}:
{
  imports = [
    ./sway.nix
    ./eww.nix
    ./alacritty.nix
    ./tmux.nix
    ./bash.nix
    ./ranger.nix
    ./neovim.nix
    ./gtk.nix
    ./element.nix
    ./tui.nix
    ./keymap.nix
    ./secrets.nix
    ./firefox.nix
    ./flatpak-files.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  programs.home-manager.enable = true;
  programs.bash.shellAliases.rebuild = lib.mkDefault "sudo nixos-rebuild switch --flake ~/harmonia";
  programs.git.enable = true;

  # XDG base dirs (~/.config, ~/.local/share, ...) plus the user dirs
  # (Desktop, Documents, Downloads, ...), created on every activation.
  xdg.enable = true;
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  # ~/Projects is where Blender, Godot and the coding agents work: on
  # harmonia the only host directory Blender and Godot can see
  # (modules/nixos/studio.nix), and Zelus's ~/Projects (modules/nixos/zelus.nix).
  home.activation.projectsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/Projects"
  '';

  # E-book library and reader (GPL; built without unrar, so no unfree bits).
  home.packages = [ pkgs.calibre ];

  home.stateVersion = "26.05";
}
