# VPNs through NetworkManager, so tunnels are toggled without root (your user
# is in the networkmanager group) and the eww bar can list and switch them
# from its network panel (home/eww.nix):
#
# - WireGuard: `nmcli connection import type wireguard file wg0.conf`
# - OpenVPN: `nmcli connection import type openvpn file client.ovpn`, through
#   NetworkManager's OpenVPN plugin; plain `openvpn` is installed too
# - Proton VPN: its own app (protonvpn-app), which makes NetworkManager
#   connections the bar picks up
#
# No keys or configs live in this repo (docs/vpn.md).
{ pkgs, ... }:
let
  wg = "${pkgs.wireguard-tools}/bin/wg";
in
{
  environment.systemPackages = with pkgs; [
    wireguard-tools
    openvpn
    proton-vpn
  ];

  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];

  # A tunnel that routes everything (AllowedIPs = 0.0.0.0/0, OpenVPN's
  # redirect-gateway) fails the strict reverse-path check; loose still drops
  # spoofed packets from other hosts.
  networking.firewall.checkReversePath = "loose";

  # The bar shows each WireGuard tunnel's endpoint and last handshake, which
  # only root can read. Allow exactly these read-only queries without a
  # password; neither prints private keys (unlike `wg show … dump` or
  # `private-key`).
  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands =
        map
          (what: {
            command = "${wg} show all ${what}";
            options = [ "NOPASSWD" ];
          })
          [
            "endpoints"
            "latest-handshakes"
          ];
    }
  ];
}
