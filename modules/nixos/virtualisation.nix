# libvirt/KVM for VMs, rootless Podman + Buildah for containers.
{
  pkgs,
  username,
  ...
}:
{
  virtualisation.libvirtd = {
    enable = true;
    onBoot = "ignore";
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;
      # virtiofs shared folders
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };
  virtualisation.spiceUSBRedirection.enable = true;
  programs.virt-manager.enable = true;

  users.users.${username}.extraGroups = [
    "libvirtd"
    "kvm"
  ];

  # Rootless Podman, no Docker daemon.
  virtualisation.podman = {
    enable = true;
    defaultNetwork.settings.dns_enabled = true; # containers resolve each other by name (compose)
  };
  environment.systemPackages = with pkgs; [
    podman-compose
    buildah
  ];

  # Let VMs on libvirt bridges reach the host (DHCP/DNS from dnsmasq).
  networking.firewall.trustedInterfaces = [ "virbr+" ];
}
