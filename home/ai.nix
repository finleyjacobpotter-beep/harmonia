# pi, the coding agent, on harmonia itself (not Cadmus, which doesn't
# import this; hosts/harmonia/default.nix does): on the local model
# (modules/nixos/llama-server.nix), with the Blender, Godot and radare2 MCP
# servers (./mcp-servers.nix) and Claude Code's skills (./gamedev.nix), and
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
      mcp.mcpServers = mcpServers.clientConfig;
    }
  );
in
{
  home.packages = [ pi ];

  # Instructions from .agents/ only, nothing from a project's .pi/.
  home.file.".pi/agent/extensions/agents-dir.ts".source = ./pi/agents-dir.ts;

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
