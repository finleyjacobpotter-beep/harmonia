#!/usr/bin/env bash
# Install base NixOS for harmonia, from the NixOS minimal ISO (UEFI).
#
# Wipes one disk, creates a GPT table with a 1 GiB ESP and a root partition
# (optionally LUKS2-encrypted, always ext4), installs a small base system
# that matches harmonia (systemd-boot, host harmonia, user u, flakes, git),
# and clones harmonia into ~u/harmonia with this machine's
# hardware-configuration.nix already in place.
#
# Run it as root from the live ISO:
#   sudo bash install.sh
#
# The walkthrough in docs/install.md explains each step.
set -euo pipefail

HOSTNAME_=harmonia
USERNAME=u
REPO=https://github.com/finleyjacobpotter-beep/harmonia
STATE_VERSION=26.05

die() { echo "error: $*" >&2; exit 1; }
ask() { local reply; read -rp "$1 [y/N] " reply; [[ $reply == [yY]* ]]; }

[[ $EUID -eq 0 ]] || die "run as root (sudo bash $0)"
[[ -d /sys/firmware/efi/efivars ]] || die "not booted in UEFI mode; turn off CSM/legacy boot in the firmware"
ping -c 1 -W 5 nixos.org >/dev/null 2>&1 || die "no network; connect with nmtui first"

# --- disk -------------------------------------------------------------------
lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -v ' loop$' || true
echo
read -rp "Disk to install on (e.g. /dev/nvme0n1, /dev/sda): " DISK
[[ -b $DISK ]] || die "$DISK is not a block device"

# NVMe and MMC partitions get a "p" before the number.
if [[ $DISK =~ [0-9]$ ]]; then PART=${DISK}p; else PART=$DISK; fi
ESP=${PART}1
ROOT=${PART}2

ask "Use LUKS encryption for the root partition?" && LUKS=1 || LUKS=0
read -rp "Swap file size in GiB (0 for none): " SWAP_GIB
[[ $SWAP_GIB =~ ^[0-9]+$ ]] || die "swap size must be a whole number"

if [[ $LUKS -eq 1 ]]; then
  while true; do
    read -rsp "LUKS passphrase: " PASSPHRASE; echo
    [[ -n $PASSPHRASE ]] || { echo "The passphrase can't be empty."; continue; }
    echo "You entered: $PASSPHRASE"
    ask "Is that correct?" && break
  done
  clear   # take the passphrase off the screen
fi

echo
echo "About to ERASE $DISK and install:"
echo "  $ESP  1 GiB ESP (vfat, label boot) at /boot"
echo "  $ROOT rest of the disk, ext4 (label nixos)$([[ $LUKS -eq 1 ]] && echo ' inside LUKS2')"
[[ $SWAP_GIB -gt 0 ]] && echo "  ${SWAP_GIB} GiB swap file at /swap/swapfile"
echo "  host $HOSTNAME_, user $USERNAME"
read -rp "Type ERASE to continue: " confirm
[[ $confirm == ERASE ]] || die "aborted"

# --- partition, format, mount ----------------------------------------------
swapoff -a || true
umount -R /mnt 2>/dev/null || true
cryptsetup close cryptroot 2>/dev/null || true

wipefs -af "$DISK"
parted -s "$DISK" -- mklabel gpt \
  mkpart ESP fat32 1MiB 1GiB \
  set 1 esp on \
  mkpart root 1GiB 100%
udevadm settle

mkfs.fat -F 32 -n boot "$ESP"

if [[ $LUKS -eq 1 ]]; then
  # --key-file=- reads the passphrase from stdin up to EOF; printf adds no
  # newline, so it matches what you type at the boot prompt.
  printf '%s' "$PASSPHRASE" | cryptsetup luksFormat --type luks2 --batch-mode --key-file=- "$ROOT"
  printf '%s' "$PASSPHRASE" | cryptsetup open --key-file=- "$ROOT" cryptroot
  unset PASSPHRASE
  ROOT_FS=/dev/mapper/cryptroot
else
  ROOT_FS=$ROOT
fi

mkfs.ext4 -F -L nixos "$ROOT_FS"
mount "$ROOT_FS" /mnt
mkdir -p /mnt/boot
mount -o umask=077 "$ESP" /mnt/boot

if [[ $SWAP_GIB -gt 0 ]]; then
  mkdir -p /mnt/swap
  dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=$((SWAP_GIB * 1024)) status=progress
  chmod 600 /mnt/swap/swapfile
  mkswap /mnt/swap/swapfile
  swapon /mnt/swap/swapfile
fi

# --- configure and install -------------------------------------------------
nixos-generate-config --root /mnt

cat > /mnt/etc/nixos/configuration.nix <<EOF
{ pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # Same boot loader as harmonia.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "$HOSTNAME_";
  networking.networkmanager.enable = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  users.users.$USERNAME = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # Flakes are needed to build harmonia.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [ git vim ];

  system.stateVersion = "$STATE_VERSION";
}
EOF

echo
echo "Installing. nixos-install asks for the root password at the end."
nixos-install

echo
echo "Set the password for $USERNAME (you log in to harmonia with it):"
until nixos-enter --root /mnt -c "passwd $USERNAME"; do :; done

# --- harmonia --------------------------------------------------------------
home=/mnt/home/$USERNAME
git() {
  if command -v git >/dev/null; then command git "$@"; else nix-shell -p git --run "git $(printf '%q ' "$@")"; fi
}
if git clone "$REPO" "$home/harmonia"; then
  cp /mnt/etc/nixos/hardware-configuration.nix "$home/harmonia/hosts/harmonia/hardware-configuration.nix"
  nixos-enter --root /mnt -c "chown -R $USERNAME:users /home/$USERNAME/harmonia"
  cloned=1
else
  echo "warning: couldn't clone $REPO; clone it after rebooting (see docs/install.md step 10)" >&2
  cloned=0
fi

swapoff -a || true
umount -R /mnt
[[ $LUKS -eq 1 ]] && cryptsetup close cryptroot

echo
echo "Base NixOS is installed. Remove the USB stick and reboot, then log in as $USERNAME and run:"
[[ $cloned -eq 1 ]] || echo "  git clone $REPO ~/harmonia && cp /etc/nixos/hardware-configuration.nix ~/harmonia/hosts/harmonia/"
echo "  cd ~/harmonia && sudo nixos-rebuild switch --flake .#harmonia"
