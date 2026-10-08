# What every machine shares, desktop or server: the user, locale, nix
# settings, the unfree allow-list, the base CLI tools and the system-wide
# EditorConfig, git LFS, sudo and podman settings. hosts/base.nix adds the
# desktop on top; hosts/server.nix adds what a headless server needs.
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
    ../modules/nixos/editorconfig.nix
    ../modules/nixos/podman.nix
    ../modules/nixos/git-lfs.nix
    ../modules/nixos/sudo.nix
  ];

  # The only non-free packages allowed, by name. A host adds its own here
  # (Dionysus adds claude-code); every list is merged into one predicate.
  options.harmonia.allowedUnfree = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };

  config = {
    nixpkgs.config.allowUnfreePredicate =
      pkg: builtins.elem (lib.getName pkg) config.harmonia.allowedUnfree;

    networking.hostName = hostname;

    time.timeZone = "UTC";
    i18n.defaultLocale = "en_US.UTF-8";
    console.keyMap = "us";

    users.users.${username} = {
      isNormalUser = true;
      description = username;
      extraGroups = [ "wheel" ];
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
