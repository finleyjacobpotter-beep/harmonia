# harmonia

*Named for Harmonia, goddess of harmony and concord: one palette, one font and
one icon theme, shared by every program on the desktop.*

harmonia is a [NixOS flake](https://nixos.wiki/wiki/Flakes) with
[home-manager](https://github.com/nix-community/home-manager) that builds a
whole Wayland desktop: **Sway**, an **eww** bar, **alacritty**, **tmux**,
**bash**, **ranger** and **neovim**, with sandboxed Flatpak apps and microVMs
for risky or agent-driven work. Everything is themed with the
[Miami Wind](https://marketplace.visualstudio.com/items?itemName=hanakin.miami-wind)
colour scheme, the **DepartureMono Nerd Font** and the pixel-art
[Tulasi](https://github.com/ShringarStudio/Tulasi) icon theme.

One repository builds several machines. They share most of their
configuration and differ only where the hardware or the job demands it.

## Environments

| Environment | What it is | Flake output | User |
| --- | --- | --- | --- |
| [harmonia](harmonia.md) | The desktop (AMD GPU) | `.#harmonia` | `u` |
| [cadmus](cadmus.md) | The laptop, a Lenovo ThinkPad E14 Gen 2 | `.#cadmus` | `u` |
| [Dionysus](dionysus.md) | The same desktop for a VM, dev tools native, no microVMs, x86_64 and aarch64 | `.#dionysus`, `.#dionysus-aarch64` | `d` |
| [Nike](nike.md) | MicroVM on harmonia and cadmus for VPN work and OSCP practice | built with the host | `k` |
| [Zelus](zelus.md) | MicroVM on harmonia and cadmus for coding agents (Claude Code, opencode) | built with the host | `c` |

[What every environment shares](common.md) covers the common base; each
environment's page covers only what is unique to it.
[Comparing environments](compare.md) puts them side by side.

!!! note "In flight"
    These pages describe `main`. Open pull requests will change some details
    when they merge: Blender and Godot moving from Flathub to nixpkgs,
    KeePassXC and Bitwarden replacing gpg-agent and pass, a llama.cpp model
    server on harmonia, Nike's OSCP toolset on Dionysus, and two servers
    (proteus and atlas) deployed with nixos-anywhere.

## How it is put together

Configuration is layered, so each machine imports only what it needs:

```
hosts/base.nix         every host: boot, network, user, locale, nix settings,
                       Sway desktop, fonts, Firefox, Element, podman, secrets, VPNs
 └ hosts/common.nix    harmonia + cadmus: gaming, Steam, LM Studio, Blender/Godot,
                       QEMU and the Nike and Zelus microVMs
    ├ hosts/harmonia   the desktop: GPU fan control, game dev agents
    └ hosts/cadmus     the laptop: Wi-Fi, lid, power profiles, ThinkPad fans
 └ hosts/dionysus      a VM: guest tools, native dev tools, both architectures

lib/microvm-guest.nix  every microVM: network, shares, volumes, user, ssh, shell configs
 ├ nike/               OSCP toolset and lab containers
 └ zelus/              Claude Code, opencode, Blender/Godot MCP
```

The home side mirrors it: `home/base.nix` is the home every host shares,
`home/default.nix` adds to it for harmonia and cadmus, and
`home/dionysus/` for Dionysus. The microVM guests reuse the host's bash, tmux,
ranger, neovim and Rust tools in their own colours.

`flake.nix` builds each host with one `mkHost` function; see
[Repository layout](layout.md) for where everything lives.

## Getting started

Start from a base NixOS install ([Installing base NixOS](install.md)), then:

```sh
git clone https://github.com/finleyjacobpotter-beep/harmonia ~/harmonia && cd ~/harmonia
sudo nixos-generate-config --show-hardware-config > hosts/harmonia/hardware-configuration.nix
sudo nixos-rebuild switch --flake .#harmonia
```

Use `cadmus` or `dionysus` in place of `harmonia` for the other machines.
Change `defaultUsername` in `flake.nix` and the time zone, locale and keymap
in `hosts/base.nix` first if the defaults (`u`, UTC, `en_US.UTF-8`, US) don't
suit you. After the first switch, `rebuild` does the same.

## Building these docs

```sh
nix develop .#docs        # a shell with mkdocs-material
mkdocs serve              # live preview on http://127.0.0.1:8000
nix build .#docs          # the static site in ./result
```

## Acknowledgements and license

harmonia stands on other people's work: Nix flakes and nixpkgs,
home-manager, Miami Wind by hanakin, the Tulasi icons by Shringar Studio, the
wallpaper art by Park Junkyu ([gharliera](https://www.artstation.com/gharliera)),
Departure Mono via Nerd Fonts, nix-flatpak, microvm.nix, Poly Haven and Poly
Pizza. The [README](../README.md) credits each one with links.

The configuration is [MIT](../LICENSE) licensed. That covers the Nix code and
scripts only: the Tulasi icons are CC BY-NC-SA 4.0, and the wallpaper artwork
belongs to its artist.
