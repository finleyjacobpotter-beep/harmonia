# harmonia

*Named for Harmonia, goddess of harmony and concord: one palette, one font and one
icon theme, shared by every program on the desktop.*

NixOS flake: **sway** + **eww** bar, **alacritty**, **tmux**, **bash**, **ranger**,
**neovim**, **libvirt**, **podman**, and **Zen browser**, **Lutris**, **Element** and **LM Studio** jailed in Flatpak —
all using the [Miami Wind](https://marketplace.visualstudio.com/items?itemName=hanakin.miami-wind)
colour scheme, **DepartureMono Nerd Font** and the pixel-art
[**Tulasi**](https://github.com/ShringarStudio/Tulasi) icon theme.

## Layout

```
flake.nix                      inputs, hostname/username, nixosConfigurations.harmonia
theme/miami-wind.nix           the palette — every app reads its colours from here
keys.nix                       the keyboard contract (which layer owns which modifier)
hosts/harmonia/                host config + hardware-configuration.nix (placeholder!)
modules/nixos/
  desktop.nix                  sway, greetd/tuigreet, pipewire, portals, console colours
  fonts.nix                    DepartureMono Nerd Font as system default
  flatpak.nix                  Flathub + Zen browser with a tightened sandbox
  gaming.nix                   Lutris from Flathub with a tightened sandbox, controller udev rules, GameMode
  element.nix                  Element (Matrix) from Flathub with a locked-down sandbox
  lmstudio.nix                 LM Studio from Flathub with a locked-down sandbox and GPU inference
  virtualisation.nix           libvirtd/KVM, virt-manager, rootless podman + buildah
  vms.nix                      Kali (i3) and Ubuntu (GNOME) libvirt VMs, virtio GPU
  secrets.nix                  pcscd + YubiKey udev rules
  wireguard.nix                WireGuard via NetworkManager, sudo rule for the bar
vms/kali-i3.nix                i3, i3status and caffeine bar for the Kali VM (Alt modifier)
vms/firewall.nix               host-enforced VM firewall policies (libvirt nwfilter)
home/                          home-manager, one file per program
  sway.nix                     sway, fuzzel launcher, mako, swaylock, swayidle
  eww.nix                      eww bar (workspaces, title, caps/num lock, cpu, mem, wireguard, caffeine, volume, battery, clock)
  keymap.nix                   build-time checks for the keyboard contract
  tui.nix                      btop, pulsemixer, bluetuith
  secrets.nix                  gpg, gpg-agent, pass, ykman, bw, bao
  secrets-backup.sh            the `secrets-backup` command
  lutris.nix element.nix       Miami Wind inside the Lutris and Element sandboxes
  alacritty.nix tmux.nix bash.nix ranger.nix neovim.nix gtk.nix zen.nix
pkgs/tulasi-icon-theme.nix     Tulasi icon theme (not in nixpkgs) with Tulasi-only fallbacks
assets/wallpaper.png           the wallpaper, pre-recoloured to Miami Wind
docs/                          the rest of the documentation (linked below)
scripts/install.py             base NixOS install from the minimal ISO (docs/install.md)
scripts/ubuntu-install.sh      Ubuntu: Blender + Blender MCP, Godot 4 + Godot MCP, Tau, Caffeine
```

## Install

Start from a base NixOS install with flakes and git enabled and a user named
`u` (or whatever you set as `username`). [Installing base NixOS](docs/install.md)
walks through that from the minimal ISO: UEFI, systemd-boot, optional LUKS;
[`scripts/install.py`](scripts/install.py) does it for you.

1. Clone this repo and edit `hostname` / `username` in `flake.nix`, and the
   timezone/locale/keymap in `hosts/harmonia/default.nix`:
   ```sh
   git clone https://github.com/finleyjacobpotter-beep/harmonia ~/harmonia && cd ~/harmonia
   ```
2. Replace the placeholder hardware config:
   ```sh
   sudo nixos-generate-config --show-hardware-config > hosts/harmonia/hardware-configuration.nix
   ```
3. Build and switch (this also creates `flake.lock` from the pinned inputs; see
   [Pinned versions](docs/versions.md)):
   ```sh
   sudo nixos-rebuild switch --flake .#harmonia
   ```
4. Reboot and log in at tuigreet. If your user already existed (as it does
   after the base install), use its existing password. The initial password
   `changeme` only applies when harmonia creates the user; in that case, run
   `passwd` straight away.

### Ubuntu

[`scripts/ubuntu-install.sh`](scripts/ubuntu-install.sh) is separate from the
NixOS setup: on an Ubuntu GNOME desktop it installs Blender with
[Blender MCP](https://github.com/ahujasid/blender-mcp), Godot 4 with
[Godot MCP](https://github.com/Coding-Solo/godot-mcp), Hugging Face's
[Tau](https://github.com/huggingface/tau) coding agent (via pipx), and the
[Caffeine](https://extensions.gnome.org/extension/517/caffeine/) extension.
Run it as your normal user: `bash scripts/ubuntu-install.sh`.

## Documentation

- [Installing base NixOS](docs/install.md): the base system harmonia installs onto
- [Pinned versions](docs/versions.md): exact commits and package versions
- [Keyboard](docs/keyboard.md): the modifier contract and every binding
- [Zen browser jail](docs/zen.md): the Flatpak sandbox and its theming
- [Gaming](docs/gaming.md): Lutris in a Flatpak jail, its theming, anti-cheat, controllers
- [Element](docs/element.md): the Matrix client's Flatpak jail and theme
- [LM Studio](docs/lmstudio.md): local LLMs in a Flatpak jail, on the GPU
- [VMs and containers](docs/vms-and-containers.md): libvirt, the Kali and Ubuntu VMs, their firewall, podman
- [WireGuard](docs/wireguard.md): importing tunnels and the bar panel
- [Secrets](docs/secrets.md): gpg, pass, YubiKey, Bitwarden, OpenBao and `secrets-backup`
- [Theme](docs/theme.md): Miami Wind colours, Tulasi icons, the wallpaper

## Unfree packages

Only one non-free package is allowed (`hosts/harmonia/default.nix`):
the Tulasi icon theme (CC BY-NC-SA 4.0, free for non-commercial use with
attribution).

LM Studio is proprietary too, but it comes from Flathub rather than nixpkgs,
so it needs no entry there.

## Acknowledgements

harmonia stands on other people's work:

- **[Nix flakes](https://nixos.wiki/wiki/Flakes)** and
  **[nixpkgs](https://github.com/NixOS/nixpkgs)**: the whole system is one
  reproducible flake.
- **[home-manager](https://github.com/nix-community/home-manager)**: every
  per-user program in `home/` is configured through it.
- **Miami Wind** by hanakin: the colour scheme, from the
  [VS Code theme](https://github.com/hanakin/miami-wind-vscode)
  ([marketplace](https://marketplace.visualstudio.com/items?itemName=hanakin.miami-wind))
  and its [canonical palette](https://github.com/hanakin/miami-wind/blob/main/palette.css).
- **[Tulasi](https://github.com/ShringarStudio/Tulasi)** by Shringar Studio:
  the pixel-art icon theme.
- **Wallpaper art** by Park Junkyu ([gharliera on ArtStation](https://www.artstation.com/gharliera)),
  [original image](https://cdna.artstation.com/p/assets/images/images/020/830/958/large/park-junkyu-kakaotalk-20190924-182145141111.jpg),
  recoloured here with the Miami Wind palette.
- **[Departure Mono](https://departuremono.com/)** via
  [Nerd Fonts](https://www.nerdfonts.com/): the font.
- **[nix-flatpak](https://github.com/gmodena/nix-flatpak)**: the declarative
  Flatpak setup for Zen, Lutris, Element and LM Studio.

## License

The configuration in this repository is [MIT](LICENSE) licensed. That covers
the Nix code and scripts only: the projects above keep their own licenses.
In particular the Tulasi icons are CC BY-NC-SA 4.0 (non-commercial use with
attribution), and the wallpaper artwork belongs to its artist and is not
covered by this repository's license.
