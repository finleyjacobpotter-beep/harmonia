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
  environment.systemPackages = [
    pkgs.python3
    # Forgejo CLI (`fj`): repos, issues and PRs on Forgejo instances such as
    # Codeberg. `fj auth login` signs in to one.
    pkgs.forgejo-cli
  ];
  environment.variables = {
    UV_PYTHON = "${pkgs.python3}/bin/python3";
    UV_PYTHON_DOWNLOADS = "never";
  };

  # AI agents and game dev, on the desktop only: pi on the local model
  # (llama-server.nix above; home/ai.nix) and Claude Code, with Blender,
  # Godot and radare2 over MCP (home/gamedev.nix; docs/pi.md, docs/gamedev.md).
  home-manager.users.${username}.imports = [
    ../../home/ai.nix
    ../../home/gamedev.nix
  ];
  harmonia.allowedUnfree = [ "claude-code" ];
}
