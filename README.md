# harmonia

*Named for Harmonia, goddess of harmony and concord: one palette, one font and one
icon theme, shared by every program on the desktop.*

NixOS flake: **sway** + **eww** bar, **alacritty**, **tmux**, **bash**, **ranger**,
**neovim**, **libvirt**, **podman**, and **Zen browser** jailed in Flatpak —
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
  virtualisation.nix           libvirtd/KVM, virt-manager, rootless podman + buildah
  vms.nix                      Kali (i3) and Ubuntu (GNOME) libvirt VMs, virtio GPU
vms/kali-i3.nix                i3 + i3status config for the Kali VM (Alt modifier)
home/                          home-manager, one file per program
  sway.nix                     sway, fuzzel launcher, mako, swaylock, swayidle
  eww.nix                      eww bar (workspaces, title, cpu, mem, volume, battery, clock)
  keymap.nix                   build-time checks for the keyboard contract
  tui.nix                      btop, pulsemixer, bluetuith
  alacritty.nix tmux.nix bash.nix ranger.nix neovim.nix gtk.nix zen.nix
pkgs/tulasi-icon-theme.nix     Tulasi icon theme (not in nixpkgs) with Tulasi-only fallbacks
assets/wallpaper.png           the wallpaper, pre-recoloured to Miami Wind
```

## Install

1. Edit `hostname` / `username` in `flake.nix`, and the timezone/locale/keymap in
   `hosts/harmonia/default.nix`.
2. Replace the placeholder hardware config:
   ```sh
   sudo nixos-generate-config --show-hardware-config > hosts/harmonia/hardware-configuration.nix
   ```
3. Build and switch (this also creates `flake.lock` from the pinned inputs; see
   [Pinned versions](#pinned-versions)):
   ```sh
   sudo nixos-rebuild switch --flake .#harmonia
   ```
4. Log in (initial password `changeme`), run `passwd`.

## Pinned versions

Every flake input is pinned to an exact commit in `flake.nix`, and every package
comes from the pinned nixpkgs, so a build always gets the versions below. They
only change when an input's commit is bumped; update this table when you do.

### Flake inputs

| Input | Pinned to |
| --- | --- |
| nixpkgs | [`e158d9e`](https://github.com/NixOS/nixpkgs/commit/e158d9ed9b51c98974c5e66e1ba1c9e0255fecaa) (nixos-unstable, 2026-09-27) |
| home-manager | [`7b4c5ec`](https://github.com/nix-community/home-manager/commit/7b4c5ec4bedaf1e062bbc1bcaeddbc6bd242aa1b) (master, 2026-09-27) |
| nix-flatpak | v0.7.0 ([`4408189`](https://github.com/gmodena/nix-flatpak/commit/440818969ac2cbd77bfe025e884d0aa528991374)) |

### System

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

### Desktop

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

### Terminal and apps

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

### Virtualisation

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

### Zen browser

| Package | Version |
| --- | --- |
| Zen (Flathub `app.zen_browser.zen`) | follows Flathub (1.22.3b on 2026-09-27) until `zenCommit` is set in `modules/nixos/flatpak.nix` |
| Vimium add-on | 2.4.2 |

## Zen browser jail

Zen comes from Flathub via [nix-flatpak](https://github.com/gmodena/nix-flatpak).
On top of the Flathub manifest, `modules/nixos/flatpak.nix` revokes:

- all host and home filesystem access — the only host path is `~/Downloads/zen`
- the X11 socket (Wayland only), CUPS and smartcard sockets
- all devices except the GPU (`dri`). Remove `"!all"` if you need a webcam or
  a FIDO/U2F key.

Check the effective permissions with `flatpak info --show-permissions app.zen_browser.zen`.

The browser is themed via `userChrome.css`/`userContent.css`/`user.js` copied
into each Zen profile. Profiles only exist after Zen has been started once, so
after the first launch run `zen-miami-wind` (it also runs on every rebuild) and
restart Zen. The same step installs the Vimium extension.

## Keyboard

Everything is driven from the keyboard with vim-style keys. Each modifier
belongs to exactly one layer ([`keys.nix`](keys.nix)), so layers never fight:

| Namespace | Owner | Notes |
| --- | --- | --- |
| `Super` + … | **sway** | nothing else binds Super |
| `Ctrl+Space` … | **tmux** prefix | no prefix-less tmux keys, so every other key reaches the program inside. `Ctrl+Space Ctrl+Space` sends a literal Ctrl+Space |
| `Ctrl+Shift` + … | **alacritty** | its Ctrl+= / Ctrl+- / Ctrl+0 defaults are passed through to programs instead |
| `Alt` + … | **i3 in the Kali VM** | nothing on the host binds Alt, so a VM window gets it untouched |
| everything else | focused app | Zen + Vimium, neovim, ranger, bash (vi mode), btop, pulsemixer, bluetuith… |

Zen and tmux may share keys (only one has focus); CLI tools may never use
Super, Ctrl+Space or Ctrl+Shift. [`home/keymap.nix`](home/keymap.nix) checks
this at build time: a sway binding without Super, a tmux `bind -n`, or an
alacritty binding outside Ctrl+Shift fails `nixos-rebuild`, and so does any
Alt binding in neovim, tmux or alacritty.

### sway (`Super`)

| Key | Action |
| --- | --- |
| `h` `j` `k` `l` | focus left/down/up/right |
| `Shift` + `h` `j` `k` `l` | move window |
| `Ctrl` + `h` / `l` | focus output left/right (`Ctrl+Shift`: move workspace there) |
| `1`…`0` / `Shift` + `1`…`0` | go to / move to workspace |
| `Tab`, `[`, `]` | last / previous / next workspace |
| `s` / `v` | split below / beside (like vim `:split` / `:vsplit`) |
| `t` / `Shift+t` / `e` | tabbed / stacking / toggle split layout |
| `f` | fullscreen |
| `space` / `Shift+space` | toggle focus tiling↔floating / toggle floating |
| `a` / `Shift+a` | focus parent / child |
| `-` / `Shift+-` | show scratchpad / move to scratchpad |
| `q` | close window |
| `Return` | alacritty |
| `d` | fuzzel launcher (`Ctrl+j`/`Ctrl+k` to move) |
| `n` / `Shift+n` / `Ctrl+n` / `i` | dismiss / dismiss all / restore / act on notification |
| `Shift+s` / `Ctrl+s` | screenshot region / screen to clipboard |
| `Shift+b` | toggle eww bar |
| `Shift+x` | lock |
| `Shift+c` | reload sway |

**Modes** (Esc or Return leaves; the eww bar shows the active mode and its keys):

| Enter | Mode | Keys |
| --- | --- | --- |
| `Super+r` | resize | `h` `j` `k` `l` (`Shift` = bigger steps) |
| `Super+o` | open | `b` Zen · `f` ranger · `e` nvim · `t` tmux · `s` btop · `a` pulsemixer · `u` bluetuith · `n` nmtui · `v` virt-manager |
| `Super+m` | media | `j`/`k` volume · `m` mute · `Shift+m` mic · `h`/`l` prev/next · `p` play/pause · `Shift+j`/`Shift+k` brightness |
| `Super+Shift+e` | system | `l` lock · `e` exit sway · `s` suspend · `r` reboot · `Shift+p` power off |

Hardware keys (volume, media, brightness, Print) work as usual.

### tmux (`Ctrl+Space`, then…)

| Key | Action |
| --- | --- |
| `h` `j` `k` `l` / `H` `J` `K` `L` | select / resize pane (repeatable) |
| `s` / `v` | split below / beside |
| `c` / `n` / `p` / `Tab` | new / next / previous / last window |
| `q` / `Q` | kill pane / window |
| `w` / `S` | pick window / session |
| `<` / `>` | move window left/right |
| `z` | zoom pane |
| `Escape` or `[` | copy mode: vim motions, `v` select, `Ctrl+v` block, `y` yank |
| `P` | paste |
| `d` | detach |
| `r` | reload config |

### alacritty (`Ctrl+Shift`)

`C`/`V` copy/paste · `F`/`B` search · `Space` vi mode (scrollback with hjkl) ·
`O` open a URL by hint · `K`/`J`/`0` font bigger/smaller/reset · `N` new window.

### Apps

- **Zen**: [Vimium](https://github.com/philc/vimium) is installed into each
  profile: `j`/`k` scroll, `f` follow link, `J`/`K` previous/next tab,
  `H`/`L` back/forward, `o`/`O` open URL, `T` search tabs, `/` find,
  `x`/`X` close/restore tab, `?` help. Vimium can't run on `about:` pages;
  use Zen's own `Ctrl+L`, `Ctrl+T`, `Ctrl+Tab` there.
- **bash**: readline vi mode (`Esc` for normal mode; cursor is a bar in
  insert mode, a block in normal mode). `Ctrl+r` fzf history, `Ctrl+t` fzf files.
- **neovim**: leader is `Space` (`which-key` shows the rest). `Space f f/g/b`
  telescope, `Space s`/`Space v` split, `Ctrl+w h/j/k/l` between windows.
- **ranger**, **btop**, **pulsemixer**, **bluetuith**, **fzf**, **less**: vim
  keys (`btop` has `vim_keys` turned on).
- **nmtui** and **virt-manager** are keyboard-driven but don't use vim keys.

## VMs and containers

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
   ripgrep and fd, and copies the configs into place (existing ones are kept as
   `*.bak`).

The Kali i3 config ([`vms/kali-i3.nix`](vms/kali-i3.nix)) uses **Alt** as its
modifier with vim directions (`Alt+h/j/k/l` focus, `Alt+Shift+h/j/k/l` move,
`Alt+Return` terminal, `Alt+d` rofi, `Alt+q` close, `Alt+1…0` workspaces,
`Alt+r` resize mode, `Alt+Shift+e` system mode). Super stays with the host's
sway, and neovim never binds Alt, so nothing overlaps. If your GPU driver has
no virgl support, set `accel3d="no"` and `<gl enable="no"/>` in `vms.nix`.

## Icons

Tulasi is the only icon theme. Instead of upstream's breeze/Adwaita
fallback, every icon Tulasi doesn't draw resolves to one of its own generic
icons (`pkgs/tulasi-icon-theme.nix`): apps → the purple "?" tile, files →
a document, folders → a folder, hardware → a computer, anything else → "?".
This covers every standard icon name and every `Icon=` in the desktop files
of installed packages, so the theme is rebuilt when your package set changes.

**Inside the Zen sandbox** the same icons are used without opening the jail:
Tulasi is copied (as real files) into Zen's own private data dir,
`~/.var/app/app.zen_browser.zen/data/icons`, and a sandbox-local
`config/gtk-3.0/settings.ini` selects it. Zen already owns that directory, so
no flatpak permission is added. The copy is the generic build, without the
list of your installed programs. Zen's launcher icon, notifications and file
picker are drawn on the host and use Tulasi anyway.

## Mouse

The pointer hides as soon as you type and comes back when the mouse moves
(sway `hide_cursor when-typing`).

## Unfree packages

Only one non-free package is allowed (`hosts/harmonia/default.nix`):
the Tulasi icon theme (CC BY-NC-SA 4.0, free for non-commercial use with
attribution).

## Colours

`theme/miami-wind.nix` holds the palette from
[hanakin/miami-wind-vscode](https://github.com/hanakin/miami-wind-vscode):
editor background `#1e1e2e`, foreground `#cdd6f4`, accent pink `#f472b6`,
secondary cyan `#22d3ee`, and the theme's `terminal.ansi*` colours for the
16-colour palette (used by alacritty, the Linux console, ranger and tuigreet).

## Wallpaper

`assets/wallpaper.png` is scaled to fit and centred on the background colour `#1e1e2e`.
It was recoloured to the Miami Wind palette with
[lutgen](https://github.com/ozwaldorf/lutgen-rs), using every colour in
`theme/miami-wind.nix`:

```
lutgen apply -P -L 0.5 -o wallpaper.png original.jpg -- <palette colours>
```

and its black outer margin was then flood-filled with `#1e1e2e` so the image
blends into the background.

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
  Flatpak setup for Zen.

## License

The configuration in this repository is [MIT](LICENSE) licensed. That covers
the Nix code and scripts only: the projects above keep their own licenses.
In particular the Tulasi icons are CC BY-NC-SA 4.0 (non-commercial use with
attribution), and the wallpaper artwork belongs to its artist and is not
covered by this repository's license.
