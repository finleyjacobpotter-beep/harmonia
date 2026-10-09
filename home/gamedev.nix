# AI agents and game dev tooling on harmonia itself (not Cadmus, which
# doesn't import this; hosts/harmonia/default.nix does): OmO, oh-my-openagent's
# native agent (`omo`), and Claude Code, both with the Blender, Godot and
# radare2 MCP servers and the skills, with Godot's server running as a user
# service next to the editor. Every omo model, the main session's and every
# agent's and category's, is the local model (modules/nixos/llama-server.nix);
# otherwise omo is on its defaults. See docs/omo.md and docs/gamedev.md.
{ pkgs, lib, ... }:
let
  # The local model as omo names it (provider "local", model "ai", below).
  local = "local/ai";

  mcpServers = import ./mcp-servers.nix { inherit pkgs; };
  mcp = mcpServers.host;
  omo = pkgs.callPackage ../pkgs/omo.nix { };

  skills = [
    "godot-4"
    "godot-mcp"
    "blender-mcp"
  ];
  # When to use the Rust tools (home/rust-tools.nix), whose aliases agent
  # shells don't get.
  rustSkills = [
    "rust-search"
    "rust-edit"
    "rust-inspect"
  ];

  # godot-ai's defaults, which the editor plugin expects.
  godotPorts = "--port 8000 --ws-port 9500";

  # The MCP servers, in the shape both ~/.claude.json and omo's mcp.json
  # take.
  mcpServerConfig = {
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
  };
  claudeMcpServers = pkgs.writeText "claude-mcp-servers.json" (builtins.toJSON mcpServerConfig);

  # What omo gets in ~/.omo/agent, merged into the files it keeps there
  # (it writes them too: /mcp, /model, /settings), so only these entries
  # are reset on a switch and everything you add stays.
  omoConfig = pkgs.writeText "omo-agent.json" (
    builtins.toJSON {
      # The llama.cpp server on this machine (modules/nixos/llama-server.nix),
      # started from the bar. It takes no key, but omo lists a provider's
      # models only once it has one.
      models.providers.local = {
        name = "Local (llama.cpp)";
        baseUrl = "http://127.0.0.1:1235/v1";
        api = "openai-completions";
        apiKey = "none";
        models = [
          {
            id = "ai";
            name = "Ornith 1.5 9B (Q4_K_M, MTP)";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            # The server splits its context between its parallel requests
            # (llama-server.nix); this is one request's share.
            contextWindow = 131072;
            maxTokens = 32768;
          }
        ];
      };
      mcp.mcpServers = mcpServerConfig;

      # omo's settings (~/.omo/omo.jsonc): a one-model chain for every builtin
      # agent and category, so nothing falls back to another provider.
      omo =
        let
          onlyLocal =
            names:
            lib.genAttrs names (_: {
              models = [ local ];
            });
        in
        {
          telemetry.enabled = false;
          "[native]" = {
            # Headless and desktop sessions; the TUI's is in settings.json.
            model_profile = local;
            agents = onlyLocal [
              "explore"
              "librarian"
              "plan-consultant"
              "plan-reviewer"
              "omo-native-gate-reviewer"
              "omo-native-code-reviewer"
              "omo-native-qa-executor"
            ];
            categories = onlyLocal [
              "architect"
              "artistry"
              "deep-high"
              "deep-low"
              "quick"
              "ultrabrain"
              "unspecified-high"
              "unspecified-low"
              "visual-engineering"
              "writing"
            ];
            # As many tasks at once as the server serves (llama-server.nix);
            # the rest queue.
            task.provider_concurrency.local = 4;
            # Its desktop engine is a binary omo unpacks unpatched, so it
            # can't start on NixOS.
            computer.enabled = false;
          };
        };
    }
  );
  # `gamedev-init` in a project folder: copies the design-doc templates into
  # .omo/design and an AGENTS.md, never overwriting.
  gamedev-init = pkgs.writeShellApplication {
    name = "gamedev-init";
    text = ''
      mkdir -p .omo/design
      cp -r --update=none --no-preserve=mode ${./gamedev/templates/design}/. .omo/design/
      [ -e AGENTS.md ] || install -m 644 ${./gamedev/templates/AGENTS.md} AGENTS.md
      echo "Design docs in $PWD/.omo/design:"
      ls .omo/design
    '';
  };
