# VPNs you can bring up and down without root, which the eww bar lists and
# switches from its network panel (home/eww.nix):
#
# - WireGuard: `nmcli connection import type wireguard file wg0.conf`
# - OpenVPN: `nmcli connection import type openvpn file client.ovpn`, through
#   NetworkManager's OpenVPN plugin; plain `openvpn` is installed too
# - openfortivpn (Fortinet SSL VPN): one config per VPN in
#   /etc/openfortivpn/NAME.conf, run as the openfortivpn@NAME service.
#   NetworkManager's fortisslvpn plugin was dropped from nixpkgs as insecure,
#   so this goes around NetworkManager.
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
    openfortivpn
  ];

  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];

  # openfortivpn's own openfortivpn@.service (-c /etc/openfortivpn/%I.conf).
  # The directory stays listable so the bar can find the configs; a config
  # holding a password should be root's alone (chmod 600).
  systemd.packages = [ pkgs.openfortivpn ];
  systemd.tmpfiles.rules = [ "d /etc/openfortivpn 0755 root root -" ];

  # Wheel users may start, stop and restart openfortivpn@ services without a
  # password, as the bar's Connect/Disconnect does; nothing else.
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          /^openfortivpn@[^\/]+\.service$/.test(action.lookup("unit")) &&
          ["start", "stop", "restart"].indexOf(action.lookup("verb")) >= 0 &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # A tunnel that routes everything (AllowedIPs = 0.0.0.0/0, OpenVPN's
  # redirect-gateway, openfortivpn's default routes) fails the strict reverse-path check; loose still drops
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
