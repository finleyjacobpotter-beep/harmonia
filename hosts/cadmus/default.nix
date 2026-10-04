# cadmus, the laptop: harmonia's setup (same desktop, apps and microVMs),
# plus Wi-Fi, lid and power handling.
{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../modules/nixos/laptop.nix
  ];
}
