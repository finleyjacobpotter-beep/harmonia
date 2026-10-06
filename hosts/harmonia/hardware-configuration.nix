# PLACEHOLDER — replace this file with the one generated on your machine:
#
#   sudo nixos-generate-config --show-hardware-config > hosts/harmonia/hardware-configuration.nix
#
# The values below only exist so the flake evaluates (`nix flake check`).
{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # Your generated file won't have this line. Until it's replaced,
  # `nixos-rebuild switch`/`boot` refuse to activate (hosts/base.nix).
  harmonia.placeholderHardware = true;

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "sd_mod"
  ];
  boot.kernelModules = [
    "kvm-intel"
    "kvm-amd"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
}
