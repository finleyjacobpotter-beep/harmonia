{ pkgs, palette, ... }:
let
  p = palette;
  # 24-bit colour escape for a palette entry, wrapped for PS1.
  rgb =
    hex:
    let
      h = p.strip hex;
      byte = i: toString (fromTOML "x = 0x${builtins.substring i 2 h}").x;
    in
    ''\[\e[38;2;${byte 0};${byte 2};${byte 4}m\]'';
  reset = ''\[\e[0m\]'';
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
      zen = "flatpak run app.zen_browser.zen";
      rebuild = "sudo nixos-rebuild switch --flake ~/snowflakes";
    };
    initExtra = ''
      source ${pkgs.git}/share/bash-completion/completions/git-prompt.sh
      GIT_PS1_SHOWDIRTYSTATE=1
      GIT_PS1_SHOWUNTRACKEDFILES=1

      __mw_prompt() {
        local status=$?
        local mark="${rgb p.pink}❯"
        [ $status -ne 0 ] && mark="${rgb p.redBright}❯"
        PS1="\n${rgb p.cyan}\u${rgb p.muted}@${rgb p.purple}\h ${rgb p.yellow}\w${rgb p.pink}$(__git_ps1 '  %s')${reset}\n$mark${reset} "
      }
      PROMPT_COMMAND="__mw_prompt''${PROMPT_COMMAND:+;$PROMPT_COMMAND}"

      # Colours for less / man pages
      export LESS_TERMCAP_md=$'\e[1;38;2;244;114;182m'   # bold      -> pink
      export LESS_TERMCAP_us=$'\e[4;38;2;34;211;238m'    # underline -> cyan
      export LESS_TERMCAP_so=$'\e[38;2;30;30;46;48;2;254;240;138m' # standout -> yellow bg
      export LESS_TERMCAP_me=$'\e[0m'
      export LESS_TERMCAP_ue=$'\e[0m'
      export LESS_TERMCAP_se=$'\e[0m'
    '';
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    colors = {
      "bg+" = p.surface;
      bg = p.bg;
      spinner = p.pink;
      hl = p.pink;
      fg = p.fg;
      header = p.blue;
      info = p.purple;
      pointer = p.pink;
      marker = p.cyan;
      "fg+" = p.fg;
      prompt = p.cyan;
      "hl+" = p.pink;
      border = p.surfaceHi;
    };
  };

  programs.dircolors = {
    enable = true;
    enableBashIntegration = true;
  };
}
