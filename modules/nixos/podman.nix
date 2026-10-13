# Rootless Podman and podman-compose on every host (harmonia, cadmus and
# Dionysus on both arches). No Docker daemon. The Nike guest sets up its own
# podman with a docker socket for Mythic in nike/labs.nix.
{ config, pkgs, ... }:
let
  podman = "${config.virtualisation.podman.package}/bin/podman";
in
{
  virtualisation.podman = {
    enable = true;
    defaultNetwork.settings.dns_enabled = true; # containers resolve each other by name (compose)
  };
  environment.systemPackages = with pkgs; [
    podman-compose
    buildah
  ];

  # The bar's pods panel (home/eww/pods.py) also lists root's containers
  # (virtualisation.oci-containers), which only root can see. Allow
  # exactly these two read-only listings without a password; not inspect,
  # which would print the containers' environment variables.
  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands =
        map
          (args: {
            command = "${podman} ${args}";
            options = [ "NOPASSWD" ];
          })
          [
            "ps -a --format json"
            "stats --no-stream --format json"
          ];
    }
  ];
}
