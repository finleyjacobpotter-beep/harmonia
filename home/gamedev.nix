# Game dev on harmonia itself (not Cadmus, which doesn't import this;
# hosts/harmonia/default.nix does): opencode with oh-my-openagent, where every
# agent runs on the local model, Ornith 1.5 9B served as "ai" by the
# llama.cpp server (modules/nixos/llama-server.nix), four agents at a time,
# and opencode offers no other provider; plus Claude Code, and the Blender,
# Godot and radare2 MCP servers for both. The planning rules, skills and
# project templates in ./gamedev are what make the local model good enough.
# See docs/gamedev.md.
{ pkgs, lib, ... }:
let
  mcp = (import ./mcp-servers.nix { inherit pkgs; }).host;

  # The server's context length (Ornith's native maximum) and how many
  # requests it serves at once; change them here and in llama-server.nix
  # together.
  contextLength = 262144;
  parallel = 4;

  local = "local/ai";

  # Ornith's recommended sampling for coding (its model card); the server
  # sets the same, plus top_k 20 and min_p 0.
  ornith = {
    model = local;
    temperature = 0.6;
    top_p = 0.95;
  };

  # Appended to oh-my-openagent's own prompts (and the finisher's whole
  # prompt): where the design docs live and how to write and work through
  # tasks Ornith can finish alone.
  prompt = name: builtins.readFile ./gamedev/prompts/${name}.md;

  skills = [
    "gamedev-plan"
    "godot-4"
    "godot-mcp"
    "blender-mcp"
  ];

  # oh-my-openagent's settings for opencode, in the format of
  # assets/oh-my-opencode.schema.json. The version is pinned in
  # opencode.json's plugin list below.
  opencodeSettings = {
    auto_update = false;

    # Every agent is local.
    agents = {
      prometheus = ornith // {
        prompt_append = prompt "prometheus";
      };
      metis = ornith;
      momus = ornith // {
        prompt_append = prompt "momus";
      };
      sisyphus = ornith // {
        prompt_append = prompt "orchestrator";
      };
      atlas = ornith // {
        prompt_append = prompt "orchestrator";
      };
      sisyphus-junior = ornith // {
        prompt_append = prompt "worker";
      };
      oracle = ornith;
      explore = ornith;
      librarian = ornith;
      # Ornith reads images (its mmproj): editor and viewport screenshots.
      multimodal-looker = ornith;
    };
    # Hephaestus only runs on GPT models.
    disabled_agents = [ "hephaestus" ];
    # Every category too; oh-my-openagent's defaults would put several on
    # other providers.
    categories = lib.genAttrs [
      "ultrabrain"
      "unspecified-high"
      "unspecified-low"
      "deep-low"
      "deep-high"
      "visual-engineering"
      "artistry"
      "quick"
      "writing"
    ] (_: ornith);

    # As many agents at once as the server serves in parallel.
    background_task.providerConcurrency.local = parallel;
  };

  # Since 5.0 oh-my-openagent reads ~/.omo/omo.jsonc (or omo.json), with the
  # opencode settings in its "[opencode]" block; on first start it moves an
  # old ~/.config/opencode/oh-my-openagent.json aside into that format. The
  # migrations are listed as done, so it never tries to rewrite this
  # read-only file.
  omo = pkgs.writeText "omo.jsonc" (
    builtins.toJSON {
      "$schema" =
        "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/omo.schema.json";
      telemetry.enabled = false;
      "[opencode]" = opencodeSettings;
      _migrations = [
        "2026-07-opencode-config-unification"
        "2026-07-codex-config-jsonc"
        "2026-08-reasoning-unification"
        "2026-09-category-deep-split"
        "2026-09-harness-native-rename"
        "2026-09-subscription-provider-rename"
      ];
    }
  );

  config = pkgs.writeText "opencode.json" (
    builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      # oh-my-openagent picks each agent's model; this is for anything else,
      # and small_model (titles, summaries) is local too.
      model = local;
      small_model = local;
      # opencode installs plugins itself on first run (so it needs the
      # internet once).
      plugin = [ "oh-my-openagent@5.1.21" ];
      # Updates come with the pinned nixpkgs, not from opencode itself.
      autoupdate = false;
      agent = {
        # Tab to it for a plain session on the local model.
        ornith = {
          description = "Local: works through one task at a time on Ornith";
          mode = "primary";
          model = local;
          temperature = 0.6;
          top_p = 0.95;
        };
        # /gd-finish: reviews what /ulw-execute built, simplifies it, checks
        # the plan was followed and finishes it before you see it.
        finisher = ornith // {
          description = "Checks, simplifies and finishes a milestone's work";
          mode = "primary";
          prompt = prompt "finisher";
        };
      };
      # The local server is the only provider opencode offers: no Anthropic,
      # OpenAI, opencode Zen or any other built-in one, even with a key set.
      enabled_providers = [ "local" ];
      provider = {
        # The llama.cpp server on this machine (modules/nixos/llama-server.nix),
        # started from the bar.
        local = {
          npm = "@ai-sdk/openai-compatible";
          name = "Local (llama.cpp)";
          options.baseURL = "http://127.0.0.1:1235/v1";
          models.ai = {
            name = "Ornith 1.5 9B (Q4_K_M, MTP)";
            tool_call = true;
            reasoning = true;
            attachment = true;
            modalities = {
              input = [
                "text"
                "image"
              ];
              output = [ "text" ];
            };
            limit = {
              # The server splits its context between the parallel
              # requests, so each agent gets its share and compacts before
              # it runs out.
              context = contextLength / parallel;
              output = 32768;
            };
          };
        };
      };
      mcp = {
        blender = {
          type = "local";
          command = [ "${mcp.blender}/bin/blender-mcp" ];
          enabled = true;
        };
        godot = {
          type = "local";
          command = [ "${mcp.godot}/bin/godot-mcp-attach" ];
          enabled = true;
        };
        radare2 = {
          type = "local";
          command = [ "${mcp.radare2}/bin/r2mcp" ];
          enabled = true;
        };
      };
    }
  );

  # The same servers for Claude Code, as user-scope servers in
  # ~/.claude.json (as on Zelus: programs.claude-code.mcpServers ships them
  # as a plugin, which Claude Code didn't show).
  claudeMcpServers = pkgs.writeText "claude-mcp-servers.json" (
    builtins.toJSON {
      blender = {
        type = "stdio";
        command = "${mcp.blender}/bin/blender-mcp";
        args = [ ];
      };
      godot = {
        type = "stdio";
        command = "${mcp.godot}/bin/godot-mcp-attach";
        args = [ ];
      };
      radare2 = {
        type = "stdio";
        command = "${mcp.radare2}/bin/r2mcp";
        args = [ ];
      };
    }
  );

  # Claude Code's versions of /gd-plan and /gd-finish: the same
  # instructions, for when you'd rather plan or finish there.
  claudeCommand = description: body: ''
    ---
    description: ${description}
    ---

    ${body}
  '';

  # `gamedev-init` in a project folder: copies the design-doc templates into
  # .omo/design (where Prometheus may write) and an AGENTS.md, never
  # overwriting.
  gamedev-init = pkgs.writeShellApplication {
    name = "gamedev-init";
    text = ''
      mkdir -p .omo/design .omo/plans
      cp -r --update=none --no-preserve=mode ${./gamedev/templates/design}/. .omo/design/
      [ -e AGENTS.md ] || install -m 644 ${./gamedev/templates/AGENTS.md} AGENTS.md
      echo "Design docs in $PWD/.omo/design:"
      ls .omo/design
    '';
  };
