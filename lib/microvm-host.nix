# The host side every microVM shares: the microvm.nix VM itself (not started
# at boot), its share and status folders, the host's end of its tap
# interface, NAT out to the internet and an `ssh <name>` entry. The VM sits
# on its own tap with a /32 route each way, so nothing else on your LAN can
# reach it.
#
#   imports = [
#     (import ../../lib/microvm-host.nix {
#       name = "nike";
#       user = "k";
#       vm = nike; # tap, mac, address, hostAddress, shareDir, statusDir, ...
#       config = ../../nike;
#     })
#   ];
#
# `vmArgs` adds to microvm.vms.<name>, `sshOptions` adds lines to its ssh
# Host entry.
{
  name,
  user,
  vm,
  config,
  vmArgs ? { },
  sshOptions ? [ ],
}:
{
  lib,
  inputs,
  username,
  ...
}:
{
  microvm.vms.${name} = {
    autostart = false;
    specialArgs = {
      inherit inputs;
      ${name} = vm;
    };
    inherit config;
  }
  // vmArgs;

  systemd.tmpfiles.rules = [
    "d ${vm.shareDir} 0755 ${username} users -"
    "d /var/lib/${name} 0755 root root -"
    "d ${vm.statusDir} 0755 root root -"
  ];

  # The host's end of the tap: an address and a route to the VM. networkd
  # handles only these interfaces; NetworkManager keeps everything else.
  systemd.network = {
    enable = true;
    wait-online.enable = false;
    networks."30-${name}" = {
      matchConfig.Name = vm.tap;
      address = [ "${vm.hostAddress}/32" ];
      routes = [ { Destination = "${vm.address}/32"; } ];
      linkConfig.RequiredForOnline = "no";
    };
  };
  networking.networkmanager.unmanaged = [ "interface-name:${vm.tap}" ];

  # Out to the internet through whatever the host uses (Wi-Fi, ethernet or
  # a VPN tunnel).
  networking.nat = {
    enable = true;
    internalIPs = [ "${vm.address}/32" ];
  };

  programs.ssh.extraConfig = ''
    Host ${name}
      HostName ${vm.address}
      User ${user}
  ''
  + lib.concatMapStrings (option: "  ${option}\n") sshOptions;
}
