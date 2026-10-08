# What every desktop host shares on top of hosts/core.nix: the boot loader,
# NetworkManager, the Sway desktop, fonts, Element, secrets and VPNs.
# hosts/common.nix adds harmonia's and cadmus's apps and microVMs on top;
# Dionysus imports this directly.
{
  pkgs,
  lib,
  username,
  ...
}:
{
  imports = [
    ./core.nix
    ../modules/nixos/desktop.nix
    ../modules/nixos/fonts.nix
    ../modules/nixos/flatpak.nix
    ../modules/nixos/element.nix
    ../modules/nixos/secrets.nix
    ../modules/nixos/vpn.nix
  ];

  # tulasi-icon-theme is CC BY-NC-SA 4.0 (non-commercial).
  harmonia.allowedUnfree = [ "tulasi-icon-theme" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.networkmanager.enable = true;

  users.users.${username}.extraGroups = [
    "networkmanager"
    "video"
    "audio"
  ];

  environment.systemPackages = [
    # `sudo harmonia-cleanup`: removes what older harmonia versions left
    # behind (scripts/cleanup-deprecated.py). Its nix-shell lines are
    # dropped; the writer adds its own interpreter line.
    (import ../lib/python-script.nix { inherit pkgs lib; } "harmonia-cleanup"
      {
        runtimeInputs = with pkgs; [
          util-linux # runuser
          iproute2
        ];
      }
      (
        lib.concatStringsSep "\n" (
          lib.drop 2 (lib.splitString "\n" (builtins.readFile ../scripts/cleanup-deprecated.py))
        )
      )
    )
  ];
}
