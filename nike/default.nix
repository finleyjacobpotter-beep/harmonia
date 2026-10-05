# Nike, the microVM guest. What every microVM shares (network, shares,
# volumes, ssh, the status service, the host's shell configs) is
# lib/microvm-guest.nix; the host side (its network, shared folders,
# `ssh nike`) is modules/nixos/nike.nix.
#
# Login: k / k (ssh nike from the host). The shell, neovim, tmux and ranger
# are the host's own home-manager configs in orange instead of pink
# (colors in modules/nixos/nike.nix).
{ pkgs, ... }:
{
  imports = [
    (import ../lib/microvm-guest.nix {
      # /var holds the podman container images and volumes (BloodHound's
      # Neo4j and Postgres data, the pulled images), so it needs room.
      varSize = 24576;
      homeSize = 16384;
    })
    ./tools.nix # the OSCP toolset and Penelope
    ./labs.nix # podman + the Ligolo-ng and BloodHound compose services
  ];

  # The ligolo proxy and its container open a TUN interface.
  boot.kernelModules = [ "tun" ];

  # The password is "k" (`openssl passwd -6 k` to change it).
  users.users.k.hashedPassword = "$6$nikeharmonia$Io38a7YWoxdELeyAm2L52p.Fj8iawmoMe6fmu5uMaoDRhZpEY1XFFPa9kVOVbtJb6.56ipdchgqf8En/4WK6Y0";

  # bash, neovim, tmux and ranger come from home-manager.
  environment.systemPackages = with pkgs; [
    python3
    openvpn
    nmap
  ];
}
