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

  # Game dev, on the desktop only: opencode on the local model in LM Studio,
  # with Claude (and Claude Code) for plans and the final check, and Blender
  # and Godot over MCP (docs/gamedev.md).
  home-manager.users.${username}.imports = [ ../../home/gamedev.nix ];
  harmonia.allowedUnfree = [ "claude-code" ];
}
