# The Blender and Godot MCP servers for Claude Code and opencode on Zelus
# (zelus/default.nix, home/opencode.nix). Each is pinned to a release so a
# new upstream commit doesn't run unreviewed.
#
# uv runs them with nixpkgs' Python: a Python uv downloads itself can't run
# on NixOS.
{ pkgs }:
{
  # Talks to the Blender add-on's socket on localhost:9876.
  blender = pkgs.writeShellApplication {
    name = "blender-mcp";
    runtimeInputs = [ pkgs.uv ];
    text = ''
      export UV_PYTHON=${pkgs.python3}/bin/python3
      exec uvx mcp-for-blender==2.1.3 "$@"
    '';
  };

  # Listens on localhost:9500; the Godot editor plugin connects to it.
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
}
