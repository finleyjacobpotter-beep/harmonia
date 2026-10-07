# Dionysus's native command-line tooling: the language toolchains and the
# Rust command-line tools. On harmonia the Rust tools live in a microVM
# (Zelus); Dionysus has no microVMs, so they run natively here and are built
# from nixpkgs, which keeps them buildable on both aarch64 and x86_64.
#
# The AI coding agents (Claude Code and opencode) used to live here too; both
# were dropped at the user's request.
{ pkgs, lib, ... }:
let
  # The classic command → its Rust replacement. Set as raw aliases (not
  # programs.bash.shellAliases) so they override home/bash.nix's own aliases
  # for the same names instead of conflicting with them; initExtra only runs
  # in interactive shells, so scripts still get the classic tools.
  rustAliases = {
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
    # Language toolchains.
    uv
    nodejs
    python3
    gcc
    gnumake
    # The Rust command-line tools (home/rust-tools on harmonia's VMs).
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

  # cd learns your directories; bat and delta follow the terminal's colours.
  programs.zoxide = {
    enable = true;
    options = [
      "--cmd"
      "cd"
    ];
  };
  programs.bat = {
    enable = true;
    config.theme = "ansi";
  };
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options.syntax-theme = "ansi";
  };

  programs.bash.initExtra = "${lib.concatStrings (
    lib.mapAttrsToList (name: cmd: "alias ${name}=${lib.escapeShellArg cmd}\n") rustAliases
  )}";
}
