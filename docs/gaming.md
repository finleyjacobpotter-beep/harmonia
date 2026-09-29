# Gaming

Lutris comes from Flathub (`net.lutris.Lutris`) and runs in a Flatpak
sandbox, the same way as the [Zen browser](zen.md). Start it with `Super+o g`
or from fuzzel. From Lutris you can install GOG, Epic (through the Heroic or
Legendary integrations), Battle.net and plain Windows installers under Wine or
Proton (umu).

## What the jail does

Lutris, Wine, every prefix and every game can see only two places in your
home directory:

- `~/.var/app/net.lutris.Lutris`: Lutris's own config, runners and Wine
  builds
- `~/Games`: the default install location, and where to drop installers
  (`.exe`, GOG `.sh` files) so Lutris can see them

A game can't read `~/.ssh`, `~/.gnupg`, your password store, browser profile or
this repo, and can't drop anything into `~/.bashrc` or `~/.config/autostart`.
Nothing runs as root.

Flathub's Lutris is far more open than that. On top of its manifest,
[`modules/nixos/gaming.nix`](../modules/nixos/gaming.nix) revokes:

- **`org.freedesktop.Flatpak` on the session bus.** This lets an app run any
  command on the host, outside the sandbox (`flatpak-spawn --host`). With it,
  the rest of the jail means nothing.
- access to your whole home directory (only `~/Games` is given back)
- `/media` and `/run/media` (USB sticks, other drives) and Flathub Steam's data
- UDisks2 on the system bus, so Wine can't list or mount drives

Check the effective permissions with
`flatpak info --show-permissions net.lutris.Lutris`.

## What it doesn't do

A sandbox is a strong fence, not a VM. Kept deliberately, because games
break without them:

- **Network.** Games can reach the internet and your LAN.
- **X11.** Wine and most games are X11 apps under Xwayland. An X11 app can
  read input to and screenshots of other Xwayland windows. Native Wayland apps
  (alacritty, Zen, Element, most of the desktop) are invisible to it.
- **Devices.** `--device=all` stays so controllers and wheels work. That
  includes webcams and microphones.
- **`~/.local/share/umu`.** Flathub lets Lutris keep the umu (Proton) runtime
  there. It holds only that runtime.
- **Kernel.** A game and the host share one kernel, so a kernel exploit
  escapes any sandbox.

Everything in `~/Games` is visible to every game, so one bad game can tamper
with another. For a game you really don't trust, use a VM
([VMs and containers](vms-and-containers.md)) with the `isolated` or
`internet-only` firewall, accepting worse graphics.

## Why Flatpak and not…

| Option | Isolation | GPU / performance | Anti-cheat |
| --- | --- | --- | --- |
| **Flatpak Lutris** (this) | own data dir plus `~/Games`, no host commands | native | EAC and BattlEye games that support Linux work |
| nixpkgs `lutris` | none: games run as you with full home access | native | same |
| A separate `gaming` user | strong for files, but it needs its own sway session or access to yours | native | same |
| libvirt VM | strongest | virgl only, or a second GPU for passthrough | many anti-cheats refuse to run in VMs |

## Theming

Lutris is a GTK 3 app, so it gets the same look as the rest of the desktop:
the adw-gtk3 dark theme with the Miami Wind colours, Tulasi icons, the Bibata
cursor and DepartureMono. The sandbox can't read the host's copies, so
[`home/flatpak-theme.nix`](../home/flatpak-theme.nix) copies them into
`~/.var/app/net.lutris.Lutris` on every rebuild (or run `flatpak-miami-wind`).
Games themselves draw their own UI and aren't themed.

## Anti-cheat

Easy Anti-Cheat and BattlEye work for games whose developers enabled Linux
support. Games with kernel-level anti-cheat (Valorant, some Call of Duty,
Fortnite) don't run on Linux at all, jailed or not. Check a game on
[ProtonDB](https://www.protondb.com/) or [Are We Anti-Cheat Yet?](https://areweanticheatyet.com/).

## Controllers and GameMode

`hardware.steam-hardware.enable` installs udev rules for Steam Controllers,
DualShock/DualSense, Switch Pro and Valve Index hardware.

[GameMode](https://github.com/FeralInteractive/gamemode) runs on the host and
the sandbox reaches it through the desktop portal. Turn on *Enable Feral
GameMode* in a game's (or all games') system options in Lutris.

In sway, any fullscreen X11 window (every Wine game) stops the screen from
locking or blanking.

## Games on another drive

Grant just that directory in `modules/nixos/gaming.nix`:

```nix
filesystems = [
  # ...
  "/mnt/games"
];
```

and rebuild. For a one-off without rebuilding:
`flatpak override --user --filesystem=/mnt/games net.lutris.Lutris`.
