# Rootless Podman + Buildah for containers, and plain QEMU for one-off VMs.
# The managed VM is the Nike microVM (modules/nixos/nike.nix); there is no
# libvirt or virt-manager.
{ pkgs, username, ... }:
{
  # Rootless Podman, no Docker daemon.
  virtualisation.podman = {
    enable = true;
    defaultNetwork.settings.dns_enabled = true; # containers resolve each other by name (compose)
  };
  environment.systemPackages = with pkgs; [
    podman-compose
    buildah
    # qemu-system-x86_64, qemu-img etc. for running an image by hand.
    qemu_kvm
  ];

  # /dev/kvm without root, so `qemu-system-x86_64 -enable-kvm` works as you.
  users.users.${username}.extraGroups = [ "kvm" ];
}
