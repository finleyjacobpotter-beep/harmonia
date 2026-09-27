# Keyboard-driven (vim-keyed) replacements for the usual GUI system tools.
# Launched from sway's "open" mode (Super+o) — see home/sway.nix.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    pulsemixer # audio: j/k select, h/l volume, m mute
    bluetuith # bluetooth: j/k, Enter, vim-style menus
  ];

  programs.btop = {
    enable = true;
    settings = {
      vim_keys = true;
      # "TTY" draws with the terminal's 16 ANSI colours = Miami Wind
      color_theme = "TTY";
      theme_background = false;
      rounded_corners = false;
    };
  };
}
