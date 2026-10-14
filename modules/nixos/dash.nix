# The dash's system side (home/eww/eww.yuck, docs/bar.md): what only root,
# or a program with a network capability, can measure. Each runs as small
# and as locked down as it can, and the dash only reads what it writes.
#
# - the CPU's power draw (dash/cpu-power.py), for the cpu tile;
# - a connectivity test, DNS and an ICMP traceroute to google.com
#   (dash/connectivity.py), for the network tile: at boot, when
#   NetworkManager brings a connection up or renews its DHCP lease, and from
#   the tile's Run again, which wheel may start without a password;
# - nethogs, which the network tile runs to see which programs send and
#   receive, with only the capabilities it needs, and only for wheel.
{ pkgs, lib, ... }:
let
  pyScript = import ../../lib/python-script.nix { inherit pkgs lib; };
  cpuPower = pyScript "harmonia-cpu-power" { } ./dash/cpu-power.py;
  connectivity = pyScript "harmonia-connectivity" {
    runtimeInputs = with pkgs; [
      mtr
      iproute2
      systemd
    ];
  } ./dash/connectivity.py;

  # What every one of these services can do without: they read a few files
  # (or send probes) and write one.
  sandbox = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    MemoryDenyWriteExecute = true;
    SystemCallArchitectures = "native";
    RuntimeDirectoryMode = "0755";
  };
in
{
  # Root reads the energy counters, but needs no capability to (they are
  # root's files); no network either.
  systemd.services.harmonia-cpu-power = {
    description = "Publish the CPU's average power draw for the dash";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = sandbox // {
      ExecStart = lib.getExe cpuPower;
      RuntimeDirectory = "harmonia-cpu-power";
      CapabilityBoundingSet = "";
      PrivateNetwork = true;
      Restart = "on-failure";
    };
  };

  # Its own throwaway user, with raw sockets for mtr's ICMP probes.
  systemd.services.harmonia-connectivity = {
    description = "Test DNS and the route to google.com for the dash";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = sandbox // {
      Type = "oneshot";
      ExecStart = lib.getExe connectivity;
      DynamicUser = true;
      AmbientCapabilities = [ "CAP_NET_RAW" ];
      CapabilityBoundingSet = [ "CAP_NET_RAW" ];
      RuntimeDirectory = "harmonia-connectivity";
      RuntimeDirectoryPreserve = true;
      TimeoutStartSec = "2min";
    };
  };

  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "harmonia-connectivity-dispatch" ''
        case "$2" in
          up | dhcp4-change | dhcp6-change)
            ${pkgs.systemd}/bin/systemctl start --no-block harmonia-connectivity.service ;;
        esac
      '';
    }
  ];

  # The network tile's Run again (home/eww/conn.py).
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "harmonia-connectivity.service" &&
          action.lookup("verb") == "start" &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # nethogs maps traffic to processes by reading every process's sockets:
  # raw capture (net_raw, net_admin) and reading /proc of other users'
  # processes (dac_read_search, sys_ptrace). Only wheel can run it.
  security.wrappers.nethogs = {
    source = "${pkgs.nethogs}/bin/nethogs";
    owner = "root";
    group = "wheel";
    permissions = "u+rx,g+x";
    capabilities = "cap_net_admin,cap_net_raw,cap_dac_read_search,cap_sys_ptrace+ep";
  };
}
