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
3. Kali only: the VM has a read-only virtiofs share with the i3 config, this
   flake's neovim config (init.lua, Miami Wind colours, plugins and
   treesitter grammars) and the wallpaper. Inside the guest run:
   ```sh
   sudo mount -t virtiofs harmonia /mnt && sh /mnt/setup.sh
   ```
   It installs i3's helpers (rofi, dunst, feh, maim, i3lock…) plus neovim,
   ripgrep, fd, fzf, tmux and ranger, and copies the configs into place
   (existing ones are kept as `*.bak`). That includes harmonia's bash setup:
   the Miami Wind prompt, vi-mode readline, fzf colours, history settings and
   aliases (without the host-only `zen` and `rebuild`), with bash made your
   login shell instead of zsh.
4. Kali also has a **read-write** virtiofs share: `~/vms/kali-shared` on the
   host is `~/shared` in the guest. `setup.sh` adds it to the guest's
   `/etc/fstab`, so it mounts on every boot. Files keep their uid, and the
   first user on both sides is uid 1000, so they belong to you on both.

The Kali i3 config ([`vms/kali-i3.nix`](../vms/kali-i3.nix)) uses **Alt** as its
modifier with vim directions (`Alt+h/j/k/l` focus, `Alt+Shift+h/j/k/l` move,
`Alt+Return` terminal, `Alt+d` rofi, `Alt+q` close, `Alt+1…0` workspaces,
`Alt+r` resize mode, `Alt+Shift+e` system mode). Super stays with the host's
sway, and neovim never binds Alt, so nothing overlaps. If your GPU driver has
no virgl support, set `accel3d="no"` and `<gl enable="no"/>` in `vms.nix`.
