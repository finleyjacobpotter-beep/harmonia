# Deploying servers with nixos-anywhere

[nixos-anywhere](https://github.com/nix-community/nixos-anywhere) installs a
flake config onto another machine over SSH. It boots the target into a NixOS
installer with kexec (unless it is already running one), partitions the disk
with [disko](https://github.com/nix-community/disko) from the host's
`disk.nix`, and installs. Both tools are on harmonia and cadmus
(`modules/nixos/deploy.nix`).

**It wipes the target's disk.** Everything on it is gone.

There are two servers in the flake:

| Host | Machine | Boot | Disk |
| --- | --- | --- | --- |
| `proteus` | a DigitalOcean droplet | GRUB, legacy BIOS | `/dev/vda` |
| `atlas` | a Minisforum MS-01 SE | systemd-boot, UEFI | `/dev/nvme0n1` |

Both are headless (`hosts/server.nix`): no Sway and no Flatpak, but the same
user (`u`), locale, nix settings, podman, and bash, tmux, ranger, neovim and
Rust tools as the desktop. SSH takes keys only, root can log in with a key but
never a password, the firewall lets in SSH and nothing else, and the network
comes up with DHCP on every wired port.

## Before the first deploy

Put your SSH public key in [`hosts/server-keys.nix`](../hosts/server-keys.nix)
and commit it (nixos-anywhere builds from the flake, and a flake only sees
files git knows about):

```nix
[
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... u@harmonia"
]
```

`cat ~/.ssh/id_ed25519.pub` prints yours; `ssh-keygen -t ed25519` makes one.
Without a key, evaluation warns and only the console gets in afterwards.

## A DigitalOcean droplet (proteus)

1. Create a droplet from any x86_64 image DigitalOcean offers (Ubuntu or
   Debian is fine; it is only there to be replaced) with **at least 2 GB of
   RAM**: the kexec installer needs 1.5 GB free. Add your SSH key to it in
   the droplet form, so you can log in as root.
2. From `~/harmonia` on harmonia or cadmus:
   ```sh
   nixos-anywhere --flake .#proteus root@<droplet ip>
   ```
   It builds proteus locally, copies it over and reboots the droplet.
3. Log in as `u` with your key: `ssh u@<droplet ip>`. Run `passwd` to replace
   the `changeme` password, which sudo and DigitalOcean's web console ask for.

nixpkgs' DigitalOcean module handles the droplet itself: virtio drivers, the
serial console, the metadata service and DigitalOcean's monitoring agent. It
also gives root the droplet's own SSH keys, as well as the ones in
`hosts/server-keys.nix`. IPv4 comes from DigitalOcean's DHCP; IPv6 and VPC
addresses are not configured.

## A Minisforum MS-01 SE (atlas)

1. In the BIOS (Del at boot), make sure it boots UEFI and turn **Secure Boot
   off**.
2. Boot the NixOS minimal ISO from a USB stick (see
   [Installing base NixOS](install.md#1-make-the-usb-stick)), plug in a
   network cable (nixos-anywhere doesn't do Wi-Fi), and set a root password
   so you can SSH in:
   ```sh
   sudo passwd root
   ip -brief address   # its IP
   ```
3. Check which disk to install on. The MS-01 has three M.2 slots, so
   `nvme0n1` is not always the one you mean:
   ```sh
   ls -l /dev/disk/by-id/ | grep nvme
   ```
   If there is more than one drive, put the right `/dev/disk/by-id/nvme-…`
   path in [`hosts/atlas/disk.nix`](../hosts/atlas/disk.nix) and commit it.
4. From `~/harmonia` on harmonia or cadmus, install and write the real
   hardware config in the same step:
   ```sh
   nixos-anywhere --flake .#atlas \
     --generate-hardware-config nixos-generate-config ./hosts/atlas/hardware-configuration.nix \
     root@<atlas ip>
   ```
   The generated file has no file systems in it (those come from
   `disk.nix`). Commit it, so later rebuilds use it too.
5. Log in with `ssh u@<atlas ip>` and run `passwd`.

atlas also gets the Intel CPU and SSD profiles from nixos-hardware, the
redistributable firmware for its network cards, and fwupd for BIOS updates
(`fwupdmgr update`, where Minisforum publishes them).

## Updating a server

After the install, rebuild from harmonia or cadmus over SSH; nothing is wiped:

```sh
nixos-rebuild switch --flake .#proteus --target-host root@<droplet ip>
nixos-rebuild switch --flake .#atlas --target-host root@<atlas ip>
```

Or clone harmonia onto the server and run `rebuild` there, like on the
desktop.

## Adding another server

Copy `hosts/proteus` (for another droplet) or `hosts/atlas` (for bare metal)
to `hosts/<name>`, adjust its `disk.nix`, and add it to `flake.nix`:

```nix
<name> = mkServer { hostname = "<name>"; };
```

For bare metal, keep `hardware-configuration.nix` a placeholder and let
`--generate-hardware-config` write it, as for atlas. For an aarch64 server,
pass `system = "aarch64-linux";` and drop the Intel profile; build on the
target with `--build-on remote`, since harmonia and cadmus are x86_64.
