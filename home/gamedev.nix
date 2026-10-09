# AI agents and game dev tooling on harmonia itself (not Cadmus, which
# doesn't import this; hosts/harmonia/default.nix does): pi and Claude Code,
# both with the Blender, Godot and radare2 MCP servers and the skills, with
# Godot's server running as a user service next to the editor. pi runs on
# the local model (modules/nixos/llama-server.nix) and takes a project's
# instructions from its .agents/ only (./pi/agents-dir.ts); otherwise it's
# on its defaults. See docs/pi.md and docs/gamedev.md.
{ pkgs, lib, ... }:
let
  mcpServers = import ./mcp-servers.nix { inherit pkgs; };
  mcp = mcpServers.host;
  pi = pkgs.callPackage ../pkgs/pi.nix { };

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

  # The MCP servers, in the shape both ~/.claude.json and pi's mcp.json
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

  # What pi gets in ~/.pi/agent, merged into the files it keeps there (it
  # writes them too: /mcp, /model, /settings), so only these entries are
  # reset on a switch and everything you add stays.
  piConfig = pkgs.writeText "pi-agent.json" (
    builtins.toJSON {
      # The llama.cpp server on this machine (modules/nixos/llama-server.nix),
      # started from the bar. It takes no key, but pi lists a provider's
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
    }
  );

  # `gamedev-init` in a project folder: copies the design-doc templates into
  # .agents/design, the instructions into .agents/AGENTS.md and a CLAUDE.md
  # that points Claude Code at them, never overwriting.
  gamedev-init = pkgs.writeShellApplication {
    name = "gamedev-init";
    text = ''
      mkdir -p .agents/design
      cp -r --update=none --no-preserve=mode ${./gamedev/templates/design}/. .agents/design/
      [ -e .agents/AGENTS.md ] || install -m 644 ${./gamedev/templates/AGENTS.md} .agents/AGENTS.md
      [ -e CLAUDE.md ] || echo "@.agents/AGENTS.md" > CLAUDE.md
      echo "Instructions in $PWD/.agents/AGENTS.md, design docs in $PWD/.agents/design:"
      ls .agents/design
    '';
  };
in
{
  home.packages = [
    pi
    pkgs.radare2
    gamedev-init
  ];

  # Instructions from .agents/ only, nothing from a project's .pi/.
  home.file.".pi/agent/extensions/agents-dir.ts".source = ./pi/agents-dir.ts;

  # Claude Code (`claude`, then /login or an API key) with the skills (which
  # pi reads too) and the MCP servers. Neither agent gets global rules: each
  # project brings its own .agents/AGENTS.md (CLAUDE.md imports it).
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

  # pi's own files, merged in on every switch. What's set here wins (the
  # provider and MCP servers by name, the settings key by key); everything
  # else you add with /mcp, /settings or by hand stays. A session starts on
  # the local model, and projects are never trusted (./pi/agents-dir.ts says
  # so too).
  home.activation.piConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.pi/agent"
    merge() {
      f="$HOME/.pi/agent/$1"
      [ -s "$f" ] || echo '{}' > "$f"
      tmp=$(mktemp "$f.XXXXXX")
      ${pkgs.jq}/bin/jq --slurpfile nix ${piConfig} "$2" "$f" > "$tmp"
      run mv "$tmp" "$f"
    }
    merge models.json '.providers = ((.providers // {}) + $nix[0].models.providers)'
    merge mcp.json '.mcpServers = ((.mcpServers // {}) + $nix[0].mcp.mcpServers)'
    merge settings.json '
      .skills = ((.skills // []) - ["~/.claude/skills"] + ["~/.claude/skills"])
      | .defaultProvider = "local" | .defaultModel = "ai"
      | .defaultProjectTrust = "never"
      | .enableInstallTelemetry = false'
  '';
}
