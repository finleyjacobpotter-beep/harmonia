# harmonia

*Named for Harmonia, goddess of harmony and concord: one palette, one font and one
icon theme, shared by every program on the desktop.*

NixOS flake: **sway** + **eww** bar, **alacritty**, **tmux**, **bash**, **ranger**,
**neovim**, two **microVMs** (Nike and Zelus), **podman**, and **Zen browser**, **Lutris**, **Steam**, **Element**, **LM Studio**, **Blender** and **Godot** jailed in Flatpak —
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
  steam.nix                    Steam from Flathub, locked down, sharing only ~/Games with Lutris
  element.nix                  Element (Matrix) from Flathub with a locked-down sandbox
  lmstudio.nix                 LM Studio from Flathub with a locked-down sandbox and GPU inference
  studio.nix                   Blender and Godot from Flathub, sharing only ~/Projects
  fans.nix                     LACT daemon + Flatpak GUI for the AMD GPU fan curve, amdgpu overdrive, lm_sensors, rocm-smi
  virtualisation.nix           rootless podman + buildah, plain QEMU (no libvirt)
  nike.nix                     the Nike microVM, host side: tap network + NAT, shared folders, `ssh nike`
  zelus.nix                    the Zelus microVM, host side: tap network + NAT, shared folders, LM Studio socket, `ssh zelus` with the Blender/Godot forwards
  vm-firewall.nix              per-VM firewall modes (nftables on the host) and the `vm-firewall` command
  secrets.nix                  pcscd + YubiKey udev rules
  wireguard.nix                WireGuard via NetworkManager, sudo rule for the bar
nike/                          the Nike microVM guest (microvm.nix)
  default.nix                  packages, user k, network, shares and volumes, home-manager
  palette.nix                  Miami Wind with orange as the primary colour
  status.py                    writes Nike's VPN and utilization for the bar
zelus/                         the Zelus microVM guest (microvm.nix): Claude Code and opencode with Blender and Godot MCP
  default.nix                  packages, user c, network, shares and volumes, home-manager, Claude Code, status service
  palette.nix                  Miami Wind with cyan as the primary colour
  rust-tools.nix               Rust CLI tools, the classic-command aliases, agent skills
  skills/                      skills for Claude Code and opencode (rg/fd/ast-grep, sd/jaq/difft, tokei/hyperfine/xh …)
home/                          home-manager, one file per program
  sway.nix                     sway, fuzzel launcher, mako, swaylock, swayidle
  eww.nix                      eww bar (workspaces, title, caps/num lock, gamemode/steam/lm studio, nike/zelus with firewall modes, display settings, cpu, mem, gpu, network, wireguard, caffeine, volume, battery, clock + calendar)
  eww/                         the bar's scripts, in Python (displays, network, gpu, volume, clock, calendar, …), and the display settings window
  keymap.nix                   build-time checks for the keyboard contract
  tui.nix                      btop, pulsemixer, bluetuith
  secrets.nix                  gpg, gpg-agent, pass, ykman, bw, bao
  secrets-backup.py            the `secrets-backup` command
  flatpak-theme.nix            the desktop GTK theme copied into the Lutris and LACT sandboxes
  element.nix                  Miami Wind theme for Element
  opencode.nix                 opencode on Zelus: LM Studio + Claude providers, oh-my-openagent, Blender and Godot MCP servers
  mcp-servers.nix              the Blender and Godot MCP servers, for Claude Code and opencode on Zelus
  alacritty.nix tmux.nix bash.nix ranger.nix neovim.nix gtk.nix zen.nix
lib/python-script.nix          packages a Python script as a command (flake8-checked, deps on PATH)
pkgs/tulasi-icon-theme.nix     Tulasi icon theme (not in nixpkgs) with Tulasi-only fallbacks
assets/wallpaper.png           the wallpaper, pre-recoloured to Miami Wind
docs/                          the rest of the documentation (linked below)
scripts/install.py             base NixOS install from the minimal ISO (docs/install.md)
scripts/ubuntu-install.py      Ubuntu: Blender + Blender MCP, Godot 4 + Godot MCP, Tau, Caffeine
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

[`scripts/ubuntu-install.py`](scripts/ubuntu-install.py) is separate from the
NixOS setup: on an Ubuntu GNOME desktop it installs Blender with
[Blender MCP](https://github.com/ahujasid/blender-mcp), Godot 4 with
[Godot MCP](https://github.com/Coding-Solo/godot-mcp), Hugging Face's
[Tau](https://github.com/huggingface/tau) coding agent (via pipx), and the
[Caffeine](https://extensions.gnome.org/extension/517/caffeine/) extension.
Run it as your normal user: `python3 scripts/ubuntu-install.py`.

## Documentation

- [Installing base NixOS](docs/install.md): the base system harmonia installs onto
- [Pinned versions](docs/versions.md): exact commits and package versions
- [Keyboard](docs/keyboard.md): the modifier contract and every binding
- [Zen browser jail](docs/zen.md): the Flatpak sandbox and its theming
- [Gaming](docs/gaming.md): Lutris and Steam in Flatpak jails, launching Steam games from Lutris, drivers
- [Element](docs/element.md): the Matrix client's Flatpak jail and theme
- [LM Studio](docs/lmstudio.md): local LLMs in a Flatpak jail, on the GPU
- [opencode](docs/opencode.md): opencode on Zelus, providers, the Anthropic key, and the Blender and Godot MCP servers
- [Fans](docs/fans.md): the GPU fan curve in LACT, case fans in the BIOS
- [Nike and containers](docs/nike.md): the Nike microVM (VPN work, firewall modes, shared folder, bar panel), podman
- [Zelus](docs/zelus.md): the Zelus microVM (Claude Code, opencode, dev tools, Blender and Godot over MCP, firewall modes)
- [The bar](docs/bar.md): what each part of the eww bar shows, its panels, and the display settings window
- [Calendar](docs/calendar.md): the clock's calendar, time zones and CalDAV sync with vdirsyncer
- [WireGuard](docs/wireguard.md): importing tunnels and the bar panel
- [Secrets](docs/secrets.md): gpg, pass, YubiKey, Bitwarden, OpenBao and `secrets-backup`
- [Theme](docs/theme.md): Miami Wind colours, Tulasi icons, the wallpaper

## Unfree packages

Only one non-free package is allowed (`hosts/harmonia/default.nix`):
the Tulasi icon theme (CC BY-NC-SA 4.0, free for non-commercial use with
attribution).

Steam and LM Studio are proprietary too, but they come from Flathub rather
than nixpkgs, so they need no entry there.

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
  Flatpak setup for Zen, Lutris, Steam, Element, LM Studio, Blender and
  Godot.
- **[microvm.nix](https://github.com/microvm-nix/microvm.nix)**: the Nike
  and Zelus microVMs.

## License

The configuration in this repository is [MIT](LICENSE) licensed. That covers
the Nix code and scripts only: the projects above keep their own licenses.
In particular the Tulasi icons are CC BY-NC-SA 4.0 (non-commercial use with
attribution), and the wallpaper artwork belongs to its artist and is not
covered by this repository's license.
