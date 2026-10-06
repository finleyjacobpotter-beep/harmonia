# harmonia

*Named for Harmonia, goddess of harmony and concord: one palette, one font and one
icon theme, shared by every program on the desktop.*

NixOS flake: **sway** + **eww** bar, **alacritty**, **tmux**, **bash**, **ranger**,
**neovim**, two **microVMs** (Nike and Zelus), **podman**, and **Firefox** (vertical tabs, uBlock Origin, Vimium), **Lutris**, **Steam**, **Element**, **LM Studio**, **Blender** and **Godot** jailed in Flatpak —
all using the [Miami Wind](https://marketplace.visualstudio.com/items?itemName=hanakin.miami-wind)
colour scheme, **DepartureMono Nerd Font** and the pixel-art
[**Tulasi**](https://github.com/ShringarStudio/Tulasi) icon theme.

## Layout

```
flake.nix                      inputs, defaultUsername, mkHost and the hosts (harmonia, cadmus, dionysus, dionysus-aarch64)
theme/miami-wind.nix           the palette — every app reads its colours from here
keys.nix                       the keyboard contract (which layer owns which modifier)
hosts/base.nix                 what every host shares: desktop modules, user, locale, nix settings
hosts/common.nix               base.nix plus the apps and microVMs harmonia and cadmus share
hosts/harmonia/                the desktop: hardware-configuration.nix (placeholder!) + fans.nix
hosts/cadmus/                  the laptop (ThinkPad E14 Gen 2): hardware-configuration.nix (placeholder!), laptop.nix, thinkpad.nix,
                               nixos-hardware's E14 Gen 2 profile (set `cpu` to intel or amd)
modules/nixos/
  desktop.nix                  sway, greetd/tuigreet, pipewire, portals, console colours
  fonts.nix                    DepartureMono Nerd Font as system default
  flatpak.nix                  Flathub, `harmonia.apps` (each app's sandbox and Super+o key), Firefox with a tightened sandbox
  gaming.nix                   Lutris from Flathub with a tightened sandbox, controller udev rules, GameMode
  steam.nix                    Steam from Flathub, locked down, sharing only ~/Games with Lutris
  element.nix                  Element (Matrix) from Flathub with a locked-down sandbox
  lmstudio.nix                 LM Studio from Flathub with a locked-down sandbox and GPU inference
  studio.nix                   Blender and Godot from Flathub, sharing only ~/Projects (and the network)
  fans.nix                     harmonia only: LACT daemon + Flatpak GUI for the AMD GPU fan curve, amdgpu overdrive, lm_sensors, rocm-smi
  podman.nix                   rootless podman, podman-compose, buildah (all hosts)
  virtualisation.nix           plain QEMU (no libvirt)
  microvms.nix                 `harmonia.microvms`: each VM declared once; its network, NAT, folders, `ssh <vm>`, colours and firewall modes follow
  nike.nix                     the Nike microVM: its colours and VPN firewall modes
  zelus.nix                    the Zelus microVM: its colours, ~/Projects, firewall modes, the LM Studio and Blender sockets, the Godot MCP server
  vm-firewall.nix              per-VM firewall modes (nftables on the host) and the `vm-firewall` command
  laptop.nix                   cadmus only: Wi-Fi firmware + regulatory database, suspend on lid close, power profiles
  thinkpad.nix                 cadmus only: thinkfan fan curve, fwupd for BIOS updates
  secrets.nix                  pcscd + YubiKey udev rules
  vpn.nix                      WireGuard and OpenVPN via NetworkManager, openfortivpn services, rules for the bar
nike/                          the Nike microVM guest (microvm.nix)
  default.nix                  packages, user k and its password, volume sizes, the TUN module
  tools.nix                    the OSCP toolset and Penelope
  labs.nix                     podman + the Ligolo-ng and BloodHound compose services
  status.py                    writes each VM's utilization (and Nike's VPN) for the bar
zelus/                         the Zelus microVM guest (microvm.nix): Claude Code and opencode with Blender and Godot MCP
  default.nix                  packages, passwordless user c, the ~/Projects share, opencode, Claude Code
  skills/                      skills for Claude Code and opencode (rg/fd/ast-grep, sd/jaq/difft, tokei/hyperfine/xh …)
home/                          home-manager, one file per program
  base.nix                     the home every host shares; default.nix (harmonia, cadmus) and dionysus/ add to it
  sway.nix                     sway, fuzzel launcher, mako, swaylock, swayidle
  eww.nix                      eww bar (workspaces, title, caps/num lock, gamemode/steam/lm studio, nike/zelus with firewall modes, display settings, cpu, mem, gpu, network with VPN asterisks, caffeine, volume, battery, clock + calendar)
  eww/                         the bar's layout (eww.yuck), styles (eww.scss) and scripts, in Python (displays, network, gpu, volume, clock, calendar, …, sharing common.py), and the display settings window
  open-mode.nix                Super+o's keys, for sway and the bar's hint
  keymap.nix                   build-time checks for the keyboard contract
  tui.nix                      btop, pulsemixer, bluetuith
  secrets.nix                  gpg, gpg-agent, pass, ykman, bw, bao
  secrets-backup.py            the `secrets-backup` command
  flatpak-files.nix            `flatpak-miami-wind`: copies themes, configs and add-ons into flatpak sandboxes (flatpak-files.py)
  flatpak-theme.nix            the desktop GTK theme for the Lutris and LACT sandboxes
  element.nix                  Miami Wind theme for Element
  opencode.nix                 opencode on Zelus: LM Studio + Claude providers, oh-my-openagent, Blender and Godot MCP servers
  rust-tools.nix               Rust CLI tools (rg, fd, bat, eza, …) and the classic-command aliases, on the host, Nike and Zelus
  blender-addons.nix           Blender add-ons in the Flatpak: MCP for Blender, Poly Haven, Poly Pizza (blender/poly_pizza.py)
  mcp-servers.nix              the Blender and Godot MCP servers (Godot's runs on the host), for Claude Code and opencode on Zelus
  alacritty.nix tmux.nix bash.nix ranger.nix neovim.nix gtk.nix firefox.nix
lib/python-script.nix          packages a Python script as a command (flake8-checked, deps on PATH)
lib/python-app.nix             packages a folder of Python scripts that share modules as several commands (the bar)
lib/root-cas.nix               trusts the root CAs in certs/ on the host, Nike and Zelus
lib/microvm-guest.nix          what every microVM guest shares: network, shares, volumes, user, openssh, status service, shell configs
certs/                         your own root CAs: all/ for every machine, harmonia/, nike/ or zelus/ for one (empty by default, see certs/README.md)
pkgs/tulasi-icon-theme.nix     Tulasi icon theme (not in nixpkgs) with Tulasi-only fallbacks
assets/wallpaper.png           the wallpaper, pre-recoloured to Miami Wind
docs/                          the rest of the documentation (linked below)
scripts/install.py             base NixOS install from the minimal ISO (docs/install.md)
scripts/cleanup-deprecated.py  `sudo harmonia-cleanup`: removes what older harmonia versions left behind (Zen, libvirt VMs, ...)
```

## Install

There are two hosts with the same desktop, apps and microVMs: **harmonia**
for a desktop and **cadmus** for a Lenovo ThinkPad E14 Gen 2, which adds
Wi-Fi firmware, suspend on lid close and power profiles
(`modules/nixos/laptop.nix`), a thinkfan fan curve and fwupd
(`modules/nixos/thinkpad.nix`) and nixos-hardware's E14 Gen 2 profile. Set
`cpu` in `hosts/cadmus/default.nix` to `intel` or `amd` to match yours. Below, use `cadmus` in place of `harmonia` for a
laptop. On cadmus, Super+o n opens `nmtui` to join a Wi-Fi network.

Start from a base NixOS install with flakes and git enabled and a user named
`u` (or whatever you set as `defaultUsername`). [Installing base NixOS](docs/install.md)
walks through that from the minimal ISO: UEFI, systemd-boot, optional LUKS;
[`scripts/install.py`](scripts/install.py) does it for you.

**dionysus** is the third host: the same Sway desktop for a VM, with the dev
tools (Claude Code, opencode, the Rust tools) built in, no microVMs and its
own user `d`. Its flake output is `.#dionysus` on x86_64 and
`.#dionysus-aarch64` on aarch64; `scripts/install.py` offers it and picks
the right one for the machine.

1. Clone this repo and edit `defaultUsername` in `flake.nix`, and the
   timezone/locale/keymap in `hosts/base.nix`:
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

## Documentation

- [Installing base NixOS](docs/install.md): the base system harmonia installs onto
- [Pinned versions](docs/versions.md): exact commits and package versions
- [Keyboard](docs/keyboard.md): the modifier contract and every binding
- [Firefox jail](docs/firefox.md): the Flatpak sandbox, add-ons and theming
- [Gaming](docs/gaming.md): Lutris and Steam in Flatpak jails, launching Steam games from Lutris, drivers
- [Element](docs/element.md): the Matrix client's Flatpak jail and theme
- [LM Studio](docs/lmstudio.md): local LLMs in a Flatpak jail, on the GPU
- [Blender](docs/blender.md): free models from Poly Haven and Poly Pizza inside Blender
- [opencode](docs/opencode.md): opencode on Zelus, providers, the Anthropic key, and the Blender and Godot MCP servers
- [Fans](docs/fans.md): the GPU fan curve in LACT, case fans in the BIOS
- [Nike and containers](docs/nike.md): the Nike microVM (VPN work, OSCP lab, firewall modes, shared folder, bar panel), podman
- [Rust tools](docs/rust-tools.md): ripgrep, fd, bat, eza and friends, and the aliases from grep, find, cat, ls … on every machine
- [Zelus](docs/zelus.md): the Zelus microVM (Claude Code, opencode, dev tools, Blender and Godot over MCP, firewall modes)
- [The bar](docs/bar.md): what each part of the eww bar shows, its panels, and the display settings window
- [Calendar](docs/calendar.md): the clock's calendar, time zones and CalDAV sync with vdirsyncer
- [VPNs](docs/vpn.md): WireGuard, OpenVPN and openfortivpn, and their asterisks on the bar
- [Secrets](docs/secrets.md): gpg, pass, YubiKey, Bitwarden, OpenBao and `secrets-backup`
- [Theme](docs/theme.md): Miami Wind colours, Tulasi icons, the wallpaper
- [Editing](docs/editing.md): the system-wide EditorConfig and Neovim's JSON/YAML commands

## Unfree packages

Only one non-free package is allowed (`harmonia.allowedUnfree` in `hosts/base.nix`):
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
  Flatpak setup for Firefox, Lutris, Steam, Element, LM Studio, Blender and
  Godot.
- **[microvm.nix](https://github.com/microvm-nix/microvm.nix)**: the Nike
  and Zelus microVMs.
- **[Poly Haven](https://polyhaven.com/)** ([add-on](https://github.com/Poly-Haven/polyhavenassets), GPL-3.0)
  and **[Poly Pizza](https://poly.pizza/)**: free models inside Blender.

## License

The configuration in this repository is [MIT](LICENSE) licensed. That covers
the Nix code and scripts only: the projects above keep their own licenses.
In particular the Tulasi icons are CC BY-NC-SA 4.0 (non-commercial use with
attribution), and the wallpaper artwork belongs to its artist and is not
covered by this repository's license.
