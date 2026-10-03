# Nike, a microVM (microvm.nix) for VPN work: bash, neovim, tmux, ranger,
# openssh, python, openvpn and nmap, with the host's configs in orange. The
# guest itself is nike/default.nix; this is the host side.
#
#   sudo systemctl start microvm@nike     (it doesn't start at boot)
#   ssh nike                               user k, password k
#   ~/nike-share                           is ~/share on Nike, read-write
#
# Nike sits on its own tap interface (vm-nike) with a /32 route each way,
# and the host NATs its traffic to the internet. Nothing else on your LAN can
# reach it. Its status service writes VPN and utilization numbers to
# /var/lib/nike/status for the bar (home/eww/nike.py).
{
  lib,
  inputs,
  palette,
  keys,
  username,
  ...
}:
let
  nike = {
    tap = "vm-nike";
    mac = "02:00:00:4e:4b:01";
    hostAddress = "10.20.0.1";
    address = "10.20.0.2";
    shareDir = "/home/${username}/nike-share";
    statusDir = "/var/lib/nike/status";
    nameservers = [
      "9.9.9.9"
      "149.112.112.112"
    ];
    palette = import ../../nike/palette.nix palette;
    inherit keys;
  };
in
{
  microvm.vms.nike = {
    autostart = false;
    specialArgs = { inherit inputs nike; };
    config = ../../nike;
  };

  systemd.tmpfiles.rules = [
    "d ${nike.shareDir} 0755 ${username} users -"
    "d /var/lib/nike 0755 root root -"
    "d ${nike.statusDir} 0755 root root -"
  ];

  # The host's end of the tap: an address and a route to Nike. networkd
  # handles only this interface; NetworkManager keeps everything else.
  systemd.network = {
    enable = true;
    wait-online.enable = false;
    networks."30-nike" = {
      matchConfig.Name = nike.tap;
      address = [ "${nike.hostAddress}/32" ];
      routes = [ { Destination = "${nike.address}/32"; } ];
      linkConfig.RequiredForOnline = "no";
    };
  };
  networking.networkmanager.unmanaged = [ "interface-name:${nike.tap}" ];

  # Out to the internet through whatever the host uses (Wi-Fi, ethernet or
  # a WireGuard tunnel).
  networking.nat = {
    enable = true;
    internalIPs = [ "${nike.address}/32" ];
  };

  # Firewall modes, switched from the bar's Nike panel or with
  # `sudo vm-firewall set nike MODE` (modules/nixos/vm-firewall.nix). The
  # VPN modes let out only DNS and the platform's OpenVPN port, so nothing
  # leaves Nike outside the tunnel; once connected, the lab traffic is
  # inside it. Use the UDP connection pack (and add a port below if yours
  # differs).
  harmonia.vmFirewall.nike =
    let
      dns = "ip daddr { ${lib.concatStringsSep ", " nike.nameservers} } meta l4proto { tcp, udp } th dport 53 accept";
      vpnOnly = port: {
        forward = [
          dns
          "udp dport ${toString port} accept"
        ];
        forwardPolicy = "drop";
        inputPolicy = "drop";
      };
    in
    {
      inherit (nike) tap;
      default = "permissive";
      modes = [
        {
          name = "lockdown";
          label = "Lockdown";
          short = "lock";
          description = "Nothing out; only ssh from the host";
          forwardPolicy = "drop";
          inputPolicy = "drop";
        }
        (
          {
            name = "oscp";
            label = "OSCP";
            short = "oscp";
            description = "Only OffSec's OpenVPN (UDP 1194) and DNS";
          }
          // vpnOnly 1194
        )
        (
          {
            name = "htb";
            label = "Hack The Box";
            short = "htb";
            description = "Only Hack The Box's OpenVPN (UDP 1337) and DNS";
          }
          // vpnOnly 1337
        )
        {
          name = "permissive";
          label = "Permissive";
          short = "open";
          description = "Anything out to the internet";
          forwardPolicy = "accept";
          inputPolicy = "accept";
        }
      ];
    };

  programs.ssh.extraConfig = ''
    Host nike
      HostName ${nike.address}
      User k
  '';
}
