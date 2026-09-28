# Two libvirt VMs on qemu:///system, both with a virtio GPU (virgl 3D over a
# local SPICE display, opened with virt-manager):
#
#   harmonia-kali    Kali Linux, installed with the i3 desktop. Gets the i3
#                    config from vms/kali-i3.nix and this flake's neovim config
#                    through a read-only virtiofs share (mount tag "harmonia").
#   harmonia-ubuntu  Ubuntu Desktop (GNOME), stock.
#
# The domains and their empty disks are created by the harmonia-vms service
# on boot. The installer ISOs are several GB, so they are not part of the
# build: `sudo harmonia-vm-fetch` downloads the pinned versions and checks them.
{
  config,
  lib,
  pkgs,
  palette,
  keys,
  username,
  ...
}:
let
  imageDir = "/var/lib/libvirt/images";
  hm = config.home-manager.users.${username};

  kaliI3 = import ../../vms/kali-i3.nix { inherit palette keys; };

  # Neovim exactly as home-manager sets it up on the host: init.lua, the
  # other nvim/ config files (colours, lualine theme) and the plugin pack
  # (plugins + treesitter grammars), copied as real files so the guest can
  # read them without /nix/store.
  nvimConfigFiles = lib.filter (f: f.enable && lib.hasPrefix "nvim/" f.target && f.target != "nvim/init.lua") (
    lib.attrValues hm.xdg.configFile
  );
  nvimInit = pkgs.writeText "init.lua" hm.programs.neovim.initLua;
  nvimPack = hm.xdg.dataFile."nvim/site/pack/hm".source;

  # Run inside Kali: installs i3 and the tools the config uses, then copies
  # everything into place (existing files are kept as *.bak).
  kaliSetup = pkgs.writeText "setup.sh" ''
    #!/bin/sh
    # Usage (in the Kali guest):
    #   sudo mount -t virtiofs harmonia /mnt && sh /mnt/setup.sh
    set -eu
    src=$(dirname "$(readlink -f "$0")")

    sudo apt-get update
    sudo apt-get install -y kali-desktop-i3 i3status rofi dunst feh maim xclip \
      i3lock alacritty neovim ripgrep fd-find git

    put() { # put <source> <dest>
      mkdir -p "$(dirname "$2")"
      [ -e "$2" ] && rm -rf "$2.bak" && mv "$2" "$2.bak"
      cp -rL "$1" "$2"
      chmod -R u+w "$2"
    }
    put "$src/i3/config"        "$HOME/.config/i3/config"
    put "$src/i3status/config"  "$HOME/.config/i3status/config"
    put "$src/wallpaper.png"    "$HOME/.local/share/harmonia/wallpaper.png"
    put "$src/nvim/config"      "$HOME/.config/nvim"
    put "$src/nvim/pack"        "$HOME/.local/share/nvim/site/pack/hm"

    echo "Done. Log out and pick i3 at the login screen; the i3 modifier is Alt."
  '';

  kaliShare = pkgs.runCommand "harmonia-kali-share" { } ''
    mkdir -p $out/i3 $out/i3status $out/nvim/config
    cp ${pkgs.writeText "i3-config" kaliI3.i3} $out/i3/config
    cp ${pkgs.writeText "i3status-config" kaliI3.i3status} $out/i3status/config
    cp ${../../assets/wallpaper.png} $out/wallpaper.png
    cp ${kaliSetup} $out/setup.sh

    cp ${nvimInit} $out/nvim/config/init.lua
    ${lib.concatMapStrings (f: ''
      mkdir -p "$(dirname "$out/nvim/config/${lib.removePrefix "nvim/" f.target}")"
      cp -rL ${f.source} "$out/nvim/config/${lib.removePrefix "nvim/" f.target}"
    '') nvimConfigFiles}
    cp -rL ${nvimPack} $out/nvim/pack
  '';

  # Installer images, pinned by release. `sha256 = null` means the checksum is
  # read from the release's own SHA256SUMS at download time (and printed, so
  # it can be pinned here).
  vms = {
    kali = {
      memory = 4096;
      vcpus = 4;
      disk = "60G";
      iso = {
        name = "kali-linux-2026.2-installer-amd64.iso";
        url = "https://cdimage.kali.org/kali-2026.2/kali-linux-2026.2-installer-amd64.iso";
        sums = "https://cdimage.kali.org/kali-2026.2/SHA256SUMS";
        sha256 = null;
      };
      share = kaliShare;
    };
    ubuntu = {
      memory = 6144;
      vcpus = 4;
      disk = "60G";
      iso = {
        name = "ubuntu-26.04.1-desktop-amd64.iso";
        url = "https://releases.ubuntu.com/26.04.1/ubuntu-26.04.1-desktop-amd64.iso";
        sums = "https://releases.ubuntu.com/26.04.1/SHA256SUMS";
        sha256 = "601e30fbf5d97759367c632e2c33630665039b7e2158fd068403da3ccf1bda1f";
      };
      share = null;
    };
  };

  domainXml =
    name: vm:
    pkgs.writeText "harmonia-${name}.xml" ''
      <domain type="kvm">
        <name>harmonia-${name}</name>
        <memory unit="MiB">${toString vm.memory}</memory>
        <vcpu>${toString vm.vcpus}</vcpu>
        <os firmware="efi">
          <type arch="x86_64" machine="q35">hvm</type>
          <firmware><feature enabled="no" name="secure-boot"/></firmware>
          <boot dev="hd"/>
          <boot dev="cdrom"/>
        </os>
        <features><acpi/><apic/></features>
        <cpu mode="host-passthrough"/>
        <clock offset="utc"/>
        ${lib.optionalString (vm.share != null) ''
          <memoryBacking><source type="memfd"/><access mode="shared"/></memoryBacking>
        ''}
        <devices>
          <disk type="file" device="disk">
            <driver name="qemu" type="qcow2" discard="unmap"/>
            <source file="${imageDir}/harmonia-${name}.qcow2"/>
            <target dev="vda" bus="virtio"/>
          </disk>
          <disk type="file" device="cdrom">
            <driver name="qemu" type="raw"/>
            <source file="${imageDir}/${vm.iso.name}"/>
            <target dev="sda" bus="sata"/>
            <readonly/>
          </disk>
          <interface type="network">
            <source network="default"/>
            <model type="virtio"/>
          </interface>
          <graphics type="spice">
            <listen type="none"/>
            <gl enable="yes"/>
          </graphics>
          <video>
            <model type="virtio" heads="1" primary="yes">
              <acceleration accel3d="yes"/>
            </model>
          </video>
          <channel type="spicevmc">
            <target type="virtio" name="com.redhat.spice.0"/>
          </channel>
          <channel type="unix">
            <target type="virtio" name="org.qemu.guest_agent.0"/>
          </channel>
          <input type="tablet" bus="usb"/>
          <sound model="ich9"/>
          <audio id="1" type="spice"/>
          <rng model="virtio">
            <backend model="random">/dev/urandom</backend>
          </rng>
          ${lib.optionalString (vm.share != null) ''
            <filesystem type="mount" accessmode="passthrough">
              <driver type="virtiofs"/>
              <source dir="${vm.share}"/>
              <target dir="harmonia"/>
            </filesystem>
          ''}
        </devices>
      </domain>
    '';

  fetch = pkgs.writeShellApplication {
    name = "harmonia-vm-fetch";
    runtimeInputs = with pkgs; [
      curl
      coreutils
      gawk
    ];
    text = ''
      # Usage: sudo harmonia-vm-fetch [kali|ubuntu]   (default: both)
      fetch() { # fetch <name> <url> <sums-url> <sha256 or "">
        dest=${imageDir}/$1
        if [ -e "$dest" ]; then echo "$1: already downloaded"; return; fi
        expected=$4
        if [ -z "$expected" ]; then
          expected=$(curl -fsSL "$3" | awk -v n="$1" '$2 == n || $2 == "*" n { print $1 }')
          echo "$1: no pinned checksum, using $3: $expected"
        fi
        curl -fL --output "$dest.part" "$2"
        echo "$expected  $dest.part" | sha256sum -c -
        mv "$dest.part" "$dest"
      }
      [ $# -gt 0 ] || set -- ${toString (lib.attrNames vms)}
      for vm in "$@"; do
        case $vm in
          ${lib.concatStrings (
            lib.mapAttrsToList (name: vm: ''
              ${name}) fetch ${vm.iso.name} ${vm.iso.url} ${vm.iso.sums} "${toString vm.iso.sha256}" ;;
            '') vms
          )}
          *) echo "unknown VM: $vm (expected: ${toString (lib.attrNames vms)})" >&2; exit 1 ;;
        esac
      done
    '';
  };
in
{
  environment.systemPackages = [ fetch ];

  # (Re)define the domains and create any missing disks. Re-running `virsh
  # define` updates a domain in place; a running VM picks it up on next boot.
  systemd.services.harmonia-vms = {
    description = "Define the harmonia libvirt VMs";
    after = [ "libvirtd.service" ];
    requires = [ "libvirtd.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      config.virtualisation.libvirtd.package
      pkgs.qemu_kvm
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p ${imageDir}
      if virsh net-info default >/dev/null 2>&1; then
        virsh net-autostart default
        virsh net-start default 2>/dev/null || true
      fi
      ${lib.concatStrings (
        lib.mapAttrsToList (name: vm: ''
          [ -e ${imageDir}/harmonia-${name}.qcow2 ] ||
            qemu-img create -f qcow2 ${imageDir}/harmonia-${name}.qcow2 ${vm.disk}
          virsh define ${domainXml name vm}
        '') vms
      )}
    '';
  };
}
