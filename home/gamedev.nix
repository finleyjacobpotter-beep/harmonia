# Game dev tooling on harmonia itself (not Cadmus, which doesn't import
# this; hosts/harmonia/default.nix does): Claude Code with the Blender, Godot
# and radare2 MCP servers and the skills (pi, which reads them too, is in
# ./ai.nix), Godot's server running as a user service next to the editor,
# and `gamedev-init`. See docs/gamedev.md and docs/pi.md.
{ pkgs, lib, ... }:
let
  mcpServers = import ./mcp-servers.nix { inherit pkgs; };

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

  claudeMcpServers = pkgs.writeText "claude-mcp-servers.json" (
    builtins.toJSON mcpServers.clientConfig
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
    pkgs.radare2
    gamedev-init
  ];

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
}
