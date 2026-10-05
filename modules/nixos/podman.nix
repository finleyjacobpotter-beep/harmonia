# Rootless Podman and podman-compose on every host (harmonia, cadmus and
# Dionysus on both arches). No Docker daemon. The Nike guest sets up its own
# podman with a docker socket for Mythic in nike/labs.nix.
{ pkgs, ... }:
{
  virtualisation.podman = {
    enable = true;
    defaultNetwork.settings.dns_enabled = true; # containers resolve each other by name (compose)
  };
  environment.systemPackages = with pkgs; [
    podman-compose
    buildah
  ];
}
