# What every headless server shares on top of hosts/core.nix: SSH with keys
# only, systemd-networkd with DHCP, a firewall that lets in SSH and nothing
# else, and the same bash, tmux, ranger, neovim and Rust tools as the
# desktop. No Sway, no Flatpak. Servers are installed over SSH with
# nixos-anywhere and laid out by disko (docs/deploy.md); each host's
# disk.nix says how its disk is partitioned.
{
  config,
  lib,
  pkgs,
  inputs,
  username,
  palette,
  keys,
  ...
}:
let
  authorizedKeys = import ./server-keys.nix;
in
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    ./core.nix
  ];

  # Without a key in hosts/server-keys.nix only the console gets in (as your
  # user, password changeme), and on DigitalOcean root with the droplet's
  # own keys.
  warnings = lib.optional (authorizedKeys == [ ]) (
    "hosts/server-keys.nix has no SSH keys: add yours before deploying "
    + "${config.networking.hostName} (docs/deploy.md)."
  );

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      # root keeps key login so `nixos-rebuild --target-host root@…` and
      # nixos-anywhere work; it can never log in with a password.
      PermitRootLogin = "prohibit-password";
    };
  };
  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;
  users.users.${username}.openssh.authorizedKeys.keys = authorizedKeys;

  networking.useNetworkd = true;
  networking.useDHCP = true;
  networking.firewall.enable = true; # openssh opens port 22 itself

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit palette keys; };
    users.${username} = {
      imports = [
        ../home/bash.nix
        ../home/tmux.nix
        ../home/ranger.nix
        ../home/neovim.nix
        ../home/rust-tools.nix
      ];
      programs.git.enable = true; # the prompt shows the git branch
      programs.bash.shellAliases.rebuild = "sudo nixos-rebuild switch --flake ~/harmonia";
      home.stateVersion = "26.05";
    };
  };
}
