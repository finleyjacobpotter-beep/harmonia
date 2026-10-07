# harmonia, the desktop.
{ pkgs, username, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    # The AMD GPU's fan curve (LACT). cadmus has its own (thinkpad.nix).
    ../../modules/nixos/fans.nix
  ];

  # Python, for uv and uvx (home/default.nix), which use it: a Python uv
  # downloads itself can't run on NixOS.
  environment.systemPackages = [ pkgs.python3 ];
  environment.variables = {
    UV_PYTHON = "${pkgs.python3}/bin/python3";
    UV_PYTHON_DOWNLOADS = "never";
  };

  # opencode for game dev, on the desktop only: Claude plus the local model
  # in LM Studio, with Blender and Godot over MCP (docs/gamedev.md).
  home-manager.users.${username}.imports = [ ../../home/gamedev.nix ];
}
