# Dionysus: harmonia's Sway desktop with the coding/creative toolset built in,
# and no microVMs. Where harmonia keeps Blender, Godot and the coding agents
# in a microVM (Zelus) or in flatpak sandboxes, Dionysus runs them natively
# (home/dionysus/dev.nix) so the whole thing builds on aarch64 and x86_64
# alike. The architecture-specific and flatpak-only modules harmonia uses
# (Steam, gaming, LM Studio, the studio flatpaks, the Nike microVM) are left
# out for the same reason.
{
  pkgs,
  lib,
  hostname,
  username,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./flatpak.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/editorconfig.nix
    ../../modules/nixos/fonts.nix
    ../../modules/nixos/element.nix
    ../../modules/nixos/secrets.nix
    ../../modules/nixos/vpn.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # harmonia's desktop enables 32-bit graphics for 32-bit Steam/Wine; there is
  # no i686 Mesa on aarch64 and Dionysus ships no 32-bit games, so turn it off.
  hardware.graphics.enable32Bit = lib.mkForce false;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
    ];
    shell = pkgs.bashInteractive;
    # Set a password with `passwd` after first boot, or use hashedPasswordFile.
    initialPassword = "changeme";
  };

  # The only non-free packages allowed:
  #   tulasi-icon-theme — CC BY-NC-SA 4.0 (non-commercial)
  #   claude-code        — Anthropic's CLI (home/dionysus/dev.nix)
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "tulasi-icon-theme"
      "claude-code"
    ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "@wheel"
    ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    jq
    ripgrep
    fd
    unzip
    htop
  ];

  system.stateVersion = "26.05";
}
