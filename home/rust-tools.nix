# Rust command-line tools, on the host, Nike and Zelus alike (imported by
# home/default.nix and lib/microvm-guest.nix). Your interactive
# bash gets aliases from the classic commands to them. On Zelus, Claude Code
# and opencode also get skills for them (zelus/skills/).
{ pkgs, lib, ... }:
let
  # The classic command → its Rust replacement. `command grep` (or \grep)
  # still runs the original.
  aliases = {
    grep = "rg";
    find = "fd";
    cat = "bat --paging=never --style=plain";
    ls = "eza --group-directories-first";
    ll = "eza -l --git --group-directories-first";
    la = "eza -la --git --group-directories-first";
    tree = "eza --tree";
    du = "dust";
    df = "dysk";
    top = "btm";
    ps = "procs";
    diff = "difft";
  };
in
{
  home.packages = with pkgs; [
    ripgrep # rg: grep
    fd # find
    bat # cat with syntax highlighting
    eza # ls
    dust # du
    dysk # df
    bottom # btm: top
    procs # ps
    sd # sed's s/// with plain regex syntax
    difftastic # difft: diff that understands syntax
    ast-grep # structural search and rewrite
    jaq # jq
    xh # curl/httpie for HTTP APIs
    hyperfine # benchmarks
    tokei # lines of code
    watchexec # rerun a command on file changes
    just # task runner
    ouch # tar/zip/7z in one command
    choose # cut/awk field picking
    tealdeer # tldr pages
  ];

  # cd learns your directories (`cd proj` jumps to the best match).
  programs.zoxide = {
    enable = true;
    options = [
      "--cmd"
      "cd"
    ];
  };
  # bat follows the terminal's Miami Wind colours.
  programs.bat = {
    enable = true;
    config.theme = "ansi";
  };
  # git diff, log -p and show through delta.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options.syntax-theme = "ansi";
  };

  # Only in your own shells: Claude Code (CLAUDECODE) and opencode (OPENCODE)
  # run commands through bash too, and expect the classic tools' flags.
  programs.bash.initExtra = ''
    if [[ -z ''${CLAUDECODE-} && -z ''${OPENCODE-} ]]; then
    ${
      lib.concatStrings (
        lib.mapAttrsToList (name: cmd: "  alias ${name}=${lib.escapeShellArg cmd}\n") aliases
      )
    }fi
  '';
}
