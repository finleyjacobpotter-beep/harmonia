# Dionysus: harmonia's Sway desktop with the coding agents built in, and no
# microVMs. Where harmonia keeps the coding agents in a microVM (Zelus),
# Dionysus runs them natively (home/dionysus/dev.nix) so the whole thing
# builds on aarch64 and x86_64 alike. Steam, Blender and Godot are not on
# Dionysus, and the other architecture-specific and flatpak-only modules
# harmonia uses (gaming, LM Studio, the Nike microVM) are left out too.
{ lib, username, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../base.nix
  ];

  # Anthropic's CLI (home/dionysus/dev.nix).
  harmonia.allowedUnfree = [ "claude-code" ];

  # harmonia's desktop enables 32-bit graphics for 32-bit Steam/Wine; there is
  # no i686 Mesa on aarch64 and Dionysus ships no 32-bit games, so turn it off.
  hardware.graphics.enable32Bit = lib.mkForce false;

  # SPICE guest services, for running Dionysus under virt-manager/QEMU with a
  # SPICE display: the vdagent gives clipboard sharing and display resizing,
  # webdavd serves the host's shared folder (spice-webdav channel).
  services.spice-vdagentd.enable = true;
  services.spice-webdavd.enable = true;

  # VirtualBox guest additions, for running Dionysus under VirtualBox (x86_64,
  # or VirtualBox 7.1+ on Apple silicon): display resizing (VMSVGA), shared
  # clipboard, drag and drop, and vboxsf shared folders. Every guest service
  # is conditioned on the hypervisor being VirtualBox, so this and the SPICE
  # services above coexist: under QEMU these stay idle, under VirtualBox SPICE
  # has no channel and stays idle.
  virtualisation.virtualbox.guest.enable = true;
  # vboxsf shared folders are mounted group vboxsf.
  users.users.${username}.extraGroups = [ "vboxsf" ];
}
