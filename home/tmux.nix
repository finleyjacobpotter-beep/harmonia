{
  pkgs,
  palette,
  keys,
  ...
}:
let
  p = palette;
in
{
  programs.tmux = {
    enable = true;
    shell = "${pkgs.bashInteractive}/bin/bash";
    terminal = "tmux-256color";
    keyMode = "vi";
    # Ctrl+Space is tmux's alone (keys.nix). Prefix twice sends a literal
    # Ctrl+Space to the program inside.
    prefix = keys.tmuxPrefix;
    # prefix h/j/k/l select pane, prefix H/J/K/L resize (repeatable)
    customPaneNavigationAndResize = true;
    resizeAmount = 5;
    mouse = true;
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    focusEvents = true;
    # No tmux-sensible (it forces emacs status-keys) and no
    # vim-tmux-navigator (it steals Ctrl+h/j/k/l from every CLI tool).
    plugins = with pkgs.tmuxPlugins; [ yank ];
    extraConfig = ''
      # truecolor + undercurl passthrough for alacritty
      set -as terminal-features ",alacritty*:RGB:usstyle"

      set -g renumber-windows on
      set -g set-titles on
      set -g status-keys vi
      set -g display-time 2000
      set -g repeat-time 500
      set -s set-clipboard on

      # Every binding below lives in the prefix table — nothing is bound in
      # the root table, so tmux never swallows a key meant for a CLI tool.

      # panes / windows, vim flavoured (s = :split, v = :vsplit)
      bind s split-window -v -c "#{pane_current_path}"
      bind v split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"
      bind -r n next-window
      bind -r p previous-window
      bind Tab last-window
      bind q kill-pane
      bind Q confirm-before -p "kill window #W? (y/n)" kill-window
      bind S choose-tree -Zs
      bind w choose-tree -Zw
      bind < swap-window -d -t -1
      bind > swap-window -d -t +1
      bind r source-file ~/.config/tmux/tmux.conf \; display "reloaded"

      # copy mode: prefix Escape (or prefix [), then vim motions
      bind Escape copy-mode
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi C-v send -X rectangle-toggle
      bind -T copy-mode-vi Escape send -X cancel
      bind P paste-buffer -p

      # ── Miami Wind ────────────────────────────────────────────────
      set -g status-position top
      set -g status-justify left
      set -g status-style "bg=${p.bgDark},fg=${p.fg}"
      set -g status-left-length 40
      set -g status-right-length 80
      set -g status-left "#[bg=${p.primary},fg=${p.bgDark},bold]  #S #[bg=${p.bgDark}] "
      set -g status-right "#{?client_prefix,#[fg=${p.yellow}]󰌌 PREFIX ,}#[fg=${p.secondary}] #h #[bg=${p.surface},fg=${p.fg}] %H:%M "

      set -g window-status-format "#[fg=${p.muted}] #I #W "
      set -g window-status-current-format "#[bg=${p.surface},fg=${p.primary},bold] #I #[fg=${p.fg}]#W#{?window_zoomed_flag, 󰊓,} "
      set -g window-status-separator ""
      set -g window-status-activity-style "fg=${p.orange}"
      set -g window-status-bell-style "fg=${p.redBright},bold"

      set -g pane-border-style "fg=${p.surface}"
      set -g pane-active-border-style "fg=${p.primary}"
      set -g pane-border-lines heavy
      set -g display-panes-colour "${p.muted}"
      set -g display-panes-active-colour "${p.primary}"

      set -g message-style "bg=${p.surface},fg=${p.secondary}"
      set -g message-command-style "bg=${p.surface},fg=${p.yellow}"
      set -g mode-style "bg=${p.surfaceHi},fg=${p.fg}"
      set -g clock-mode-colour "${p.primary}"
      set -g copy-mode-match-style "bg=${p.secondary},fg=${p.bgDark}"
      set -g copy-mode-current-match-style "bg=${p.primary},fg=${p.bgDark}"
    '';
  };
}
