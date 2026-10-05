# Dionysus: harmonia's Sway desktop with the coding/creative toolset built in,
# and no microVMs. Where harmonia keeps Blender, Godot and the coding agents
# in a microVM (Zelus) or in flatpak sandboxes, Dionysus runs them natively
# (home/dionysus/dev.nix) so the whole thing builds on aarch64 and x86_64
# alike. The architecture-specific and flatpak-only modules harmonia uses
# (Steam, gaming, LM Studio, the studio flatpaks, the Nike microVM) are left
# out for the same reason.
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
}
