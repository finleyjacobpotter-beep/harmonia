# Zelus, a microVM (microvm.nix) for development with Claude Code: bash,
# neovim, tmux, ranger and the usual dev tools, with the host's configs in
# cyan, and Claude Code wired to Blender and Godot over MCP. The guest itself
# is zelus/default.nix; this is the host side.
#
#   sudo systemctl start microvm@zelus    (it doesn't start at boot)
#   ssh zelus                              user c, no password
#   ~/zelus-share                          is ~/share on Zelus, read-write
#   ~/Projects                             is ~/Projects on Zelus, read-write
#
# Zelus sits on its own tap interface (vm-zelus) with a /32 route each way,
# and the host NATs its traffic to the internet. Nothing else on your LAN can
# reach it.
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
  ];

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
