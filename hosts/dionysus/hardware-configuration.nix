# PLACEHOLDER — replace this with the file generated on your machine:
#
#   sudo nixos-generate-config --show-hardware-config > hosts/dionysus/hardware-configuration.nix
#
# The values below are deliberately architecture-neutral (no x86-only CPU
# microcode or kvm_intel/kvm_amd modules), so the flake evaluates and the
# config builds and boots as a plain UEFI QEMU/KVM guest on both aarch64-linux
# and x86_64-linux. `nixos-rebuild build-vm` overrides the filesystems with a
# throwaway qcow2, so you can try Dionysus as a VM without touching this file.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
    "xhci_pci"
    "usbhid"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

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
}
