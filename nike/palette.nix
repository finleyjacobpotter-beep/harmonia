# Nike's palette: Miami Wind with orange as the primary colour instead of
# pink, so a shell on Nike never looks like one on the host. The shared
# configs (home/bash.nix, tmux.nix, ranger.nix, neovim.nix) use `pink` for
# the primary, so it is the slot that changes; everything else is untouched.
palette:
palette
// {
  pink = palette.orange;
  pinkBright = palette.orangeBright;
  accent = palette.orange;
  selection = "${palette.orange}40";
  selectionSolid = "#463a3b"; # orange @ 25% over bg, like the host's pink one
  accentAnsi = "yellow"; # ranger's nearest slot to orange
}
