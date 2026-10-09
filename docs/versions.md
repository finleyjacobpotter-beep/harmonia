# Pinned versions

Every flake input is pinned to an exact commit in `flake.nix`, and every package
comes from the pinned nixpkgs, so a build always gets the versions below. They
only change when an input's commit is bumped; update this table when you do.

## Flake inputs

| Input | Pinned to |
| --- | --- |
| nixpkgs | [`e158d9e`](https://github.com/NixOS/nixpkgs/commit/e158d9ed9b51c98974c5e66e1ba1c9e0255fecaa) (nixos-unstable, 2026-09-27) |
| home-manager | [`7b4c5ec`](https://github.com/nix-community/home-manager/commit/7b4c5ec4bedaf1e062bbc1bcaeddbc6bd242aa1b) (master, 2026-09-27) |
| nix-flatpak | v0.7.0 ([`4408189`](https://github.com/gmodena/nix-flatpak/commit/440818969ac2cbd77bfe025e884d0aa528991374)) |
| microvm.nix | [`3f1540f`](https://github.com/microvm-nix/microvm.nix/commit/3f1540f254fe73ac907281b7de7d396bb3d54850) (main, 2026-10-01) |
| nixos-hardware | [`31cc5f4`](https://github.com/NixOS/nixos-hardware/commit/31cc5f4d9b9ba601071e8b8504601b9b176e2756) (master, 2026-10-04; cadmus only) |

## System

| Package | Version |
| --- | --- |
| Linux kernel (`linuxPackages_latest`) | 7.2.8 |
| systemd | 261.2 |
| bash | 5.3p15 |
| greetd / tuigreet | 0.10.3 / 0.11.1 |
| NetworkManager | 1.58.1 |
| wireguard-tools | 1.0.20260223 |
| OpenVPN / NetworkManager-openvpn | 2.6.23 / 1.12.5 |
| openfortivpn | 1.24.1 |
| PipeWire / WirePlumber | 1.6.8 / 0.5.17 |
| BlueZ / Blueman | 5.87 / 2.4.6 |
| UPower | 1.91.4 |
| Mesa (64- and 32-bit, radeonsi + RADV) | 26.2.3 |
| Vulkan loader / vulkan-tools | 1.4.357.0 / 1.4.357.0 |
| mesa-demos (`glxinfo`) | 9.0.0 |
| polkit | 127 |
| gnome-keyring | 50.0 |
| dconf | 0.49.0 |
| xdg-desktop-portal / -gtk / -wlr | 1.22.1 / 1.15.3 / 0.8.4 |
| Flatpak | 1.18.1 |
| git, curl, wget | 2.55.0, 8.22.0, 1.25.0 |
| jq, ripgrep, fd | 1.8.2, 15.2.0, 10.5.0 |
| unzip, htop | 6.0, 3.5.3 |

## Desktop

| Package | Version |
| --- | --- |
| Sway | 1.12 |
| swaylock / swayidle | 1.8.6 / 1.9.0 |
| eww | 0.6.0 (unstable 2026-07-17) |
| fuzzel | 1.15.0 |
| mako | 1.11.0 |
| wl-clipboard, grim, slurp | 2.3.0, 1.5.0, 1.5.0 |
| brightnessctl, playerctl, pavucontrol | 0.5.1, 2.4.1, 6.2 |
| gawk (eww scripts) | 5.4.1 |
| adw-gtk3 | 6.5 |
| Bibata cursors | 2.0.7 |
| hicolor-icon-theme | 0.18 |
| Tulasi icon theme | 0.3 (unstable 2026-09-16, [`b23e381`](https://github.com/ShringarStudio/Tulasi/commit/b23e3813dc2614c130a793cae3f594a45fd8959c)) |
| Departure Mono Nerd Font | Nerd Fonts 3.5.0 |
| Noto Color Emoji | 2.051 |

## Terminal and apps

| Package | Version |
| --- | --- |
| Alacritty | 0.17.0 |
| tmux (+ tmux-yank, unstable 2023-07-19) | 3.7c |
| Neovim | 0.12.5 |
| ranger | 1.9.4 (unstable 2026-09-09) |
| ranger_devicons | [`1bcaff0`](https://github.com/alexanderjeurissen/ranger_devicons/commit/1bcaff0366a9d345313dc5af14002cfdcddabb82) |
| ranger previews: file, highlight, atool, poppler-utils, mediainfo | 5.48, 4.21, 0.39.0, 26.06.0, 26.05 |
| btop | 1.4.7 |
| pulsemixer / bluetuith | 1.5.1 / 0.2.7 |
| fzf | 0.74.4 |
| Calibre | 9.14.0 |
| Blender (harmonia, cadmus) | 5.2.2 |
| Godot (harmonia, cadmus) | 4.7.2 |
| Poly Haven Assets (Blender add-on) | 1.2.3 |

Neovim plugins:

| Plugin | Version |
| --- | --- |
| nvim-treesitter (all grammars) | 0.10.0 (unstable 2026-09-19) |
| nvim-web-devicons | 0.100 |
| lualine.nvim | [`221ce6b`](https://github.com/nvim-lualine/lualine.nvim/commit/221ce6b2d999187044529f49da6554a92f740a96) |
| gitsigns.nvim | 2.1.0 |
| telescope.nvim | [`40aedd8`](https://github.com/nvim-telescope/telescope.nvim/commit/40aedd8a68c78a656a10a8d62d80c54af59420fb) |
| plenary.nvim | [`74b06c6`](https://github.com/nvim-lua/plenary.nvim/commit/74b06c6c75e4eeb3108ec01852001636d85a932b) |
| which-key.nvim | 3.17.0 (unstable 2025-10-28) |
| indent-blankline.nvim | 3.10.1 |

## Virtualisation

| Package | Version |
| --- | --- |
| QEMU (KVM, runs Nike) | 11.1.1 |
| virtiofsd | 1.14.0 |
| Podman | 5.8.7 |
| podman-compose | 1.6.0 |
| Buildah | 1.45.1 |

## Nike (microVM)

Same nixpkgs as the host, so neovim, tmux, ranger and bash match the tables above.

| Package | Version |
| --- | --- |
| OpenVPN | 2.6.23 |
| Nmap | 7.991 |
| Python | 3.14.7 |
| OpenSSH | 10.5p1 |

## Rust tools

[rust-tools.md](rust-tools.md).

| Package | Version |
| --- | --- |
| ripgrep / fd / bat / eza | 15.2.0 / 10.5.0 / 0.26.1 / 0.23.5 |
| dust / dysk / bottom / procs | 1.2.6 / 3.7.0 / 0.14.9 / 0.14.12 |
| sd / ast-grep / jaq / difftastic / delta | 1.1.0 / 0.45.1 / 3.1.1 / 0.71.0 / 0.19.2 |
| xh / hyperfine / tokei / watchexec / just / ouch / zoxide | 0.26.2 / 1.20.0 / 15.0.0 / 2.5.1 / 1.58.0 / 0.8.3 / 0.10.0 |

## Game dev (harmonia host)

[gamedev.md](gamedev.md). The plugin, the MCP servers and the local model are fetched at runtime, pinned here.

| Package | Version |
| --- | --- |
| opencode | 1.18.31 |
| oh-my-openagent (opencode plugin) | 5.1.21 |
| Ornith 1.5 9B (`protoLabsAI/Ornith-1.5-9B-MTP-GGUF`, served as `ai`) | Q4_K_M with the MTP head |
| llama.cpp server image (`ghcr.io/ggml-org/llama.cpp`) | `server-vulkan-b11515` |
| r2mcp (radare2 MCP server) | 1.8.8 |
| MCP for Blender (`mcp-for-blender`) | 2.1.3 |
| Godot AI (`godot-ai`) | 4.3.0 |
| Claude Code | 2.1.283 |

## Secrets

| Package | Version |
| --- | --- |
| GnuPG | 2.4.9 |
| KeePassXC (`keepassxc-cli`) | 2.7.12 |
| yubikey-manager (`ykman`) | 5.9.2 |
| pcsc-lite | 2.4.1 |
| Bitwarden CLI (`bw`) | 2026.9.0 |
| OpenBao (`bao`) | 2.7.0 |

## Firefox

| Package | Version |
| --- | --- |
| Firefox (Flathub `org.mozilla.firefox`) | follows Flathub until `firefoxCommit` is set in `modules/nixos/flatpak.nix` |
| uBlock Origin add-on | 1.75.0 |
| Vimium add-on | 2.4.2 |

## Lutris and Element

| Package | Version |
| --- | --- |
| Lutris (Flathub `net.lutris.Lutris`) | follows Flathub |
| Steam (Flathub `com.valvesoftware.Steam`) | follows Flathub; the client also updates itself |
| Element (Flathub `im.riot.Riot`) | follows Flathub |
| Flatpak Mesa, 32-bit (`org.freedesktop.Platform.GL32.default`) | branch 25.08, follows Flathub |
| GameMode | from the pinned nixpkgs |
| steam-devices-udev-rules | from the pinned nixpkgs |

## Fans

| Package | Version |
| --- | --- |
| LACT daemon (nixpkgs) | 0.10.1 |
| LACT GUI (Flathub `io.github.ilya_zlobintsev.LACT`) | follows Flathub (0.10.1 on 2026-09-29) |
| lm_sensors | 3.6.2 |
| rocm-smi | 7.2.3 |
