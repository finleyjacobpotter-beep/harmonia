# Repository layout

Where everything lives. Every module starts with a comment saying what it
does and how to use it, so the source is the next stop after these pages.

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
  flatpak.nix                  Flathub, `harmonia.apps` (each app's sandbox and Super+o key), `harmonia.launchers` (native apps' keys), Firefox with a tightened sandbox
  gaming.nix                   Lutris from Flathub with a tightened sandbox, controller udev rules, GameMode
  steam.nix                    Steam from Flathub, locked down, sharing only ~/Games with Lutris
  element.nix                  Element (Matrix) from Flathub with a locked-down sandbox
  studio.nix                   Blender and Godot from nixpkgs, with their Super+o keys
  fans.nix                     harmonia only: LACT daemon + Flatpak GUI for the AMD GPU fan curve, amdgpu overdrive, lm_sensors, rocm-smi
  llama-server.nix             harmonia only: Ornith 1.5 9B (Q4_K_M, MTP) as `ai` on llama.cpp's server in a podman container, Vulkan on the GPU, port 1235
  podman.nix                   rootless podman, podman-compose, buildah (all hosts)
  virtualisation.nix           plain QEMU (no libvirt)
  microvms.nix                 `harmonia.microvms`: each VM declared once; its network, NAT, folders, `ssh <vm>`, colours and firewall modes follow
  nike.nix                     the Nike microVM: its colours and VPN firewall modes
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
home/                          home-manager, one file per program
  base.nix                     the home every host shares; default.nix (harmonia, cadmus) and dionysus/ add to it
  sway.nix                     sway, fuzzel launcher, mako, swaylock, swayidle
  eww.nix                      eww bar (workspaces, title, caps/num lock, gamemode/steam/local model, nike with firewall modes, display settings, cpu, mem, gpu, network with VPN asterisks, caffeine, volume, battery, clock + calendar)
  eww/                         the bar's layout (eww.yuck), styles (eww.scss) and scripts, in Python (displays, network, gpu, volume, clock, calendar, …, sharing common.py), and the display settings window
  open-mode.nix                Super+o's keys, for sway and the bar's hint
  keymap.nix                   build-time checks for the keyboard contract
  tui.nix                      btop, pulsemixer, bluetuith
  secrets.nix                  keepassxc-cli, bw, ssh-agent, gpg, ykman, bao
  secrets-backup.py            the `secrets-backup` command
  flatpak-files.nix            `flatpak-miami-wind`: copies themes, configs and add-ons into flatpak sandboxes (flatpak-files.py)
  flatpak-theme.nix            the desktop GTK theme for the Lutris and LACT sandboxes
  element.nix                  Miami Wind theme for Element
  gamedev.nix                  AI agents and game dev on the harmonia desktop: omo (oh-my-openagent, native) on the local model and Claude Code, no global prompts, Blender, Godot and radare2 MCP, the godot-ai service, the skills
  gamedev/                     its skills (Godot 4, Godot and Blender MCP) and the design-doc templates gamedev-init copies
  skills/                      Rust tool skills for Claude Code and omo on harmonia (rg/fd/ast-grep, sd/jaq/difft, tokei/hyperfine/xh …)
  rust-tools.nix               Rust CLI tools (rg, fd, bat, eza, …) and the classic-command aliases, on the host and Nike
  blender-addons.nix           Blender add-ons: MCP for Blender, Poly Haven, Poly Pizza (blender/poly_pizza.py)
  mcp-servers.nix              the Blender, Godot and radare2 MCP servers for Claude Code and omo on harmonia (home/gamedev.nix)
  alacritty.nix tmux.nix bash.nix ranger.nix neovim.nix gtk.nix firefox.nix
lib/python-script.nix          packages a Python script as a command (flake8-checked, deps on PATH)
lib/python-app.nix             packages a folder of Python scripts that share modules as several commands (the bar)
lib/root-cas.nix               trusts the root CAs in certs/ on the host and Nike
lib/microvm-guest.nix          what every microVM guest shares: network, shares, volumes, user, openssh, status service, shell configs
certs/                         your own root CAs: all/ for every machine, harmonia/ or nike/ for one (empty by default, see certs/README.md)
pkgs/tulasi-icon-theme.nix     Tulasi icon theme (not in nixpkgs) with Tulasi-only fallbacks
pkgs/omo.nix                   omo, oh-my-openagent's native agent: the pinned release binary, patched for NixOS
assets/wallpaper.png           the wallpaper, pre-recoloured to Miami Wind
docs/                          these pages
mkdocs.yml                     the documentation site: theme, navigation (`nix build .#docs`)
scripts/mkdocs-hooks.py        points the docs' links to repository files at GitHub
scripts/install.py             base NixOS install from the minimal ISO (docs/install.md)
scripts/cleanup-deprecated.py  `sudo harmonia-cleanup`: removes what older harmonia versions left behind (Zen, libvirt VMs, the Zelus microVM, ...)
```
