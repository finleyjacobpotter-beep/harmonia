# Dionysus's dev toolset, on the host itself (not in a VM): Claude Code plus
# the language toolchains it leans on and the Rust command-line tools. On
# harmonia these live in a microVM (Zelus); Dionysus has no microVMs, so they
# run natively here and are built from nixpkgs, which keeps them buildable on
# both aarch64 and x86_64.
#
# opencode and its oh-my-openagent config used to live here too; they were
# dropped at the user's request.
{ pkgs, lib, ... }:
let
  # The classic command → its Rust replacement, only in your own interactive
  # shells: Claude Code (CLAUDECODE) runs commands through bash too and
  # expects the classic tools' flags.
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
    # Toolchains Claude Code leans on.
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

  # Claude Code.
  programs.claude-code.enable = true;

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

  programs.bash.initExtra = ''
    if [[ -z ''${CLAUDECODE-} ]]; then
    ${
      lib.concatStrings (
        lib.mapAttrsToList (name: cmd: "  alias ${name}=${lib.escapeShellArg cmd}\n") rustAliases
      )
    }fi
  '';
}
