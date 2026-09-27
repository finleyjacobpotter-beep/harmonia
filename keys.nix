# The keyboard contract. Each modifier "namespace" belongs to exactly one layer,
# so layers never fight over a key. home/keymap.nix turns these rules into
# evaluation-time assertions.
#
#   Super + …        sway only. No app, tmux or CLI tool binds Super.
#   Ctrl+Space …     tmux prefix only. tmux has no prefix-less (root table)
#                    bindings, so every other key reaches the program inside.
#   Ctrl+Shift + …   alacritty only (copy/paste, search, font size, hints).
#   everything else  the focused app: Zen (+ Vimium), neovim, ranger, bash
#                    (vi mode), btop, pulsemixer, bluetuith, …
#
# Zen and tmux never see each other's keys (only one is focused), so they may
# overlap; CLI tools always run inside alacritty/tmux, so they may not use
# Super, Ctrl+Space or Ctrl+Shift.
{
  sway = "Mod4";
  tmuxPrefix = "C-Space";
  terminalMods = "Control|Shift";
}
