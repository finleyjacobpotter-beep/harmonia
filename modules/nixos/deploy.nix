# Installing NixOS onto other machines over SSH (docs/deploy.md):
# nixos-anywhere boots the target into a NixOS installer with kexec,
# partitions it with disko and installs a flake config.
#
#   nixos-anywhere --flake .#proteus root@<droplet ip>
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    nixos-anywhere
    disko
  ];
}
