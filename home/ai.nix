# pi, the coding agent, on harmonia itself (not Cadmus, which doesn't
# import this; hosts/harmonia/default.nix does): with the Blender, Godot
# and radare2 MCP servers (./mcp-servers.nix) and Claude Code's skills (./gamedev.nix), and
# a project's instructions from its .agents/ only (./pi/agents-dir.ts);
# otherwise on its defaults. See docs/pi.md.
{ pkgs, lib, ... }:
let
  mcpServers = import ./mcp-servers.nix { inherit pkgs; };
  pi = pkgs.callPackage ../pkgs/pi.nix { };

  # What pi gets in ~/.pi/agent, merged into the files it keeps there (it
  # writes them too: /mcp, /model, /settings), so only these entries are
  # reset on a switch and everything you add stays.
  piConfig = pkgs.writeText "pi-agent.json" (
    builtins.toJSON {
      mcp.mcpServers = mcpServers.clientConfig;
    }
  );
in
{
  home.packages = [ pi ];

  # Instructions from .agents/ only, nothing from a project's .pi/.
  home.file.".pi/agent/extensions/agents-dir.ts".source = ./pi/agents-dir.ts;

  # pi's own files, merged in on every switch. What's set here wins (the
  # MCP servers by name, the settings key by key); everything else you add
  # with /mcp, /settings or by hand stays. Projects are never trusted
  # (./pi/agents-dir.ts says so too). The `local` provider and startup model
  # an older version set here, for the llama.cpp server that was removed,
  # are taken out again.
  home.activation.piConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.pi/agent"
    merge() {
      f="$HOME/.pi/agent/$1"
      [ -s "$f" ] || echo '{}' > "$f"
      tmp=$(mktemp "$f.XXXXXX")
      ${pkgs.jq}/bin/jq --slurpfile nix ${piConfig} "$2" "$f" > "$tmp"
      run mv "$tmp" "$f"
    }
    merge models.json 'del(.providers.local?)'
    merge mcp.json '.mcpServers = ((.mcpServers // {}) + $nix[0].mcp.mcpServers)'
    merge settings.json '
      .skills = ((.skills // []) - ["~/.claude/skills"] + ["~/.claude/skills"])
      | if .defaultProvider == "local" then del(.defaultProvider, .defaultModel) else . end
      | .defaultProjectTrust = "never"
      | .enableInstallTelemetry = false'
  '';
}
