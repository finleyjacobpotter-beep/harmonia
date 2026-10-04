# harmonia, the desktop.
{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    # The AMD GPU's fan curve (LACT); laptops leave fans to the firmware.
    ../../modules/nixos/fans.nix
  ];
}
