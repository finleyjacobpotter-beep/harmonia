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
# at 10.20.1.1:1234, for opencode's local model: the host redirects that to a
# socket on the tap's address (port 11234), which passes connections on to
# LM Studio's localhost:1234. The socket can't sit on 1234 itself: LM Studio's
# "serve on local network" binds 0.0.0.0:1234, which would then fail.
#
# Blender and Godot run on the host (Flatpak, modules/nixos/studio.nix);
# Claude Code and opencode on Zelus reach them through two sockets on the
# host's end of the tap (home/mcp-servers.nix), whether or not an
# `ssh zelus` is open, and in every firewall mode:
#   - Blender: blender-mcp runs on Zelus and connects to 10.20.1.1:19876,
#     which passes connections on to the add-on on the host's localhost:9876.
#   - Godot: godot-ai v5's server has to run next to the editor, which
#     authenticates to it with a private record the server writes (a server
#     on Zelus could never be adopted). So the host runs it as a user service
#     (localhost:8000, plugin WebSocket localhost:9500), with the record in
#     Godot's Flatpak config folder where the plugin looks. Each connection
#     to 10.20.1.1:19500 gets its own `godot-ai attach` stdio bridge to it,
#     and godot-mcp on Zelus is a pipe to that.
# Both sockets sit off the apps' own ports, so setting the add-on or plugin
# to listen on the local network can't collide with them.
{
  pkgs,
  config,
  username,
  ...
}:
let
  inherit (config.harmonia.microvms.zelus) vm;
  # Where the proxy below listens; Zelus's 10.20.1.1:1234 is redirected here.
  proxyPort = 11234;

  mcp = import ../../home/mcp-servers.nix { inherit pkgs; };
  # godot-ai's defaults, which the editor plugin expects.
  godotPorts = "--port 8000 --ws-port 9500";
  # The plugin reads the record from $XDG_CONFIG_HOME/godot-ai/capabilities,
  # and Flatpak sets XDG_CONFIG_HOME to the app's own folder.
  godotEnv.GODOT_AI_CAPABILITY_DIR = "%h/.var/app/org.godotengine.Godot/config/godot-ai/capabilities";
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
      blenderPort = 19876;
      godotPort = 19500;
    };
    # Zelus builds its own package set so it can allow Claude Code (unfree)
    # without allowing it on the host; it's the same nixpkgs, so the store
    # paths are shared.
    vmArgs.pkgs = null;
    firewall.hostPorts = [
      vm.blenderPort
      vm.godotPort
    ];
    firewall.hostPortsLabel = "Blender and Godot";
    # Besides Lockdown and Permissive (modules/nixos/microvms.nix).
    firewall.modes = [
      {
        name = "local";
        label = "Local inference";
        short = "local";
        description = "Only the host's LM Studio, Blender and Godot; no internet";
        forwardPolicy = "drop";
        # After the redirect (below), so the proxy's port.
        input = [ "tcp dport ${toString proxyPort} accept" ];
        inputPolicy = "drop";
      }
    ];
  };

  systemd.tmpfiles.rules = [ "d ${vm.projectsDir} 0755 ${username} users -" ];

  # LM Studio for Zelus: listens on the host's end of the tap (FreeBind, so
  # it can start before Zelus brings the tap up) and hands each connection to
  # LM Studio's local server, whether that serves on localhost only or on the
  # local network. The firewall modes decide whether Zelus may use it.
  systemd.sockets.lmstudio-zelus = {
    description = "LM Studio for Zelus";
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "${vm.hostAddress}:${toString proxyPort}" ];
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
  # Zelus keeps using 10.20.1.1:1234. The redirect happens before the host's
  # firewall (and the VM's firewall mode) sees the connection, so both filter
  # on the proxy's port.
  networking.nat.extraCommands = ''
    iptables -w -t nat -A nixos-nat-pre -i ${vm.tap} -d ${vm.hostAddress} -p tcp \
      --dport ${toString vm.lmstudioPort} -j REDIRECT --to-ports ${toString proxyPort}
  '';
  networking.firewall.interfaces.${vm.tap}.allowedTCPPorts = [
    proxyPort
    vm.blenderPort
    vm.godotPort
  ];

  # Blender for Zelus, the same way: the add-on's localhost:9876, from the
  # tap's address.
  systemd.sockets.blender-zelus = {
    description = "Blender MCP add-on for Zelus";
    wantedBy = [ "sockets.target" ];
    listenStreams = [ "${vm.hostAddress}:${toString vm.blenderPort}" ];
    socketConfig.FreeBind = true;
  };
  systemd.services.blender-zelus = {
    description = "Blender MCP add-on for Zelus (proxy to localhost:9876)";
    requires = [ "blender-zelus.socket" ];
    serviceConfig = {
      ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:9876";
      DynamicUser = true;
      PrivateTmp = true;
    };
  };

  # The Godot MCP server, in your session: running before the editor opens,
  # so the plugin adopts it instead of trying to start one (it can't, inside
  # the Flatpak). The record is removed first and waited for after, so a
  # bridge never reads a stale one.
  systemd.user.services.godot-ai = {
    description = "Godot MCP server (godot-ai) for the editor and Zelus";
    wantedBy = [ "default.target" ];
    unitConfig.ConditionUser = username;
    environment = godotEnv;
    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/rm -f \${GODOT_AI_CAPABILITY_DIR}/http-8000.json";
      ExecStart = "${mcp.godot}/bin/godot-mcp --transport streamable-http ${godotPorts}";
      ExecStartPost = pkgs.writeShellScript "godot-ai-wait" ''
        # uv downloads the server on its first start.
        for _ in {1..600}; do
          [ -e "$GODOT_AI_CAPABILITY_DIR/http-8000.json" ] && exit 0
          ${pkgs.coreutils}/bin/sleep 0.5
        done
        exit 1
      '';
      TimeoutStartSec = 330;
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # One `godot-ai attach` per connection from Zelus, speaking MCP over the
  # socket as it would over stdin and stdout. Any number at once, so Claude
  # Code and opencode can both use Godot.
  systemd.user.sockets.godot-ai-zelus = {
    description = "Godot MCP for Zelus";
    wantedBy = [ "sockets.target" ];
    unitConfig.ConditionUser = username;
    listenStreams = [ "${vm.hostAddress}:${toString vm.godotPort}" ];
    socketConfig = {
      Accept = true;
      FreeBind = true;
    };
  };
  systemd.user.services."godot-ai-zelus@" = {
    description = "Godot MCP bridge for Zelus";
    requires = [ "godot-ai.service" ];
    after = [ "godot-ai.service" ];
    environment = godotEnv;
    serviceConfig = {
      ExecStart = "${mcp.godot}/bin/godot-mcp attach ${godotPorts}";
      StandardInput = "socket";
      StandardOutput = "socket";
      StandardError = "journal";
    };
  };
}
