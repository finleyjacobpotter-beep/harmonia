# The Blender and Godot MCP servers. Each is pinned to a release so a new
# upstream commit doesn't run unreviewed.
#
# Blender and Godot run on the host, the agents on Zelus
# (modules/nixos/zelus.nix):
#   - blender-mcp runs on Zelus and connects to the add-on through a socket
#     on the host's end of the tap.
#   - godot-ai's server runs on the host, next to the editor that reads its
#     private capability record; on Zelus, godot-mcp is a pipe to a
#     `godot-ai attach` bridge the host starts per connection.
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
  godot = pkgs.writeShellApplication {
    name = "godot-mcp";
    runtimeInputs = [
      pkgs.uv
      pkgs.git
    ];
    text = ''
      export UV_PYTHON=${pkgs.python3}/bin/python3
      exec uvx --from git+https://github.com/bebabinlarsson-blip/Godot-MCP.git@v5.0.9 godot-ai "$@"
    '';
  };

  # The two as Claude Code and opencode on Zelus run them; `vm` is Zelus's
  # `vm` argument (ports from modules/nixos/zelus.nix).
  zelus = vm: {
    blender = pkgs.writeShellApplication {
      name = "blender-mcp";
      text = ''
        export BLENDER_HOST=${vm.hostAddress} BLENDER_PORT=${toString vm.blenderPort}
        exec ${blender}/bin/blender-mcp "$@"
      '';
    };
    godot = pkgs.writeShellApplication {
      name = "godot-mcp";
      runtimeInputs = [ pkgs.socat ];
      text = ''
        exec socat - TCP:${vm.hostAddress}:${toString vm.godotPort}
      '';
    };
  };
}
