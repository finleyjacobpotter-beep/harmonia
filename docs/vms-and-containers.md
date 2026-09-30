# VMs and containers

Your user is in `libvirtd` and `kvm`, so `virt-manager` and `virsh` work without
root. Containers use rootless **podman** (with `podman-compose` and `buildah`);
there is no Docker daemon and no `docker` alias.

Two VMs are defined on `qemu:///system` at boot (`modules/nixos/vms.nix`), both
booting UEFI (secure boot off) with an emulated TPM 2.0 (swtpm), a plain VGA
adapter and a VNC display that listens on localhost only. virt-manager opens it
as usual, or point any VNC viewer at the port below (from another machine,
tunnel it: `ssh -L 5900:127.0.0.1:5900 host`). There is no 3D acceleration and
no guest audio.

| VM | Desktop | RAM / vCPUs / disk | VNC |
| --- | --- | --- | --- |
| `harmonia-kali` | i3 | 4 GiB / 4 / 60 GB | `127.0.0.1:5900` |
| `harmonia-ubuntu` | GNOME (stock Ubuntu Desktop) | 6 GiB / 4 / 60 GB | `127.0.0.1:5901` |

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

## Firewall (enforced on the host)

Each VM's network is filtered by libvirt on the host, on the VM's virtual
network card ([`vms/firewall.nix`](../vms/firewall.nix)). Nothing inside the
guest, root included, can change it. Every policy also blocks MAC, IP and
ARP spoofing.

| Policy | The VM can reach |
| --- | --- |
| `open` | everything (the default) |
| `internet-only` | DHCP and DNS from the host, then the internet only: not the host, your LAN, other VMs or link-local addresses |
| `isolated` | nothing |

To switch a VM right away, even while it's running:

```sh
harmonia-vm-firewall                    # show each VM's policy
harmonia-vm-firewall kali isolated      # sandbox Kali now
harmonia-vm-firewall kali open          # and back
```

That lasts until the next boot or rebuild. To change the default, set
`firewall.policy` for the VM in `modules/nixos/vms.nix`. For finer control,
add raw [nwfilter](https://libvirt.org/formatnwfilter.html) rules in
`firewall.extraRules`. They are checked before the policy, so give them a
priority below 100 to win. For example, to let an internet-only Kali reach
one LAN host:

```nix
firewall = {
  policy = "internet-only";
  extraRules = ''
    <rule action="accept" direction="out" priority="50"><tcp dstipaddr="192.168.1.20" dstportstart="443" dstportend="443"/></rule>
  '';
};
```

The Kali shared folder (`~/shared`) is virtiofs, not networking, so the
firewall doesn't affect it.

The Kali i3 config ([`vms/kali-i3.nix`](../vms/kali-i3.nix)) uses **Alt** as its
modifier with vim directions (`Alt+h/j/k/l` focus, `Alt+Shift+h/j/k/l` move,
`Alt+Return` terminal, `Alt+d` rofi, `Alt+q` close, `Alt+1…0` workspaces,
`Alt+r` resize mode, `Alt+Shift+e` system mode). Super stays with the host's
sway, and neovim never binds Alt, so nothing overlaps.
