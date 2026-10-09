# The Blender, Godot and radare2 MCP servers, for Claude Code and opencode
# on harmonia (home/gamedev.nix), next to the editors. Each is pinned to a
# release so a new upstream commit doesn't run unreviewed.
#
# uv runs them with nixpkgs' Python: a Python uv downloads itself can't run
# on NixOS.
{ pkgs }:
rec {
  # Talks to the Blender add-on's socket, localhost:9876 unless BLENDER_HOST
  # and BLENDER_PORT say otherwise.
  blender = pkgs.writeShellApplication {
    name = "blender-mcp";
    runtimeInputs = [ pkgs.uv ];
    text = ''
      export UV_PYTHON=${pkgs.python3}/bin/python3
      exec uvx mcp-for-blender==2.1.3 "$@"
    '';
  };

  # godot-ai: with no arguments a stdio bridge to the shared server on
  # localhost:8000 (starting one if none runs); the Godot editor plugin
  # connects to that server's WebSocket on localhost:9500.
  # Must be the same version as the Godot AI plugin in your project, or the
  # plugin won't adopt the server.
  godot = pkgs.writeShellApplication {
    name = "godot-mcp";
    runtimeInputs = [ pkgs.uv ];
    text = ''
      export UV_PYTHON=${pkgs.python3}/bin/python3
      exec uvx --from godot-ai==4.3.0 godot-ai "$@"
    '';
  };

  # The servers as Claude Code and opencode run them (home/gamedev.nix):
  # Blender's add-on on localhost:9876, and a `godot-ai attach` stdio bridge
  # to the godot-ai user service (home/gamedev.nix, same ports), which reads
  # the capability record the service writes for the editor.
  host = {
    inherit blender;
    # radare2's own MCP server (pkgs/r2mcp.nix): analyses binaries on this
    # machine with radare2; its run_* tools (raw r2 commands) stay off.
    radare2 = pkgs.callPackage ../pkgs/r2mcp.nix { };
    godot = pkgs.writeShellApplication {
      name = "godot-mcp-attach";
      text = ''
        export GODOT_AI_CAPABILITY_DIR="$HOME/.config/godot-ai/capabilities"
        exec ${godot}/bin/godot-mcp attach --port 8000 --ws-port 9500 "$@"
      '';
    };
  };
}
