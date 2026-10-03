# Nike, the microVM guest (microvm.nix on QEMU/KVM). The host side (its
# network, shared folders, `ssh nike`) is modules/nixos/nike.nix, which passes
# `nike` below: the addresses, the tap interface and the host folders.
#
# Login: k / k (ssh nike from the host). The shell, neovim, tmux and ranger
# are the host's own home-manager configs in orange instead of pink
# (nike/palette.nix).
{
  lib,
  pkgs,
  inputs,
  nike,
  ...
}:
let
  pyScript = import ../lib/python-script.nix { inherit pkgs lib; };

  # Writes the VPN and utilization status the host's bar shows.
  status = pyScript "nike-status" {
    runtimeInputs = [ pkgs.iproute2 ];
  } ./status.py;
in
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  microvm = {
    hypervisor = "qemu";
    vcpu = 2;
    mem = 3072; # not exactly 2048: QEMU hangs (microvm.nix#171)

    interfaces = [
      {
        type = "tap";
        id = nike.tap;
        inherit (nike) mac;
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
      # Shared files: ~/nike-share on the host is ~/share here, read-write.
      {
        proto = "virtiofs";
        tag = "share";
        source = nike.shareDir;
        mountPoint = "/home/k/share";
      }
      # Where status.py writes for the host's bar.
      {
        proto = "virtiofs";
        tag = "status";
        source = nike.statusDir;
        mountPoint = "/run/nike-status";
      }
    ];

    # The root filesystem is a tmpfs; these survive a reboot. The images
    # live in /var/lib/microvms/nike on the host and are created on first
    # start.
    volumes = [
      {
        image = "var.img";
        mountPoint = "/var";
        size = 4096;
      }
      {
        image = "home.img";
        mountPoint = "/home";
        size = 16384;
      }
    ];
  };
  # Mounted before users are set up, so ~k lands on the volume.
  fileSystems."/home".neededForBoot = true;

  networking.useNetworkd = true;
  networking.useDHCP = false;
  # A host route to the host and a default route through it; the host NATs
  # Nike's traffic out to the internet.
  systemd.network.networks."10-host" = {
    matchConfig.MACAddress = nike.mac;
    address = [ "${nike.address}/32" ];
    routes = [
      {
        Destination = "${nike.hostAddress}/32";
        GatewayOnLink = true;
      }
      {
        Destination = "0.0.0.0/0";
        Gateway = nike.hostAddress;
        GatewayOnLink = true;
      }
    ];
  };
  # The VPN modes' firewall lets DNS out only to these.
  networking.nameservers = nike.nameservers;

  users.mutableUsers = false;
  users.users.k = {
    isNormalUser = true;
    # The host's first user is uid 1000 too, so files in the shared folder
    # belong to you on both sides.
    uid = 1000;
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
    # The password is "k" (`openssl passwd -6 k` to change it).
    hashedPassword = "$6$nikeharmonia$Io38a7YWoxdELeyAm2L52p.Fj8iawmoMe6fmu5uMaoDRhZpEY1XFFPa9kVOVbtJb6.56ipdchgqf8En/4WK6Y0";
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

  # bash, neovim, tmux and ranger come from home-manager below.
  environment.systemPackages = with pkgs; [
    openssh
    python3
    openvpn
    nmap
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit (nike) palette keys;
    };
    users.k = {
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

  systemd.services.nike-status = {
    description = "Write Nike's VPN and utilization status for the host's bar";
    wantedBy = [ "multi-user.target" ];
    unitConfig.RequiresMountsFor = "/run/nike-status";
    serviceConfig = {
      ExecStart = "${status}/bin/nike-status /run/nike-status/status.json";
      Restart = "always";
      RestartSec = 5;
    };
  };

  system.stateVersion = "26.05";
}
