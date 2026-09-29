# WireGuard through NetworkManager, so tunnels are toggled without root (your
# user is in the networkmanager group) and the eww bar can list and switch
# them (home/eww.nix). No keys live in this repo: import your own configs
# with `nmcli connection import type wireguard file wg0.conf`
# (docs/wireguard.md).
{ pkgs, ... }:
let
  wg = "${pkgs.wireguard-tools}/bin/wg";
in
{
  environment.systemPackages = [ pkgs.wireguard-tools ];

  # A tunnel that routes everything (AllowedIPs = 0.0.0.0/0) fails the strict
  # reverse-path check; loose still drops spoofed packets from other hosts.
  networking.firewall.checkReversePath = "loose";

  # The bar shows each tunnel's endpoint and last handshake, which only root
  # can read. Allow exactly these read-only queries without a password;
  # neither prints private keys (unlike `wg show … dump` or `private-key`).
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
