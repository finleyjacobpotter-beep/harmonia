# libvirt/KVM + Vagrant (with the vagrant-libvirt provider, bundled by nixpkgs).
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
      # virtiofs synced folders for Vagrant
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };
  virtualisation.spiceUSBRedirection.enable = true;
  programs.virt-manager.enable = true;

  users.users.${username}.extraGroups = [
    "libvirtd"
    "kvm"
  ];

  environment.systemPackages = [ pkgs.vagrant ];
  environment.variables.VAGRANT_DEFAULT_PROVIDER = "libvirt";

  # Let VMs on libvirt bridges reach the host (DHCP/DNS from dnsmasq).
  networking.firewall.trustedInterfaces = [ "virbr+" ];
}
