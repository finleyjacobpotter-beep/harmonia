# Proteus: a DigitalOcean droplet, installed over SSH with nixos-anywhere
# (docs/deploy.md). Droplets boot with legacy BIOS from /dev/vda, so this
# uses GRUB rather than systemd-boot; disk.nix lays the disk out.
#
# nixpkgs' DigitalOcean module does the droplet plumbing: the virtio
# drivers, the serial console, the metadata service, the droplet's SSH keys
# for root (in addition to hosts/server-keys.nix) and DigitalOcean's
# monitoring agent.
{ lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/digital-ocean-config.nix")
    ./disk.nix
    ../server.nix
  ];

  # The module would otherwise rebuild from the droplet's user data on every
  # boot; this config comes from the flake instead.
  virtualisation.digitalOcean.rebuildFromUserData = false;

  # GRUB on the disk's MBR for BIOS, and on the ESP too so the disk would
  # also boot under UEFI.
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    # disko (from disk.nix's BIOS boot partition) and the DigitalOcean module
    # both name /dev/vda; install GRUB there once.
    devices = lib.mkForce [ "/dev/vda" ];
  };
}
