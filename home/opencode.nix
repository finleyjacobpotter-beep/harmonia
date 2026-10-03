# opencode on Zelus (imported by zelus/default.nix for user c): providers,
# oh-my-openagent and the Blender and Godot MCP servers. The host's
# `opencode` command (home/zelus.nix) starts it over `ssh zelus` with the
# Anthropic key from the host's pass. See docs/opencode.md.
{ pkgs, zelus, ... }:
let
  # The same pinned servers Claude Code uses (home/mcp-servers.nix), run
  # right here on Zelus; ssh zelus connects them to the editors on the host.
  mcp = import ./mcp-servers.nix { inherit pkgs; };

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
      "$schema" =
        "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/v5.1.11/assets/oh-my-opencode.schema.json";
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
      # opencode installs plugins itself on first run (so it needs the
      # internet once: start it in the permissive firewall mode).
      plugin = [ "oh-my-openagent@5.1.11" ];
      # Updates come with the pinned nixpkgs, not from opencode itself.
      autoupdate = false;
      provider = {
        # The host's LM Studio server (Developer tab), reached through the
        # host's end of Zelus's tap (modules/nixos/zelus.nix). The model key is
        # LM Studio's API identifier for Jackrong/Qwopus3.5-9B-v3-GGUF (Q4_K_M).
        lmstudio = {
          npm = "@ai-sdk/openai-compatible";
          name = "LM Studio (host)";
          options.baseURL = "http://${zelus.hostAddress}:${toString zelus.lmstudioPort}/v1";
          models."qwopus3.5-9b-v3".name = "Qwopus 3.5 9B v3 (Q4_K_M)";
        };
        # The key comes from the host's pass with each `opencode` (ssh
        # SendEnv), never from disk.
        anthropic.options.apiKey = "{env:ANTHROPIC_API_KEY}";
      };
      mcp = {
        blender = {
          type = "local";
          command = [ "${mcp.blender}/bin/blender-mcp" ];
          enabled = true;
        };
        godot = {
          type = "local";
          command = [ "${mcp.godot}/bin/godot-mcp" ];
          enabled = true;
        };
      };
    }
  );
in
{
  home.packages = [ pkgs.opencode ];

  xdg.configFile."opencode/opencode.json".source = config;
  xdg.configFile."opencode/oh-my-openagent.json".source = omo;
}
