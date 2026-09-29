# VMs and containers

Your user is in `libvirtd` and `kvm`, so `virt-manager` and `virsh` work without
root. Containers use rootless **podman** (with `podman-compose` and `buildah`);
there is no Docker daemon and no `docker` alias.

Two VMs are defined on `qemu:///system` at boot (`modules/nixos/vms.nix`), both
with a virtio GPU (virgl 3D over a local SPICE display) and UEFI:

| VM | Desktop | RAM / vCPUs / disk |
| --- | --- | --- |
| `harmonia-kali` | i3 | 4 GiB / 4 / 60 GB |
| `harmonia-ubuntu` | GNOME (stock Ubuntu Desktop) | 6 GiB / 4 / 60 GB |

1. Download the pinned installers into `/var/lib/libvirt/images` (checksums are
   verified):
   ```sh
   sudo harmonia-vm-fetch          # or: sudo harmonia-vm-fetch kali
   ```
2. Start a VM from virt-manager (`Super+o v`) and install as usual. For Kali,
   pick **i3** on the installer's desktop-environment screen.
3. Kali only: the VM has one **read-write** virtiofs share: `~/vms/kali-shared`
   on the host is `~/shared` in the guest. Files keep their uid, and the first
   user on both sides is uid 1000, so they belong to you on both. On every
   boot and rebuild the host puts an install script in it
   (`~/vms/kali-shared/harmonia/`). The first time, inside the guest run:
   ```sh
   mkdir -p ~/shared && sudo mount -t virtiofs shared ~/shared
   sh ~/shared/harmonia/install.sh
   ```
   It installs i3's helpers (rofi, dunst, feh, maim, i3lock, xss-lock…) plus
   neovim, ripgrep, fd, fzf, tmux and ranger, and copies the configs into place
   (existing ones are kept as `*.bak`):
   - the i3 and i3status config, and the wallpaper
   - this flake's neovim config (init.lua, Miami Wind colours, plugins and
     treesitter grammars)
   - harmonia's bash setup: the Miami Wind prompt, vi-mode readline, fzf
     colours, history settings and aliases (without the host-only `zen` and
     `rebuild`), with bash made your login shell instead of zsh

   It also adds the share to the guest's `/etc/fstab`, so it mounts on every
   boot after that. Run the script again after a host rebuild to pick up
   config changes.

Kali locks after 10 minutes idle and blanks the screen after 15, like the
host. The **caffeine** block on the left of its bar toggles that: click it and
it reads `caffeine on` in orange, and nothing locks or blanks until you click
it again. It resets to off when you log in again.

The Kali i3 config ([`vms/kali-i3.nix`](../vms/kali-i3.nix)) uses **Alt** as its
modifier with vim directions (`Alt+h/j/k/l` focus, `Alt+Shift+h/j/k/l` move,
`Alt+Return` terminal, `Alt+d` rofi, `Alt+q` close, `Alt+1…0` workspaces,
`Alt+r` resize mode, `Alt+Shift+e` system mode). Super stays with the host's
sway, and neovim never binds Alt, so nothing overlaps. If your GPU driver has
no virgl support, set `accel3d="no"` and `<gl enable="no"/>` in `vms.nix`.
