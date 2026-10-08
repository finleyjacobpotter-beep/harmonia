# Atlas: a Minisforum MS-01 SE mini PC run as a headless home server,
# installed over SSH with nixos-anywhere (docs/deploy.md). UEFI with
# systemd-boot, like the desktops; disk.nix lays out the NVMe drive.
#
# hardware-configuration.nix is a placeholder; nixos-anywhere's
# --generate-hardware-config writes the real one during the install.
{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ./hardware-configuration.nix
    ./disk.nix
    ../server.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Firmware for the network cards.
  hardware.enableRedistributableFirmware = true;

  # BIOS updates, where Minisforum publishes them to LVFS.
  services.fwupd.enable = true;
}
