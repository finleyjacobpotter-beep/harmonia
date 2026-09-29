{ pkgs, username, ... }:
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
    ./lutris.nix
    ./element.nix
    ./tui.nix
    ./keymap.nix
    ./secrets.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  programs.home-manager.enable = true;
  programs.git.enable = true;

  # E-book library and reader (GPL; built without unrar, so no unfree bits).
  home.packages = [ pkgs.calibre ];

  home.stateVersion = "26.05";
}
