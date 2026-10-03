# Rootless Podman + Buildah for containers. VMs are microVMs (Nike,
# modules/nixos/nike.nix).
{ pkgs, ... }:
{
  # Rootless Podman, no Docker daemon.
  virtualisation.podman = {
    enable = true;
    defaultNetwork.settings.dns_enabled = true; # containers resolve each other by name (compose)
  };
  environment.systemPackages = with pkgs; [
    podman-compose
    buildah
  ];
}