in
{
  home.packages = [
    omo
    pkgs.radare2
    gamedev-init
  ];

  # Claude Code (`claude`, then /login or an API key) with the skills (which
  # omo reads too) and the MCP servers. Neither agent gets global rules: each
  # project brings its own AGENTS.md or CLAUDE.md.
  programs.claude-code = {
    enable = true;
    skills =
      lib.genAttrs skills (name: ./gamedev/skills/${name}/SKILL.md)
      // lib.genAttrs rustSkills (name: ./skills/${name}/SKILL.md);
  };

  # The Godot MCP server, in your session: running before the editor opens,
  # so the plugin adopts it instead of starting its own, and the editor and
  # every agent share one server (each agent's godot-mcp-attach is a stdio
  # bridge to it). The record is removed first and waited for after, so a
  # bridge never reads a stale one.
  systemd.user.services.godot-ai = {
    Unit.Description = "Godot MCP server (godot-ai) for the editor and the agents";
    Install.WantedBy = [ "default.target" ];
    Service = {
      # The plugin reads the record from $XDG_CONFIG_HOME/godot-ai/capabilities.
      Environment = "GODOT_AI_CAPABILITY_DIR=%h/.config/godot-ai/capabilities";
      ExecStartPre = "${pkgs.coreutils}/bin/rm -f \${GODOT_AI_CAPABILITY_DIR}/http-8000.json";
      ExecStart = "${mcpServers.godot}/bin/godot-mcp --transport streamable-http ${godotPorts}";
      ExecStartPost = toString (
        pkgs.writeShellScript "godot-ai-wait" ''
          # uv downloads the server on its first start.
          for _ in {1..600}; do
            [ -e "$GODOT_AI_CAPABILITY_DIR/http-8000.json" ] && exit 0
            ${pkgs.coreutils}/bin/sleep 0.5
          done
          exit 1
        ''
      );
      TimeoutStartSec = 330;
      Restart = "on-failure";
      RestartSec = 5;
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

  # omo's own files, merged in on every switch. What's set here wins
  # (the provider and MCP servers by name, the models in omo.jsonc key by
  # key); everything else you add with /mcp, /settings or by hand stays. A
  # file jq can't parse (omo.jsonc with comments) is left alone, with a
  # warning.
  home.activation.omoConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run mkdir -p "$HOME/.omo/agent"
    merge() {
      f="$HOME/.omo/$1"
      # The read-only omo.jsonc this used to link in: keep only its
      # migration markers.
      if [ -L "$f" ]; then
        old=$(${pkgs.jq}/bin/jq -c '{_migrations}' "$f")
        run rm "$f"
        echo "$old" > "$f"
      fi
      [ -s "$f" ] || echo '{}' > "$f"
      tmp=$(mktemp "$f.XXXXXX")
      if ${pkgs.jq}/bin/jq --slurpfile nix ${omoConfig} "$2" "$f" > "$tmp"; then
        run mv "$tmp" "$f"
      else
        rm -f "$tmp"
        warnEcho "$f isn't plain JSON; set omo's local-only settings in it by hand (home/gamedev.nix)"
      fi
    }
    merge agent/models.json '.providers = ((.providers // {}) + $nix[0].models.providers)'
    merge agent/mcp.json '.mcpServers = ((.mcpServers // {}) + $nix[0].mcp.mcpServers)'
    merge agent/settings.json '
      .skills = ((.skills // []) - ["~/.claude/skills"] + ["~/.claude/skills"])
      | .defaultProvider = "local" | .defaultModel = "ai"'
    merge omo.jsonc '. * $nix[0].omo'
  '';
}
