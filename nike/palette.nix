# Nike's palette: Miami Wind with red as the primary colour instead of pink,
# so a shell on Nike never looks like one on the host. The shared configs
# (home/bash.nix, tmux.nix, ranger.nix, neovim.nix) use `pink` for the
# primary, so it is the slot that changes; everything else is untouched.
palette:
palette
// {
  pink = palette.red;
  pinkBright = palette.redBright;
  accent = palette.red;
  selection = "${palette.red}40";
  selectionSolid = "#452d3a"; # red @ 25% over bg, like the host's pink one
  accentAnsi = "red";
}
