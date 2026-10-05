{
  pkgs,
  palette,
  config,
  ...
}:
let
  p = palette;
in
{
  programs.bash = {
    enable = true;
    enableCompletion = true;
    historyControl = [
      "ignoredups"
      "erasedups"
    ];
    historySize = 50000;
    historyFileSize = 100000;
    shellOptions = [
      "histappend"
      "checkwinsize"
      "globstar"
      "autocd"
    ];
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less";
      LESS = "-R";
    };
    shellAliases = {
      ls = "ls --color=auto --group-directories-first";
      ll = "ls -lh";
      la = "ls -lAh";
      grep = "grep --color=auto";
      r = "ranger";
      v = "nvim";
      t = "tmux new-session -A -s main";
    };
    initExtra = import ./bash-prompt.nix {
      inherit palette;
      gitPrompt = "${pkgs.git}/share/bash-completion/completions/git-prompt.sh";
      gpg = if config.programs.gpg.enable then config.programs.gpg.package else null;
    };
  };
  # vi editing mode for bash (and everything else that uses readline).
  programs.readline = {
    enable = true;
    variables = {
      editing-mode = "vi";
      show-mode-in-prompt = true;
      # cursor: bar in insert mode, block in command mode
      vi-ins-mode-string = ''\1\e[6 q\2'';
      vi-cmd-mode-string = ''\1\e[2 q\2'';
      keyseq-timeout = 50;
      completion-ignore-case = true;
      show-all-if-ambiguous = true;
      colored-stats = true;
      colored-completion-prefix = true;
    };
    extraConfig = ''
      $if mode=vi
      set keymap vi-command
      "gg": beginning-of-history
      "G": end-of-history
      "k": history-search-backward
      "j": history-search-forward
      set keymap vi-insert
      "\C-l": clear-screen
      "\C-p": history-search-backward
      "\C-n": history-search-forward
      $endif
    '';
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    colors = {
      "bg+" = p.surface;
      bg = p.bg;
      spinner = p.primary;
      hl = p.primary;
      fg = p.fg;
      header = p.blue;
      info = p.purple;
      pointer = p.primary;
      marker = p.secondary;
      "fg+" = p.fg;
      prompt = p.secondary;
      "hl+" = p.primary;
      border = p.surfaceHi;
    };
  };

  programs.dircolors = {
    enable = true;
    enableBashIntegration = true;
  };
}
