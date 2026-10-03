# Nike, a microVM (microvm.nix) for VPN work: bash, neovim, tmux, ranger,
# openssh, python, openvpn and nmap, with the host's configs in red. The
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

  programs.ssh.extraConfig = ''
    Host nike
      HostName ${nike.address}
      User k
  '';
}
