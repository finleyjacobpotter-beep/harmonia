# harmonia, the desktop.
{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    # The AMD GPU's fan curve (LACT). cadmus has its own (thinkpad.nix).
    ../../modules/nixos/fans.nix
  ];
}
