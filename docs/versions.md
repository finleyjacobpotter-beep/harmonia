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

## System

| Package | Version |
| --- | --- |
| Linux kernel (`linuxPackages_latest`) | 7.2.8 |
| systemd | 261.2 |
| bash | 5.3p15 |
| greetd / tuigreet | 0.10.3 / 0.11.1 |
| NetworkManager | 1.58.1 |
| PipeWire / WirePlumber | 1.6.8 / 0.5.17 |
| BlueZ / Blueman | 5.87 / 2.4.6 |
| UPower | 1.91.4 |
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
| QEMU (KVM) | 11.1.1 |
| libvirt | 12.7.0 |
| virt-manager | 5.1.0 |
| swtpm | 0.10.1 (unstable 2026-05-21) |
| virtiofsd | 1.14.0 |
| Podman | 5.8.7 |
| podman-compose | 1.6.0 |
| Buildah | 1.45.1 |
| Kali installer (VM) | 2026.2 (checksum read from the release's SHA256SUMS) |
| Ubuntu Desktop installer (VM) | 26.04.1 (sha256 `601e30fb…1bda1f`) |

## Secrets

| Package | Version |
| --- | --- |
| GnuPG | 2.4.9 |
| pinentry (curses) | 1.3.2 |
| pass | 1.7.4 |
| yubikey-manager (`ykman`) | 5.9.2 |
| pcsc-lite | 2.4.1 |
| Bitwarden CLI (`bw`) | 2026.9.0 |
| OpenBao (`bao`) | 2.7.0 |

## Zen browser

| Package | Version |
| --- | --- |
| Zen (Flathub `app.zen_browser.zen`) | follows Flathub (1.22.3b on 2026-09-27) until `zenCommit` is set in `modules/nixos/flatpak.nix` |
| Vimium add-on | 2.4.2 |
