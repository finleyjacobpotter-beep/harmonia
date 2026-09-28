# System side of the local secrets tooling (the user side is home/secrets.nix).
# ykman and gpg's scdaemon both talk to the YubiKey through pcscd.
{ pkgs, ... }:
{
  services.pcscd.enable = true;

  # udev rules so the logged-in user can reach YubiKeys without root.
  services.udev.packages = [ pkgs.yubikey-personalization ];
}
