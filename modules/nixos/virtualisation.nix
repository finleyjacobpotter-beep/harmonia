# Plain QEMU for one-off VMs. The managed VMs are the Nike and Zelus microVMs
# (modules/nixos/nike.nix, zelus.nix); there is no libvirt or virt-manager.
# Podman comes from modules/nixos/podman.nix via hosts/base.nix.
{ pkgs, username, ... }:
{
  environment.systemPackages = with pkgs; [
    # qemu-system-x86_64, qemu-img etc. for running an image by hand.
    qemu_kvm
  ];

  # /dev/kvm without root, so `qemu-system-x86_64 -enable-kvm` works as you.
  users.users.${username}.extraGroups = [ "kvm" ];
}
