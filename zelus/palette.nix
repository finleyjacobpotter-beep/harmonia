# Zelus's palette: Miami Wind with cyan as the primary colour instead of
# pink, so a shell on Zelus never looks like one on the host (or on Nike,
# which is orange). The shared configs (home/bash.nix, tmux.nix, ranger.nix,
# neovim.nix) use `pink` for the primary and `cyan` for the secondary, so the
# two swap: cyan leads and pink is the second colour, which keeps neovim's
# normal and insert modes (pink and cyan) apart.
palette:
palette
// {
  pink = palette.cyan;
  pinkBright = palette.cyanBright;
  cyan = palette.pink;
  cyanBright = palette.pinkBright;
  accent = palette.cyan;
  accentAlt = palette.pink;
  selection = "${palette.cyan}40";
  selectionSolid = "#1f4b5e"; # cyan @ 25% over bg, like the host's pink one
  accentAnsi = "cyan";
}
