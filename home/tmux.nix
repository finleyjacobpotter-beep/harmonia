{ pkgs, palette, ... }:
let
  p = palette;
in
{
  programs.tmux = {
    enable = true;
    shell = "${pkgs.bashInteractive}/bin/bash";
    terminal = "tmux-256color";
    keyMode = "vi";
    mouse = true;
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    focusEvents = true;
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      vim-tmux-navigator
    ];
    extraConfig = ''
      # truecolor + undercurl passthrough for alacritty
      set -as terminal-features ",alacritty*:RGB:usstyle"

      set -g renumber-windows on
      set -g set-titles on
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"
      bind r source-file ~/.config/tmux/tmux.conf \; display "reloaded"

      # ── Miami Wind ────────────────────────────────────────────────
      set -g status-position top
      set -g status-justify left
      set -g status-style "bg=${p.bgDark},fg=${p.fg}"
      set -g status-left-length 40
      set -g status-right-length 80
      set -g status-left "#[bg=${p.pink},fg=${p.bgDark},bold]  #S #[bg=${p.bgDark}] "
      set -g status-right "#{?client_prefix,#[fg=${p.yellow}]󰌌 PREFIX ,}#[fg=${p.cyan}] #h #[bg=${p.surface},fg=${p.fg}] %H:%M "

      set -g window-status-format "#[fg=${p.muted}] #I #W "
      set -g window-status-current-format "#[bg=${p.surface},fg=${p.pink},bold] #I #[fg=${p.fg}]#W#{?window_zoomed_flag, 󰊓,} "
      set -g window-status-separator ""
      set -g window-status-activity-style "fg=${p.orange}"
      set -g window-status-bell-style "fg=${p.redBright},bold"

      set -g pane-border-style "fg=${p.surface}"
      set -g pane-active-border-style "fg=${p.pink}"
      set -g pane-border-lines heavy
      set -g display-panes-colour "${p.muted}"
      set -g display-panes-active-colour "${p.pink}"

      set -g message-style "bg=${p.surface},fg=${p.cyan}"
      set -g message-command-style "bg=${p.surface},fg=${p.yellow}"
      set -g mode-style "bg=${p.surfaceHi},fg=${p.fg}"
      set -g clock-mode-colour "${p.pink}"
      set -g copy-mode-match-style "bg=${p.cyan},fg=${p.bgDark}"
      set -g copy-mode-current-match-style "bg=${p.pink},fg=${p.bgDark}"
    '';
  };
}
