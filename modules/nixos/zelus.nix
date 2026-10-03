# Zelus, a microVM (microvm.nix) for development with Claude Code and
# opencode: bash, neovim, tmux, ranger and the usual dev tools, with the
# host's configs in cyan, and both agents wired to Blender and Godot over MCP.
# The guest itself is zelus/default.nix; this is the host side.
#
#   sudo systemctl start microvm@zelus    (it doesn't start at boot)
#   ssh zelus                              user c, no password
#   ~/zelus-share                          is ~/share on Zelus, read-write
#   ~/Projects                             is ~/Projects on Zelus, read-write
#
# Zelus sits on its own tap interface (vm-zelus) with a /32 route each way,
# and the host NATs its traffic to the internet. Nothing else on your LAN can
# reach it. Its status service writes utilization numbers to
# /var/lib/zelus/status for the bar (home/eww/microvm.py).
#
# LM Studio (on the host, modules/nixos/lmstudio.nix) is reachable from Zelus
# at 10.20.1.1:1234, for opencode's local model: a socket on the tap's
# address passes connections on to LM Studio's localhost:1234.
#
# Blender and Godot run on the host (Flatpak, modules/nixos/studio.nix) and
# their MCP servers run on Zelus, started by Claude Code. `ssh zelus` carries
# the two connections between them, each bound to localhost on both ends, so
# no port is opened to the network:
#   - Blender: the add-on listens on the host's localhost:9876; Zelus's
#     localhost:9876 forwards to it (RemoteForward).
#   - Godot: the MCP server listens on Zelus's localhost:9500 and the editor
#     plugin connects to the host's localhost:9500, which forwards to it
#     (LocalForward).
# The forwards live as long as the first `ssh zelus`; later ones share its
# connection (ControlMaster) for 10 minutes after it closes.
{
  pkgs,
  inputs,
  palette,
  keys,
  username,
  ...
}:
let
  zelus = {
    tap = "vm-zelus";
    mac = "02:00:00:5a:4c:01";
    hostAddress = "10.20.1.1";
    address = "10.20.1.2";
    shareDir = "/home/${username}/zelus-share";
    projectsDir = "/home/${username}/Projects";
    statusDir = "/var/lib/zelus/status";
    lmstudioPort = 1234;
    palette = import ../../zelus/palette.nix palette;
    inherit keys;
  };
in
{
  microvm.vms.zelus = {
    autostart = false;
    # Zelus builds its own package set so it can allow Claude Code (unfree)
    # without allowing it on the host; it's the same nixpkgs, so the store
    # paths are shared.
    pkgs = null;
    specialArgs = { inherit inputs zelus; };
    config = ../../zelus;
  };

  systemd.tmpfiles.rules = [
    "d ${zelus.shareDir} 0755 ${username} users -"
    "d ${zelus.projectsDir} 0755 ${username} users -"
    "d /var/lib/zelus 0755 root root -"
    "d ${zelus.statusDir} 0755 root root -"
  ];

  # LM Studio for Zelus: listens on the host's end of the tap (FreeBind, so
  # it can start before Zelus brings the tap up) and hands each connection to
  # LM Studio's local server. The firewall modes below decide whether Zelus
  # may use it.
  systemd.sockets.lmstudio-zelus = {
    description = "LM Studio for Zelus";
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "${zelus.hostAddress}:${toString zelus.lmstudioPort}" ];
    socketConfig.FreeBind = true;
  };
  systemd.services.lmstudio-zelus = {
    description = "LM Studio for Zelus (proxy to localhost:${toString zelus.lmstudioPort})";
    requires = [ "lmstudio-zelus.socket" ];
    serviceConfig = {
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:${toString zelus.lmstudioPort}";
      DynamicUser = true;
      PrivateTmp = true;
    };
  };
  networking.firewall.interfaces.${zelus.tap}.allowedTCPPorts = [ zelus.lmstudioPort ];

  # Firewall modes, switched from the bar's Zelus panel or with
  # `sudo vm-firewall set zelus MODE` (modules/nixos/vm-firewall.nix).
  harmonia.vmFirewall.zelus = {
    inherit (zelus) tap;
    default = "permissive";
    modes = [
      {
        name = "permissive";
        label = "Permissive";
        short = "open";
        description = "Internet and the host's LM Studio";
        forwardPolicy = "accept";
        inputPolicy = "accept";
      }
      {
        name = "lockdown";
        label = "Lockdown";
        short = "lock";
        description = "Nothing out; only ssh from the host";
        forwardPolicy = "drop";
        inputPolicy = "drop";
      }
      {
        name = "local";
        label = "Local inference";
        short = "local";
        description = "Only the host's LM Studio; no internet";
        forwardPolicy = "drop";
        input = [ "tcp dport ${toString zelus.lmstudioPort} accept" ];
        inputPolicy = "drop";
      }
    ];
  };

  # The host's end of the tap, as for Nike (modules/nixos/nike.nix).
  systemd.network.enable = true;
  systemd.network.networks."30-zelus" = {
    matchConfig.Name = zelus.tap;
    address = [ "${zelus.hostAddress}/32" ];
    routes = [ { Destination = "${zelus.address}/32"; } ];
    linkConfig.RequiredForOnline = "no";
  };
  networking.networkmanager.unmanaged = [ "interface-name:${zelus.tap}" ];

  networking.nat = {
    enable = true;
    internalIPs = [ "${zelus.address}/32" ];
  };

  programs.ssh.extraConfig = ''
    Host zelus
      HostName ${zelus.address}
      User c
      RemoteForward 127.0.0.1:9876 127.0.0.1:9876
      LocalForward 127.0.0.1:9500 127.0.0.1:9500
      ControlMaster auto
      ControlPath /run/user/%i/ssh-zelus-%C
      ControlPersist 10m
  '';
}
