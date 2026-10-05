# Dionysus's dev toolset, on the host itself (not in a VM): Blender, Godot,
# opencode and Claude Code with the Blender and Godot MCP servers, plus the
# Rust command-line tools. On harmonia these live in a microVM (Zelus) or in
# flatpak sandboxes; Dionysus has no microVMs, so they run natively here and
# are built from nixpkgs, which keeps them buildable on both aarch64 and
# x86_64.
{ pkgs, lib, ... }:
let
  # The Blender and Godot MCP servers, pinned to a release so a new upstream
  # commit doesn't run unreviewed. uv runs them with nixpkgs' Python: a Python
  # uv downloads itself can't run on NixOS.
  blenderMcp = pkgs.writeShellApplication {
    name = "blender-mcp";
    runtimeInputs = [ pkgs.uv ];
    text = ''
      export UV_PYTHON=${pkgs.python3}/bin/python3
      exec uvx mcp-for-blender==2.1.3 "$@"
    '';
  };
  godotMcp = pkgs.writeShellApplication {
    name = "godot-mcp";
    runtimeInputs = [
      pkgs.uv
      pkgs.git
    ];
    text = ''
      export UV_PYTHON=${pkgs.python3}/bin/python3
      exec uvx --from git+https://github.com/bebabinlarsson-blip/Godot-MCP.git@v5.0.9 godot-ai "$@"
    '';
  };

  # opencode's providers and MCP servers. The MCP servers run right here, so
  # the commands point straight at the wrappers above (no flatpak-spawn).
  local = "lmstudio/qwopus3.5-9b-v3";
  opus = "anthropic/claude-opus-5-5";
  sonnet = "anthropic/claude-sonnet-5-5";
  claude = model: {
    inherit model;
    fallback_models = [ local ];
  };
  omo = pkgs.writeText "oh-my-openagent.json" (
    builtins.toJSON {
      "$schema" =
        "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/v5.1.11/assets/oh-my-opencode.schema.json";
      auto_update = false;
      telemetry = false;
      agents = {
        sisyphus = claude opus;
        prometheus = claude opus;
        oracle = claude opus;
        hephaestus = claude sonnet;
        atlas = claude sonnet;
        metis = claude sonnet;
        momus = claude sonnet;
        multimodal-looker = claude sonnet;
        sisyphus-junior.model = local;
        explore.model = local;
        librarian.model = local;
      };
      categories = {
        ultrabrain = claude opus;
        deep = claude sonnet;
        visual-engineering = claude sonnet;
        artistry = claude sonnet;
        unspecified-high = claude sonnet;
        quick.model = local;
        writing.model = local;
        unspecified-low.model = local;
      };
    }
  );
  opencodeConfig = pkgs.writeText "opencode.json" (
    builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      model = local;
      # opencode installs plugins itself on first run (so it needs the
      # internet once).
      plugin = [ "oh-my-openagent@5.1.11" ];
      autoupdate = false;
      provider = {
        # A local LM Studio server (its Developer tab), if you run one.
        lmstudio = {
          npm = "@ai-sdk/openai-compatible";
          name = "LM Studio (local)";
          options.baseURL = "http://127.0.0.1:1234/v1";
          models."qwopus3.5-9b-v3".name = "Qwopus 3.5 9B v3 (Q4_K_M)";
        };
        # Set ANTHROPIC_API_KEY in your environment, or use opencode's
        # /connect, to reach Claude.
        anthropic.options.apiKey = "{env:ANTHROPIC_API_KEY}";
      };
      mcp = {
        blender = {
          type = "local";
          command = [ "${blenderMcp}/bin/blender-mcp" ];
          enabled = true;
        };
        godot = {
          type = "local";
          command = [ "${godotMcp}/bin/godot-mcp" ];
          enabled = true;
        };
      };
    }
  );

  # The classic command → its Rust replacement, only in your own interactive
  # shells: Claude Code (CLAUDECODE) and opencode (OPENCODE) run commands
  # through bash too and expect the classic tools' flags.
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
    # The creative editors the MCP servers drive.
    blender
    godot_4
    # The coding agents.
    opencode
    # Toolchains the agents and the MCP servers lean on.
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

  # Claude Code, with the same Blender and Godot MCP servers.
  programs.claude-code = {
    enable = true;
    mcpServers = {
      blender.command = "${blenderMcp}/bin/blender-mcp";
      godot.command = "${godotMcp}/bin/godot-mcp";
    };
  };

  # opencode's config (native, so a plain symlink into the store is fine).
  xdg.configFile."opencode/opencode.json".source = opencodeConfig;
  xdg.configFile."opencode/oh-my-openagent.json".source = omo;

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
    if [[ -z ''${CLAUDECODE-} && -z ''${OPENCODE-} ]]; then
    ${
      lib.concatStrings (
        lib.mapAttrsToList (name: cmd: "  alias ${name}=${lib.escapeShellArg cmd}\n") rustAliases
      )
    }fi
  '';
}
