{ username, ... }:
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
    ./tui.nix
    ./keymap.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  programs.home-manager.enable = true;
  programs.git.enable = true;

  home.stateVersion = "26.05";
}
