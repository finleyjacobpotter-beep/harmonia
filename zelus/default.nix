# Zelus, the microVM guest (microvm.nix on QEMU/KVM). The host side (its
# network, shared folders, `ssh zelus` and the Blender/Godot forwards) is
# modules/nixos/zelus.nix, which passes `zelus` below: the addresses, the tap
# interface and the host folders.
#
# Login: c, no password (ssh zelus from the host). The shell, neovim, tmux
# and ranger are the host's own home-manager configs in cyan instead of pink
# (zelus/palette.nix). Claude Code and opencode (home/opencode.nix) both have
# the Blender and Godot MCP servers (home/mcp-servers.nix).
{
  lib,
  pkgs,
  inputs,
  zelus,
  ...
}:
let
  pyScript = import ../lib/python-script.nix { inherit pkgs lib; };

  mcp = import ../home/mcp-servers.nix { inherit pkgs; };

  # Nike's status writer: utilization for the host's bar (its VPN fields
  # just read "no VPN" here).
  status = pyScript "zelus-status" {
    runtimeInputs = [ pkgs.iproute2 ];
  } ../nike/status.py;
in
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  # The only non-free package, and only on Zelus.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "claude-code" ];

  microvm = {
    hypervisor = "qemu";
    vcpu = 4;
    mem = 6144; # not exactly 2048: QEMU hangs (microvm.nix#171)

    interfaces = [
      {
        type = "tap";
        id = zelus.tap;
        inherit (zelus) mac;
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
      # Shared files: ~/zelus-share on the host is ~/share here, read-write.
      {
        proto = "virtiofs";
        tag = "share";
        source = zelus.shareDir;
        mountPoint = "/home/c/share";
      }
      # The host's ~/Projects (what Blender and Godot can open), read-write,
      # so Claude Code can work on the same files the editors have open.
      {
        proto = "virtiofs";
        tag = "projects";
        source = zelus.projectsDir;
        mountPoint = "/home/c/Projects";
      }
      # Where status.py writes for the host's bar.
      {
        proto = "virtiofs";
        tag = "status";
        source = zelus.statusDir;
        mountPoint = "/run/zelus-status";
      }
    ];

    # The root filesystem is a tmpfs; these survive a reboot. The images
    # live in /var/lib/microvms/zelus on the host and are created on first
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
        size = 32768;
      }
    ];
  };
  # Mounted before users are set up, so ~c lands on the volume.
  fileSystems."/home".neededForBoot = true;

  networking.useNetworkd = true;
  networking.useDHCP = false;
  # A host route to the host and a default route through it; the host NATs
  # Zelus's traffic out to the internet.
  systemd.network.networks."10-host" = {
    matchConfig.MACAddress = zelus.mac;
    address = [ "${zelus.address}/32" ];
    routes = [
      {
        Destination = "${zelus.hostAddress}/32";
        GatewayOnLink = true;
      }
      {
        Destination = "0.0.0.0/0";
        Gateway = zelus.hostAddress;
        GatewayOnLink = true;
      }
    ];
  };
  networking.nameservers = [
    "9.9.9.9"
    "149.112.112.112"
  ];

  # No password anywhere: Zelus is reachable from the host only, and ssh,
  # the console and sudo let c straight in.
  users.mutableUsers = false;
  users.users.c = {
    isNormalUser = true;
    # The host's first user is uid 1000 too, so files in the shared folders
    # belong to you on both sides.
    uid = 1000;
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
    hashedPassword = "";
  };
  security.sudo.wheelNeedsPassword = false;
  security.pam.services.sshd.allowNullPassword = true;
  services.getty.autologinUser = "c";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitEmptyPasswords = "yes";
    };
    # On the /var volume, so the host key stays the same across reboots.
    hostKeys = [
      {
        path = "/var/lib/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  # bash, neovim, tmux, ranger, Claude Code and opencode come from
  # home-manager below.
  environment.systemPackages = with pkgs; [
    openssh
    git
    jq
    curl
    wget
    unzip
    btop
    gnumake
    gcc
    python3
    uv
    nodejs
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit (zelus) palette keys;
      inherit zelus;
    };
    users.c = {
      imports = [
        ../home/bash.nix
        ../home/tmux.nix
        ../home/ranger.nix
        ../home/neovim.nix
        ../home/opencode.nix
        ./rust-tools.nix
      ];
      programs.git.enable = true; # the prompt shows the git branch

      # `claude`, then /login the first time. The MCP servers connect to
      # Blender and Godot on the host through `ssh zelus` (see
      # modules/nixos/zelus.nix), so start Claude Code from an ssh session.
      programs.claude-code = {
        enable = true;
        mcpServers = {
          blender.command = "${mcp.blender}/bin/blender-mcp";
          godot.command = "${mcp.godot}/bin/godot-mcp";
        };
      };

      home.stateVersion = "26.05";
    };
  };

  systemd.services.zelus-status = {
    description = "Write Zelus's utilization for the host's bar";
    wantedBy = [ "multi-user.target" ];
    unitConfig.RequiresMountsFor = "/run/zelus-status";
    serviceConfig = {
      ExecStart = "${status}/bin/zelus-status /run/zelus-status/status.json";
      Restart = "always";
      RestartSec = 5;
    };
  };

  system.stateVersion = "26.05";
}
