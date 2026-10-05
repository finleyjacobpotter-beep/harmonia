# Nike, a microVM (microvm.nix) for VPN work: bash, neovim, tmux, ranger,
# openssh, python, openvpn and nmap, with the host's configs in orange. The
# guest itself is nike/default.nix; this is the host side.
#
#   sudo systemctl start microvm@nike     (it doesn't start at boot)
#   ssh nike                               user k, password k
#   ~/nike-share                           is ~/share on Nike, read-write
#
# Nike sits on its own tap interface (vm-nike); the network, folders and
# `ssh nike` come from modules/nixos/microvms.nix. Its status service writes
# VPN and utilization numbers to /var/lib/nike/status for the bar
# (home/eww/microvm.py).
{ lib, config, ... }:
let
  inherit (config.harmonia.microvms.nike) vm;
  dns = "ip daddr { ${lib.concatStringsSep ", " vm.nameservers} } meta l4proto { tcp, udp } th dport 53 accept";
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
  harmonia.microvms.nike = {
    index = 0;
    user = "k";
    guest = ../../nike;
    key = "v";
    # Orange instead of the host's pink.
    colors = {
      primary = "orange";
      selection = "#463a3b";
      ansi = "yellow";
    };
    panel = {
      vpn = true;
      footer = "ssh nike (k / k) · ~/nike-share is ~/share on Nike";
    };

    # Besides Lockdown and Permissive (modules/nixos/microvms.nix): the VPN
    # modes let out only DNS and the platform's OpenVPN port, so nothing
    # leaves Nike outside the tunnel; once connected, the lab traffic is
    # inside it. Use the UDP connection pack (and add a port below if yours
    # differs).
    firewall.modes = [
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
    ];
  };
}
