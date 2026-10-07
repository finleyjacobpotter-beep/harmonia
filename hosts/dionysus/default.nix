# Dionysus: harmonia's Sway desktop with the Nike OSCP toolset native on the
# host and no microVMs. Where harmonia keeps the pentesting toolset in a
# microVM (Nike), Dionysus runs the same packages and podman lab stacks
# natively, so the whole thing builds on aarch64 and x86_64 alike. Steam,
# Blender and Godot are not on Dionysus, the AI coding agents (Claude Code,
# opencode) have been removed, and the other architecture-specific and
# flatpak-only modules harmonia uses (gaming, LM Studio, the Nike microVM
# itself) are left out too.
{
  pkgs,
  lib,
  username,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../base.nix
    # The same pentesting toolset Nike carries, built natively here: the OSCP
    # package set and the podman lab stacks (CyberChef, ZAP, BloodHound,
    # Mythic, Ligolo-ng). These are plain NixOS modules, so they apply to a
    # real host as well as the microVM guest they were written for.
    ../../nike/tools.nix
    ../../nike/labs.nix
  ];

  # Round out Nike's toolset with the extras nike/default.nix adds on top of
  # tools.nix/labs.nix: OpenVPN for lab connection packs, and the tun module
  # Ligolo-ng needs for its pivot interface.
  environment.systemPackages = [ pkgs.openvpn ];
  boot.kernelModules = [ "tun" ];

  # harmonia's desktop enables 32-bit graphics for 32-bit Steam/Wine; there is
  # no i686 Mesa on aarch64 and Dionysus ships no 32-bit games, so turn it off.
  hardware.graphics.enable32Bit = lib.mkForce false;

  # SPICE guest services, for running Dionysus under virt-manager/QEMU with a
  # SPICE display: the vdagent gives clipboard sharing and display resizing,
  # webdavd serves the host's shared folder (spice-webdav channel).
  services.spice-vdagentd.enable = true;
  services.spice-webdavd.enable = true;

  # VirtualBox guest additions, for running Dionysus under VirtualBox (x86_64,
  # or VirtualBox 7.1+ on Apple silicon): display resizing (VMSVGA), shared
  # clipboard, drag and drop, and vboxsf shared folders. Every guest service
  # is conditioned on the hypervisor being VirtualBox, so this and the SPICE
  # services above coexist: under QEMU these stay idle, under VirtualBox SPICE
  # has no channel and stays idle.
  virtualisation.virtualbox.guest.enable = true;
  # vboxsf shared folders are mounted group vboxsf.
  users.users.${username}.extraGroups = [ "vboxsf" ];

  # Automount the hypervisor's shared folder at /mnt/share, owned by the
  # Dionysus user. This expects a VirtualBox shared folder named "share"
  # (VM → Settings → Shared Folders, or `VBoxManage sharedfolder add`); the
  # vboxsf module comes from the guest additions above. uid/gid are the sole
  # normal user's (d → uid 1000, primary group "users" → gid 100). nofail
  # (and the automount below) keep boot clean when the share is absent, e.g.
  # under QEMU, where SPICE webdav serves files a different way instead.
  fileSystems."/mnt/share" = {
    device = "share";
    fsType = "vboxsf";
    options = [
      "rw"
      "nofail"
      "uid=1000"
      "gid=100"
      "x-systemd.automount"
    ];
  };

  # Sway in a VM: VMSVGA (VirtualBox) and plain virtio-gpu have no working
  # hardware cursor plane and, on Apple silicon or with 3D off, no GPU, so
  # the cursor glitches and the GL renderer draws a broken screen. Draw the
  # cursor in software and render with pixman (CPU) instead; apps still get
  # OpenGL through Mesa's llvmpipe.
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_RENDERER = "pixman";
  };
}
