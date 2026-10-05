# Dionysus: harmonia's Sway desktop with the coding agents built in, and no
# microVMs. Where harmonia keeps the coding agents in a microVM (Zelus),
# Dionysus runs them natively (home/dionysus/dev.nix) so the whole thing
# builds on aarch64 and x86_64 alike. Steam, Blender and Godot are not on
# Dionysus, and the other architecture-specific and flatpak-only modules
# harmonia uses (gaming, LM Studio, the Nike microVM) are left out too; Zen
# is installed on x86_64 only (modules/nixos/flatpak.nix).
{ lib, ... }:
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
}
