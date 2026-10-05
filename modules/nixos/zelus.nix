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
# Zelus sits on its own tap interface (vm-zelus); the network, folders and
# `ssh zelus` come from modules/nixos/microvms.nix. Its status service writes
# utilization numbers to /var/lib/zelus/status for the bar
# (home/eww/microvm.py).
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
  config,
  username,
  ...
}:
let
  inherit (config.harmonia.microvms.zelus) vm;
in
{
  harmonia.microvms.zelus = {
    index = 1;
    user = "c";
    guest = ../../zelus;
    key = "z";
    # Cyan instead of the host's pink, and pink as the second colour, which
    # keeps neovim's normal and insert modes (primary and secondary) apart.
    colors = {
      primary = "cyan";
      secondary = "pink";
      selection = "#1f4b5e";
      ansi = "cyan";
    };
    panel.footer = "ssh zelus (c, no password) · claude, opencode · ~/zelus-share is ~/share, ~/Projects is shared";
    extra = {
      projectsDir = "/home/${username}/Projects";
      lmstudioPort = 1234;
    };
    # Zelus builds its own package set so it can allow Claude Code (unfree)
    # without allowing it on the host; it's the same nixpkgs, so the store
    # paths are shared.
    vmArgs.pkgs = null;
    sshOptions = [
      "RemoteForward 127.0.0.1:9876 127.0.0.1:9876"
      "LocalForward 127.0.0.1:9500 127.0.0.1:9500"
      "ControlMaster auto"
      "ControlPath /run/user/%i/ssh-zelus-%C"
      "ControlPersist 10m"
    ];
    # Besides Lockdown and Permissive (modules/nixos/microvms.nix).
    firewall.modes = [
      {
        name = "local";
        label = "Local inference";
        short = "local";
        description = "Only the host's LM Studio; no internet";
        forwardPolicy = "drop";
        input = [ "tcp dport ${toString vm.lmstudioPort} accept" ];
        inputPolicy = "drop";
      }
    ];
  };

  systemd.tmpfiles.rules = [ "d ${vm.projectsDir} 0755 ${username} users -" ];

  # LM Studio for Zelus: listens on the host's end of the tap (FreeBind, so
  # it can start before Zelus brings the tap up) and hands each connection to
  # LM Studio's local server. The firewall modes decide whether Zelus may use
  # it.
  systemd.sockets.lmstudio-zelus = {
    description = "LM Studio for Zelus";
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "${vm.hostAddress}:${toString vm.lmstudioPort}" ];
    socketConfig.FreeBind = true;
  };
  systemd.services.lmstudio-zelus = {
    description = "LM Studio for Zelus (proxy to localhost:${toString vm.lmstudioPort})";
    requires = [ "lmstudio-zelus.socket" ];
    serviceConfig = {
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:${toString vm.lmstudioPort}";
      DynamicUser = true;
      PrivateTmp = true;
    };
  };
  networking.firewall.interfaces.${vm.tap}.allowedTCPPorts = [ vm.lmstudioPort ];
}
