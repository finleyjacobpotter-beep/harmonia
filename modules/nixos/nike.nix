# Nike, a microVM (microvm.nix) for VPN work: bash, neovim, tmux, ranger,
# openssh, python, openvpn and nmap, with the host's configs in orange. The
# guest itself is nike/default.nix; this is the host side.
#
#   sudo systemctl start microvm@nike     (it doesn't start at boot)
#   ssh nike                               user k, password k
#   ~/nike-share                           is ~/share on Nike, read-write
#
# Nike sits on its own tap interface (vm-nike); the network, folders and
# `ssh nike` are lib/microvm-host.nix. Its status service writes VPN and utilization numbers to
# /var/lib/nike/status for the bar (home/eww/microvm.py).
{
  lib,
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
  imports = [
    (import ../../lib/microvm-host.nix {
      name = "nike";
      user = "k";
      vm = nike;
      config = ../../nike;
    })
  ];

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
}
