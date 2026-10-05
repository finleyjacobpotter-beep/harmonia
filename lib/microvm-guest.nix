# What every microVM guest shares (microvm.nix on QEMU/KVM): the tap network
# with a /32 route to the host, the read-only host store, the ~/share and
# status shares, /var and /home volumes, one user (uid 1000, like the host's
# first user, so shared files belong to you on both sides), openssh, the
# status service the host's bar reads, and the host's bash, tmux, ranger,
# neovim and Rust tools in the VM's own colours.
#
#   imports = [
#     (import ../lib/microvm-guest.nix {
#       name = "nike";
#       user = "k";
#       vm = nike; # from the host side (modules/nixos/nike.nix)
#       varSize = 24576;
#       homeSize = 16384;
#     })
#   ];
#
# `vm` carries tap, mac, address, hostAddress, nameservers, shareDir,
# statusDir, palette and keys. The guest adds its own shares, packages, user
# settings and home-manager modules on top.
{
  name,
  user,
  vm,
  varSize,
  homeSize,
}:
{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  pyScript = import ./python-script.nix { inherit pkgs lib; };

  # Writes utilization (and, on Nike, VPN) status for the host's bar.
  status = pyScript "${name}-status" {
    runtimeInputs = [ pkgs.iproute2 ];
  } ../nike/status.py;
  statusMount = "/run/${name}-status";
  Name = lib.toUpper (lib.substring 0 1 name) + lib.substring 1 (-1) name;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    (import ./root-cas.nix name)
    ../modules/nixos/editorconfig.nix
  ];

  microvm = {
    hypervisor = "qemu";
    vcpu = 4;
    mem = 6144; # not exactly 2 or 4 GiB: QEMU hangs (microvm.nix#171)

    interfaces = [
      {
        type = "tap";
        id = vm.tap;
        inherit (vm) mac;
      }
    ];

    shares = [
      # The host's /nix/store, read-only: nothing is copied into an image.
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
      # Shared files: ~/<name>-share on the host is ~/share here, read-write.
      {
        proto = "virtiofs";
        tag = "share";
        source = vm.shareDir;
        mountPoint = "/home/${user}/share";
      }
      # Where status.py writes for the host's bar.
      {
        proto = "virtiofs";
        tag = "status";
        source = vm.statusDir;
        mountPoint = statusMount;
      }
    ];

    # The root filesystem is a tmpfs; these survive a reboot. The images
    # live in /var/lib/microvms/<name> on the host and are created on first
    # start.
    volumes = [
      {
        image = "var.img";
        mountPoint = "/var";
        size = varSize;
      }
      {
        image = "home.img";
        mountPoint = "/home";
        size = homeSize;
      }
    ];
  };
  # Mounted before users are set up, so the home directory lands on the volume.
  fileSystems."/home".neededForBoot = true;

  networking.useNetworkd = true;
  networking.useDHCP = false;
  # A host route to the host and a default route through it; the host NATs
  # the VM's traffic out to the internet.
  systemd.network.networks."10-host" = {
    matchConfig.MACAddress = vm.mac;
    address = [ "${vm.address}/32" ];
    routes = [
      {
        Destination = "${vm.hostAddress}/32";
        GatewayOnLink = true;
      }
      {
        Destination = "0.0.0.0/0";
        Gateway = vm.hostAddress;
        GatewayOnLink = true;
      }
    ];
  };
  # Nike's VPN firewall modes let DNS out only to these.
  networking.nameservers = vm.nameservers;

  users.mutableUsers = false;
  users.users.${user} = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
    # On the /var volume, so the host key stays the same across reboots.
    hostKeys = [
      {
        path = "/var/lib/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  environment.systemPackages = [ pkgs.openssh ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit (vm) palette keys;
    };
    users.${user} = {
      imports = [
        ../home/bash.nix
        ../home/tmux.nix
        ../home/ranger.nix
        ../home/neovim.nix
        ../home/rust-tools.nix
      ];
      programs.git.enable = true; # the prompt shows the git branch
      home.stateVersion = "26.05";
    };
  };

  systemd.services."${name}-status" = {
    description = "Write ${Name}'s status for the host's bar";
    wantedBy = [ "multi-user.target" ];
    unitConfig.RequiresMountsFor = statusMount;
    serviceConfig = {
      ExecStart = "${status}/bin/${name}-status ${statusMount}/status.json";
      Restart = "always";
      RestartSec = 5;
    };
  };

  system.stateVersion = "26.05";
}
