# snowflakes

NixOS flake: **sway** + **eww** bar, **alacritty**, **tmux**, **bash**, **ranger**,
**neovim**, **vagrant**/**libvirt**, and **Zen browser** jailed in Flatpak —
all using the [Miami Wind](https://marketplace.visualstudio.com/items?itemName=hanakin.miami-wind)
colour scheme and **DepartureMono Nerd Font**.

## Layout

```
flake.nix                      inputs, hostname/username, nixosConfigurations.snowflake
theme/miami-wind.nix           the palette — every app reads its colours from here
hosts/snowflake/               host config + hardware-configuration.nix (placeholder!)
modules/nixos/
  desktop.nix                  sway, greetd/tuigreet, pipewire, portals, console colours
  fonts.nix                    DepartureMono Nerd Font as system default
  flatpak.nix                  Flathub + Zen browser with a tightened sandbox
  virtualisation.nix           libvirtd/KVM, virt-manager, vagrant (libvirt provider)
home/                          home-manager, one file per program
  sway.nix                     sway, fuzzel launcher, mako, swaylock, swayidle
  eww.nix                      eww bar (workspaces, title, cpu, mem, volume, battery, clock)
  alacritty.nix tmux.nix bash.nix ranger.nix neovim.nix gtk.nix zen.nix
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
restart Zen.

## Keys (sway)

| Key | Action |
| --- | --- |
| `Super+Return` | alacritty |
| `Super+d` | fuzzel launcher |
| `Super+b` | Zen browser |
| `Super+e` | ranger |
| `Super+Shift+b` | toggle eww bar |
| `Super+Shift+x` | lock |
| `Print` / `Shift+Print` | screenshot region / screen to clipboard |

Everything else is sway's default keymap.

## Vagrant / libvirt

Your user is in `libvirtd`, and `VAGRANT_DEFAULT_PROVIDER=libvirt` is set
(nixpkgs' vagrant ships the vagrant-libvirt plugin). Vagrant is BUSL licensed,
so it's allowed as the only unfree package. See `examples/Vagrantfile`.

## Colours

`theme/miami-wind.nix` holds the palette from
[hanakin/miami-wind-vscode](https://github.com/hanakin/miami-wind-vscode):
editor background `#1e1e2e`, foreground `#cdd6f4`, accent pink `#f472b6`,
secondary cyan `#22d3ee`, and the theme's `terminal.ansi*` colours for the
16-colour palette (used by alacritty, the Linux console, ranger and tuigreet).
