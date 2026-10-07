# Game dev on harmonia itself (not Cadmus, which doesn't import this;
# hosts/harmonia/default.nix does): opencode with oh-my-openagent, where
# Claude only writes the plans and finishes the work, and the local Ornith
# 1.5 9B in LM Studio does everything in between, four agents at a time;
# plus Claude Code, and the Blender and Godot MCP servers for both. Every
# Claude agent falls back to Ornith, so work carries on when the credits run
# out. The planning rules, skills and project templates in ./gamedev are
# what make the local model good enough. See docs/gamedev.md.
{ pkgs, lib, ... }:
let
  mcp = (import ./mcp-servers.nix { inherit pkgs; }).host;

  # LM Studio's API identifier for the model (bartowski/Ornith-1.5-9B-GGUF,
  # Q6_K); the context length it's loaded with (Ornith's native maximum);
  # and how many requests LM Studio serves at once (its "Max concurrent
  # predictions"). Change them here and in LM Studio together.
  ornithId = "ornith-1.5-9b";
  contextLength = 262144;
  parallel = 4;

  local = "lmstudio/${ornithId}";
  opus = "anthropic/claude-opus-5-5";
  sonnet = "anthropic/claude-sonnet-5-5";

  # Ornith's recommended sampling for coding (its model card); LM Studio's
  # per-model defaults carry the rest (top_k 20, min_p 0).
  ornith = {
    model = local;
    temperature = 0.6;
    top_p = 0.95;
  };

  # A Claude agent: falls back down the chain to Ornith when Anthropic
  # refuses (no key, credits gone, rate limited, overloaded).
  claude =
    model: extra:
    {
      inherit model;
      fallback_models = (if model == opus then [ sonnet ] else [ ]) ++ [ local ];
    }
    // extra;

  # A Claude model for opencode's provider list: price in $ per million
  # tokens (models.dev, 2026-10).
  claudeModel = name: cost: {
    inherit name cost;
    tool_call = true;
    reasoning = true;
    attachment = true;
    limit = {
      context = 1000000;
      output = 128000;
    };
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

    # Claude plans; Ornith does everything else.
    agents = {
      # The plan: the one place Claude is used, besides the finisher.
      prometheus = claude opus { prompt_append = prompt "prometheus"; };
      metis = claude sonnet { };
      momus = claude sonnet { prompt_append = prompt "momus"; };
      # The finisher (opencode.json), so it falls back to Ornith too.
      finisher = claude opus { };
      # Running the plan (/ulw-execute) and everything else: local.
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
    # Every category is local; oh-my-openagent's defaults would put several
    # on Claude.
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

    # Off by default: retry on the next model in fallback_models when a
    # call fails. Quota errors ("credit balance is too low") and a missing
    # key always count; these status codes do too. Once it falls back it
    # stays there for the session.
    runtime_fallback = {
      enabled = true;
      retry_on_errors = [
        401
        402
        429
        500
        502
        503
        504
        529
      ];
      max_fallback_attempts = 3;
      notify_on_fallback = true;
      restore_primary_after_cooldown = false;
    };

    # As many local agents at once as LM Studio serves in parallel.
    background_task.providerConcurrency = {
      lmstudio = parallel;
      anthropic = 2;
    };
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
        finisher = {
          description = "Claude: checks, simplifies and finishes a milestone's work";
          mode = "primary";
          model = opus;
          prompt = prompt "finisher";
        };
      };
      provider = {
        # Claude, with the key from /connect. The two models are also listed
        # here, with their prices, so opencode knows them (and shows what a
        # session cost) even when its model list is older than they are.
        anthropic.models = {
          claude-opus-5-5 = claudeModel "Claude Opus 5.5" {
            input = 4;
            output = 20;
            cache_read = 0.2;
            cache_write = 5;
          };
          claude-sonnet-5-5 = claudeModel "Claude Sonnet 5.5" {
            input = 2;
            output = 10;
            cache_read = 0.2;
            cache_write = 2.5;
          };
        };
        # LM Studio's local server (Developer tab) on this machine.
        lmstudio = {
          npm = "@ai-sdk/openai-compatible";
          name = "LM Studio";
          options.baseURL = "http://127.0.0.1:1234/v1";
          models.${ornithId} = {
            name = "Ornith 1.5 9B (Q6_K)";
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
              # LM Studio's one KV cache is shared by the parallel requests,
              # so each agent gets its share of it and compacts before
              # four together could overflow it.
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
      };
    }
  );

  # The same two servers for Claude Code, as user-scope servers in
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
