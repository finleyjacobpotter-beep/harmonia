# opencode (installed from Flathub in modules/nixos/studio.nix): providers,
# MCP servers and the `opencode` launcher that reads API keys from pass.
# See docs/opencode.md.
{ pkgs, lib, ... }:
let
  app = "ai.opencode.opencode";

  # The MCP servers run on the host (opencode reaches them with
  # flatpak-spawn --host), pinned to a release so a new upstream commit
  # doesn't run unreviewed.
  blenderMcp = pkgs.writeShellApplication {
    name = "blender-mcp";
    runtimeInputs = [ pkgs.uv ];
    text = ''exec uvx mcp-for-blender==2.1.3 "$@"'';
  };
  godotMcp = pkgs.writeShellApplication {
    name = "godot-mcp";
    runtimeInputs = [
      pkgs.uv
      pkgs.git
    ];
    text = ''exec uvx --from git+https://github.com/bebabinlarsson-blip/Godot-MCP.git@v5.0.9 godot-ai "$@"'';
  };

  host = cmd: [
    "flatpak-spawn"
    "--host"
    cmd
  ];

  local = "lmstudio/qwopus3.5-9b-v3";
  opus = "anthropic/claude-opus-5-5";
  sonnet = "anthropic/claude-sonnet-5-5";

  # oh-my-openagent: Claude for planning, orchestration and review, the local
  # model for searching and small edits. Claude agents fall back to the local
  # model when there's no API key or the call fails.
  claude = model: {
    inherit model;
    fallback_models = [ local ];
  };
  omo = pkgs.writeText "oh-my-openagent.json" (
    builtins.toJSON {
      "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/v5.1.11/assets/oh-my-opencode.schema.json";
      # The version is pinned in opencode.json's plugin list below.
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

  config = pkgs.writeText "opencode.json" (
    builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      model = local;
      # opencode installs plugins itself (with its bundled bun) on first run.
      plugin = [ "oh-my-openagent@5.1.11" ];
      provider = {
        # LM Studio's local server (Developer tab), localhost:1234. The model
        # key is LM Studio's API identifier for Jackrong/Qwopus3.5-9B-v3-GGUF
        # (Q4_K_M).
        lmstudio = {
          npm = "@ai-sdk/openai-compatible";
          name = "LM Studio (local)";
          options.baseURL = "http://127.0.0.1:1234/v1";
          models."qwopus3.5-9b-v3".name = "Qwopus 3.5 9B v3 (Q4_K_M)";
        };
        # The key comes from pass through the launcher below, never from disk.
        anthropic.options.apiKey = "{env:ANTHROPIC_API_KEY}";
      };
      mcp = {
        blender = {
          type = "local";
          command = host "${blenderMcp}/bin/blender-mcp";
          enabled = true;
        };
        godot = {
          type = "local";
          command = host "${godotMcp}/bin/godot-mcp";
          enabled = true;
        };
      };
    }
  );

  # Reads the Anthropic key from pass (pinentry asks in this terminal if
  # gpg-agent hasn't cached the passphrase), then starts opencode detached.
  # flatpak passes the environment through to the app.
  launcher = pkgs.writeShellApplication {
    name = "opencode";
    runtimeInputs = [
      pkgs.pass
      pkgs.flatpak
      pkgs.util-linux
    ];
    text = ''
      export PASSWORD_STORE_DIR="''${PASSWORD_STORE_DIR:-$HOME/.local/share/password-store}"
      if key=$(pass show opencode/anthropic-api-key 2>/dev/null | head -n1) && [ -n "$key" ]; then
        export ANTHROPIC_API_KEY="$key"
      else
        echo "opencode: no key in pass at opencode/anthropic-api-key; Claude won't be available." >&2
        sleep 2
      fi
      setsid -f flatpak run ${app} "$@" >/dev/null 2>&1
    '';
  };
in
{
  home.packages = [ launcher ];

  # Flatpak apps can't follow symlinks into /nix/store, so the config is
  # copied into the app's own XDG_CONFIG_HOME. Edits made in the app are
  # replaced on the next switch; change this file instead.
  home.activation.opencodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -Dm644 ${config} "$HOME/.var/app/${app}/config/opencode/opencode.json"
    run install -Dm644 ${omo} "$HOME/.var/app/${app}/config/opencode/oh-my-openagent.json"
  '';
}
