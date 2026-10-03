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
    ./zen.nix
    ./flatpak-theme.nix
    ./element.nix
    ./opencode.nix
    ./tui.nix
    ./keymap.nix
    ./secrets.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  programs.home-manager.enable = true;
  programs.git.enable = true;

  # XDG base dirs (~/.config, ~/.local/share, ...) plus the user dirs
  # (Desktop, Documents, Downloads, ...), created on every activation.
  xdg.enable = true;
  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  # ~/Projects is the only host directory Blender, Godot and opencode can see
  # (modules/nixos/studio.nix).
  home.activation.projectsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/Projects"
  '';

  home.packages = [
    # E-book library and reader (GPL; built without unrar, so no unfree bits).
    pkgs.calibre
    # Python package manager; provides `uv` and `uvx` (run a tool from PyPI
    # without installing it).
    pkgs.uv
  ];

  home.stateVersion = "26.05";
}
