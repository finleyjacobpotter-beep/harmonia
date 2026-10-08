# PLACEHOLDER — nixos-anywhere replaces this during the install:
#
#   nixos-anywhere --generate-hardware-config nixos-generate-config \
#     ./hosts/atlas/hardware-configuration.nix --flake .#atlas root@<ip>
#
# Commit the generated file afterwards. The values below only exist so the
# flake evaluates. File systems come from disk.nix (disko), so the generated
# file has none either.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];
}
