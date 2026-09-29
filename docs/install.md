# Installing base NixOS for harmonia

This gets a minimal, bootable NixOS onto a UEFI machine, set up the way
harmonia expects, and stops where harmonia's own install steps begin.

harmonia assumes:

- **UEFI** with **systemd-boot**, ESP mounted at `/boot`
- a user named **`u`** (set in `flake.nix`) in the `wheel` group
- **flakes** enabled (`nix-command` + `flakes`)
- host name **`harmonia`** (the flake output is `.#harmonia`)
- an **x86_64** machine
- a real `hosts/harmonia/hardware-configuration.nix` from *your* machine (the one in the repo is a placeholder)

**Scripted version:** [`scripts/install.py`](../scripts/install.py) does steps
3 to 10 for you. Boot the ISO, get online (steps 1 and 2), then:

```sh
curl -LO https://raw.githubusercontent.com/finleyjacobpotter-beep/harmonia/main/scripts/install.py
chmod +x install.py && sudo ./install.py   # fetches Python via nix-shell
```

It asks for the disk, whether to use LUKS (the passphrase is read in, then
shown back to you to confirm before anything is written), and a swap size,
then asks you to type `ERASE` before touching the disk. It ends with your
hardware config already in `~u/harmonia`, ready for step 11.

The layout below is GPT with two partitions: a 1 GiB ESP and an ext4 root.
LUKS encryption is optional and marked **(LUKS)** where the steps differ.

---

## 1. Make the USB stick

Download the **Minimal ISO, 64-bit Intel/AMD** from <https://nixos.org/download/#nixos-iso>
(the latest stable, currently 26.05, is fine: harmonia pins its own nixpkgs,
so the ISO version only matters for the base system).

Write it to a USB stick (this erases the stick, so check the device name with `lsblk`):

```sh
sudo dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

In the firmware settings: boot in **UEFI** mode (turn off CSM/legacy boot) and
turn off **Secure Boot** (systemd-boot on NixOS isn't signed out of the box).
Then boot from the stick.

## 2. Boot the installer and get online

You land at a root-capable shell as user `nixos`. Switch to root:

```sh
sudo -i
```

Check that you really booted in UEFI mode (this directory must exist):

```sh
ls /sys/firmware/efi/efivars
```

**Wired:** it usually just works. **Wi-Fi:**

```sh
nmtui          # pick "Activate a connection"
```

Test it: `ping -c 3 nixos.org`

## 3. Partition the disk

Find your disk (e.g. `/dev/nvme0n1` or `/dev/sda`):

```sh
lsblk
```

**Everything on this disk will be erased.** Set a variable so the rest of the
commands can be copied as they are:

```sh
DISK=/dev/nvme0n1          # change this
```

Create a GPT table, a 1 GiB ESP and a root partition that fills the rest:

```sh
parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart ESP fat32 1MiB 1GiB
parted "$DISK" -- set 1 esp on
parted "$DISK" -- mkpart root 1GiB 100%
```

Partition names: NVMe disks get a `p` (`/dev/nvme0n1p1`), SATA disks don't (`/dev/sda1`):

```sh
ESP=${DISK}p1;  ROOT=${DISK}p2     # NVMe
# ESP=${DISK}1; ROOT=${DISK}2      # SATA / USB / virtio (/dev/sda, /dev/vda)
```

## 4. Format and mount

### Without encryption

```sh
mkfs.fat -F 32 -n boot "$ESP"
mkfs.ext4 -L nixos "$ROOT"

mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/boot /mnt/boot
```

### (LUKS) With encryption

```sh
mkfs.fat -F 32 -n boot "$ESP"
cryptsetup luksFormat --type luks2 "$ROOT"     # type YES, then your passphrase
cryptsetup open "$ROOT" cryptroot
mkfs.ext4 -L nixos /dev/mapper/cryptroot

mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/boot /mnt/boot
```

`nixos-generate-config` sees the open LUKS device and writes the matching
`boot.initrd.luks.devices` entry into the hardware config for you, so harmonia
needs no extra changes for it.

### Swap (optional)

harmonia doesn't set up swap. If you want some, a swap file is simplest:

```sh
mkdir -p /mnt/swap
dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=8192 status=progress   # 8 GiB
chmod 600 /mnt/swap/swapfile
mkswap /mnt/swap/swapfile
swapon /mnt/swap/swapfile
```

The hardware config generated in the next step picks it up.

## 5. Generate the config

```sh
nixos-generate-config --root /mnt
```

This writes two files:

- `/mnt/etc/nixos/hardware-configuration.nix`: your disks, kernel modules and
  CPU. **This is the file harmonia needs later**, so keep it.
- `/mnt/etc/nixos/configuration.nix`: the base system, which you edit now.

## 6. Edit the base configuration

```sh
nano /mnt/etc/nixos/configuration.nix
```

Replace its contents with this. It matches harmonia's own settings, so
the switch later is small:

```nix
{ pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Same boot loader as harmonia.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "harmonia";
  networking.networkmanager.enable = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  # harmonia's user. You set the password in step 8.
  users.users.u = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # Flakes are needed to build harmonia.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # git is needed to clone harmonia (and flakes read the repo through git).
  environment.systemPackages = with pkgs; [ git vim ];

  # Keep this at the ISO's release. harmonia sets its own stateVersion.
  system.stateVersion = "26.05";
}
```

If you use a different login name, change `u` here **and** `username` in
harmonia's `flake.nix` later. If your timezone or keymap is different, you
can set them here too, and in `hosts/harmonia/default.nix` later.

## 7. Install

```sh
nixos-install
```

This downloads and builds the base system. At the end it asks for a
**root password**; set one.

## 8. Set `u`'s password

Still in the installer, before rebooting:

```sh
nixos-enter --root /mnt -c 'passwd u'
```

Note: because `u` already has a password now, harmonia's
`initialPassword = "changeme"` won't apply (it only applies to a user that
doesn't exist yet). You'll log in to harmonia with **this** password, not
`changeme`.

## 9. Reboot

```sh
umount -R /mnt
# (LUKS) cryptsetup close cryptroot
reboot
```

Remove the USB stick. You'll get the systemd-boot menu, then (LUKS) a
passphrase prompt, then a text login. Log in as **`u`**.

Get online again if you're on Wi-Fi: `nmtui`.

## 10. Get harmonia and drop in your hardware config

```sh
git clone https://github.com/finleyjacobpotter-beep/harmonia ~/harmonia
cd ~/harmonia
cp /etc/nixos/hardware-configuration.nix hosts/harmonia/hardware-configuration.nix
git add hosts/harmonia/hardware-configuration.nix
```

A flake only sees files git tracks. The placeholder is already tracked, so
your edited copy is picked up either way (you'll see a "Git tree is dirty"
warning, which is harmless); the `git add` just keeps that habit for any new
file you create later, which would otherwise be invisible to the build. Commit
it if you like, but don't push your machine's hardware file to the public repo
unless you mean to.

(Copying the file generated during install is the same as running
`sudo nixos-generate-config --show-hardware-config > hosts/harmonia/hardware-configuration.nix`
as the README says; either works.)

## 11. Hand-off: harmonia's own install steps

From here, follow the [README's **Install** section](../README.md#install). With the base config
above, step 1 (hostname/username/timezone) is already done if you kept the
defaults, and step 2 (hardware config) is the step you just did. What's left:

```sh
cd ~/harmonia
sudo nixos-rebuild switch --flake .#harmonia
```

The first build is large (latest kernel, sway, QEMU/libvirt, all neovim
treesitter grammars, the Tulasi icon theme build), so it takes a while. When
it finishes, reboot; you'll get the tuigreet login, and logging in as `u`
(with your password from step 8) starts sway.

After that, see the docs: `zen-miami-wind` after first launching Zen
([zen.md](zen.md)), `sudo harmonia-vm-fetch` for the VMs
([vms-and-containers.md](vms-and-containers.md)), and the secrets first-run steps ([secrets.md](secrets.md)).

---

## Troubleshooting

- **`error: experimental Nix feature 'flakes' is disabled`**: the base config
  didn't get the `nix.settings.experimental-features` line. Add it to
  `/etc/nixos/configuration.nix` and run `sudo nixos-rebuild switch`, or pass
  `--extra-experimental-features 'nix-command flakes'` once.
- **`repository path ... is not owned by current user`** when running
  `sudo nixos-rebuild` in `~/harmonia`: run it as `u` and let it ask for sudo
  itself: `nixos-rebuild switch --flake .#harmonia --sudo`
  (older versions: `--use-remote-sudo`).
- **No boot menu after reboot**: the machine booted the installer in legacy
  mode, so no EFI boot entry was made. Re-check step 2 (`efivars` must exist)
  and reinstall.
- **Wrong disk name in `fileSystems`**: you're still using the placeholder
  hardware config. Redo step 10.
