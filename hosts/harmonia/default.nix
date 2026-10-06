# harmonia, the desktop.
{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    # The AMD GPU's fan curve (LACT). cadmus has its own (thinkpad.nix).
    ../../modules/nixos/fans.nix
  ];

  # Python, uv and uvx. uv uses nixpkgs' Python: a Python uv downloads itself
  # can't run on NixOS.
  environment.systemPackages = [
    pkgs.python3
    pkgs.uv
  ];
  environment.variables = {
    UV_PYTHON = "${pkgs.python3}/bin/python3";
    UV_PYTHON_DOWNLOADS = "never";
  };
}
