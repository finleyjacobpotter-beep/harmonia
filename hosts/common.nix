# Everything harmonia (desktop) and cadmus (laptop) share on top of
# hosts/base.nix: the gaming and studio apps and the microVMs.
# Each host's default.nix adds its hardware-configuration.nix and what only
# that kind of machine needs.
{ hostname, ... }:
{
  imports = [
    # Extra root CAs: certs/all plus certs/<hostname>, if present.
    (import ../lib/root-cas.nix hostname)
    ./base.nix
    ../modules/nixos/gaming.nix
    ../modules/nixos/steam.nix
    ../modules/nixos/studio.nix
    ../modules/nixos/virtualisation.nix
    ../modules/nixos/microvms.nix
    ../modules/nixos/nike.nix
  ];
}
