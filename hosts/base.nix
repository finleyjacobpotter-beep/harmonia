# What every host shares: boot, networking, locale, the user, nix settings
# and the base CLI tools, plus the Sway desktop, fonts, Element, secrets and
# VPNs. hosts/common.nix adds harmonia's and cadmus's apps and microVMs on
# top; Dionysus imports this directly.
{
  config,
  pkgs,
  lib,
  hostname,
  username,
  ...
}:
{
  imports = [
    ../modules/nixos/desktop.nix
    ../modules/nixos/editorconfig.nix
    ../modules/nixos/fonts.nix
    ../modules/nixos/flatpak.nix
    ../modules/nixos/element.nix
    ../modules/nixos/secrets.nix
    ../modules/nixos/vpn.nix
  ];

  # The only non-free packages allowed, by name. A host adds its own here
  # (Dionysus adds claude-code); every list is merged into one predicate.
  options.harmonia.allowedUnfree = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };

  config = {
    # tulasi-icon-theme is CC BY-NC-SA 4.0 (non-commercial).
    harmonia.allowedUnfree = [ "tulasi-icon-theme" ];
    nixpkgs.config.allowUnfreePredicate =
      pkg: builtins.elem (lib.getName pkg) config.harmonia.allowedUnfree;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.kernelPackages = pkgs.linuxPackages_latest;

    networking.hostName = hostname;
    networking.networkmanager.enable = true;

    time.timeZone = "UTC";
    i18n.defaultLocale = "en_US.UTF-8";
    console.keyMap = "us";

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
  };
}