in
{
  home.packages = [
    pkgs.opencode
    pkgs.radare2
    gamedev-init
  ];

  home.file.".omo/omo.jsonc".source = omo;

  xdg.configFile = {
    "opencode/opencode.json".source = config;
    # Global rules for every agent, and the game dev commands. The skills
    # are Claude Code's (below), which opencode reads too.
    "opencode/AGENTS.md".source = ./gamedev/AGENTS.md;
    "opencode/commands".source = ./gamedev/commands;
  };

  # Claude Code (`claude`, then /login or an API key): same rules, skills
  # and MCP servers, for planning and finishing outside opencode.
  programs.claude-code = {
    enable = true;
    context = ./gamedev/AGENTS.md;
    skills = lib.genAttrs skills (name: ./gamedev/skills/${name}/SKILL.md);
    commands = {
      gd-plan = claudeCommand "Interview me and write an ultrawork plan for the next milestone" (
        prompt "prometheus"
        + ''

          Here in Claude Code there is no Metis or Momus: before writing the
          plan, list what the interview missed and ask about it; after writing
          it, critique every task card as Momus would and fix it.

          The milestone: $ARGUMENTS
        ''
      );
      gd-finish = claudeCommand "Check, simplify and finish the milestone ultrawork built" (
        prompt "finisher"
        + ''

          The milestone: $ARGUMENTS
        ''
      );
    };
  };

  home.activation.claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="$HOME/.claude.json"
    [ -s "$f" ] || echo '{}' > "$f"
    tmp=$(mktemp "$f.XXXXXX")
    ${pkgs.jq}/bin/jq --slurpfile servers ${claudeMcpServers} \
      '.mcpServers = ((.mcpServers // {}) + $servers[0])' "$f" > "$tmp"
    run mv "$tmp" "$f"
  '';
}
