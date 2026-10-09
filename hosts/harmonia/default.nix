# harmonia, the desktop.
{ pkgs, username, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    # The AMD GPU's fan curve (LACT). cadmus has its own (thinkpad.nix).
    ../../modules/nixos/fans.nix
    # Ornith 1.5 9B on llama.cpp's server, in podman, on the GPU.
    ../../modules/nixos/llama-server.nix
  ];

  # Python, for uv and uvx (home/default.nix), which use it: a Python uv
  # downloads itself can't run on NixOS.
  environment.systemPackages = [ pkgs.python3 ];
  environment.variables = {
    UV_PYTHON = "${pkgs.python3}/bin/python3";
    UV_PYTHON_DOWNLOADS = "never";
  };

  # Game dev, on the desktop only: opencode with every agent on the local
  # model (llama-server.nix above), Claude Code, and Blender, Godot and
  # radare2 over MCP (docs/gamedev.md).
  home-manager.users.${username}.imports = [ ../../home/gamedev.nix ];
  harmonia.allowedUnfree = [ "claude-code" ];
}
