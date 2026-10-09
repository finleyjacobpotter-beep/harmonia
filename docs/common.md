# What every environment shares

Most of harmonia is common to every machine. This page lists what comes from
the shared layers; each environment's own page lists only what it adds or
leaves out.

## Every host: `hosts/base.nix`

harmonia, cadmus and Dionysus all import [`hosts/base.nix`](../hosts/base.nix).

**System**

- systemd-boot (UEFI) and the latest kernel (`linuxPackages_latest`).
- NetworkManager for networking, Bluetooth on.
- Time zone UTC, locale `en_US.UTF-8`, US keymap. Change these here.
- One user (`u` by default, `d` on Dionysus) in `wheel`, `networkmanager`,
  `video` and `audio`, with bash and the initial password `changeme`.
- Nix with flakes, the store optimised, and garbage collection weekly
  (older than 14 days).
- Base CLI tools: git, curl, wget, jq, ripgrep, fd, unzip, htop, and
  `sudo harmonia-cleanup`, which removes what older harmonia versions left
  behind (such as the removed Zelus microVM,
  [omo.md](omo.md#coming-from-zelus)).
- Only one unfree package is allowed by default: the Tulasi icon theme
  (`harmonia.allowedUnfree`). A host can add its own to the list.

**Modules** (in [`modules/nixos/`](../modules/nixos))

| Module | What it does |
| --- | --- |
| `desktop.nix` | Sway, greetd/tuigreet login, PipeWire audio, portals, Bluetooth, console colours |
| `fonts.nix` | DepartureMono Nerd Font as the system default |
| `flatpak.nix` | Flathub, the `harmonia.apps` list (each app's sandbox and Super+o key), `harmonia.launchers` (Super+o keys for native programs), [Firefox](firefox.md) in a tightened sandbox |
| `element.nix` | [Element](element.md) (Matrix) from Flathub in a locked-down sandbox |
| `podman.nix` | Rootless podman, podman-compose and buildah |
| `git-lfs.nix` | Git with LFS |
| `editorconfig.nix` | A system-wide `/.editorconfig` ([Editing](editing.md)) |
| `sudo.nix` | Asterisks at the sudo password prompt |
| `secrets.nix` | pcscd and YubiKey udev rules ([Secrets](secrets.md)) |
| `vpn.nix` | WireGuard, OpenVPN and openfortivpn without root ([VPNs](vpn.md)) |

## Every home: `home/base.nix`

Every host's user gets [`home/base.nix`](../home/base.nix), one home-manager
file per program:

- **Desktop**: Sway with the fuzzel launcher, mako notifications, swaylock and
  swayidle; the [eww bar](bar.md); GTK theming; the
  [keyboard contract](keyboard.md) and its build-time checks.
- **Terminal**: alacritty, tmux, bash and its prompt, ranger, neovim
  (with the [JSON/YAML commands](editing.md)), btop, pulsemixer and bluetuith.
- **Apps**: Firefox's add-ons and theme, Element's theme, Calibre, and
  `flatpak-miami-wind`, which copies themes and configs into the Flatpak
  sandboxes.
- **Secrets**: KeePassXC (`keepassxc-cli` and the app), the Bitwarden CLI
  with `bw-unlock`, OpenSSH's ssh-agent, gpg, ykman, the OpenBao CLI and
  `secrets-backup` ([Secrets](secrets.md)).
- The XDG user directories and `~/Projects`, and a `rebuild` alias for
  `sudo nixos-rebuild switch --flake ~/harmonia`.

## The look

Every environment, microVMs included, uses the same
[theme](theme.md): the Miami Wind palette from
[`theme/miami-wind.nix`](../theme/miami-wind.nix), DepartureMono Nerd Font
and the Tulasi icons. The hosts use pink as the primary colour; Nike swaps it
for orange, so you can tell at a glance which machine a terminal belongs
to.

## Desktop and laptop: `hosts/common.nix`

harmonia and cadmus also import [`hosts/common.nix`](../hosts/common.nix) and
[`home/default.nix`](../home/default.nix). Dionysus does not.

| Piece | What it adds |
| --- | --- |
| `gaming.nix`, `steam.nix` | [Lutris and Steam](gaming.md) from Flathub in jails sharing only `~/Games`, controller rules, GameMode |
| `studio.nix` | Blender and Godot from nixpkgs, opened with Super+o Shift+b and Super+o d, working in `~/Projects` |
| `virtualisation.nix` | Plain QEMU (no libvirt) and `/dev/kvm` access |
| `microvms.nix`, `vm-firewall.nix` | The `harmonia.microvms` option and per-VM firewall modes switched from the bar |
| `nike.nix` | The [Nike](nike.md) microVM |
| `lib/root-cas.nix` | Your own root CAs from `certs/all` and `certs/<hostname>` |
| `home/default.nix` | The Flatpak GTK theme sync, the [Rust tools](rust-tools.md), [Blender add-ons](blender.md) and `uv` |

## Every microVM: `lib/microvm-guest.nix`

Every microVM (only Nike now) uses [`lib/microvm-guest.nix`](../lib/microvm-guest.nix):

- A tap interface with a `/32` route each way (`10.20.<n>.1` on the host,
  `10.20.<n>.2` in the guest), so nothing else on your LAN can reach them,
  and NAT out through whatever the host uses.
- The host's `/nix/store` read-only, a tmpfs root, and persistent `/home` and
  `/var` volumes under `/var/lib/microvms/<name>`.
- `~/<name>-share` on the host is `~/share` in the guest.
- One user (uid 1000, so shared files belong to you on both sides), openssh,
  and `ssh <name>` from the host.
- A status service the host's bar reads for its badge and panel.
- The host's bash, tmux, ranger, neovim, Rust tools, EditorConfig, sudo and
  Git LFS settings, in the VM's own colours, and the root CAs from
  `certs/all` and `certs/<name>`.

None of them starts at boot: use the bar's panel or
`sudo systemctl start microvm@<name>`.
