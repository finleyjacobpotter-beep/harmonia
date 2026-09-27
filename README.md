# snowflakes

NixOS flake: **sway** + **eww** bar, **alacritty**, **tmux**, **bash**, **ranger**,
**neovim**, **vagrant**/**libvirt**, and **Zen browser** jailed in Flatpak —
all using the [Miami Wind](https://marketplace.visualstudio.com/items?itemName=hanakin.miami-wind)
colour scheme, **DepartureMono Nerd Font** and the pixel-art
[**Tulasi**](https://github.com/ShringarStudio/Tulasi) icon theme.

## Layout

```
flake.nix                      inputs, hostname/username, nixosConfigurations.snowflake
theme/miami-wind.nix           the palette — every app reads its colours from here
keys.nix                       the keyboard contract (which layer owns which modifier)
hosts/snowflake/               host config + hardware-configuration.nix (placeholder!)
modules/nixos/
  desktop.nix                  sway, greetd/tuigreet, pipewire, portals, console colours
  fonts.nix                    DepartureMono Nerd Font as system default
  flatpak.nix                  Flathub + Zen browser with a tightened sandbox
  virtualisation.nix           libvirtd/KVM, virt-manager, vagrant (libvirt provider)
home/                          home-manager, one file per program
  sway.nix                     sway, fuzzel launcher, mako, swaylock, swayidle
  eww.nix                      eww bar (workspaces, title, cpu, mem, volume, battery, clock)
  keymap.nix                   build-time checks for the keyboard contract
  tui.nix                      btop, pulsemixer, bluetuith
  alacritty.nix tmux.nix bash.nix ranger.nix neovim.nix gtk.nix zen.nix
pkgs/tulasi-icon-theme.nix     Tulasi icon theme (not in nixpkgs), added via overlay
examples/Vagrantfile           libvirt + virtiofs example
```

## Install

1. Edit `hostname` / `username` in `flake.nix`, and the timezone/locale/keymap in
   `hosts/snowflake/default.nix`.
2. Replace the placeholder hardware config:
   ```sh
   sudo nixos-generate-config --show-hardware-config > hosts/snowflake/hardware-configuration.nix
   ```
3. Build and switch (this also creates `flake.lock`):
   ```sh
   sudo nixos-rebuild switch --flake .#snowflake
   ```
4. Log in (initial password `changeme`), run `passwd`.

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
| everything else | focused app | Zen + Vimium, neovim, ranger, bash (vi mode), btop, pulsemixer, bluetuith… |

Zen and tmux may share keys (only one has focus); CLI tools may never use
Super, Ctrl+Space or Ctrl+Shift. [`home/keymap.nix`](home/keymap.nix) checks
this at build time: a sway binding without Super, a tmux `bind -n`, or an
alacritty binding outside Ctrl+Shift fails `nixos-rebuild`.

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

## Vagrant / libvirt

Your user is in `libvirtd`, and `VAGRANT_DEFAULT_PROVIDER=libvirt` is set
(nixpkgs' vagrant ships the vagrant-libvirt plugin). See `examples/Vagrantfile`.

## Unfree packages

Only two non-free packages are allowed (`hosts/snowflake/default.nix`):
vagrant (BUSL-1.1) and the Tulasi icon theme (CC BY-NC-SA 4.0, free for
non-commercial use with attribution).

## Colours

`theme/miami-wind.nix` holds the palette from
[hanakin/miami-wind-vscode](https://github.com/hanakin/miami-wind-vscode):
editor background `#1e1e2e`, foreground `#cdd6f4`, accent pink `#f472b6`,
secondary cyan `#22d3ee`, and the theme's `terminal.ansi*` colours for the
16-colour palette (used by alacritty, the Linux console, ranger and tuigreet).
