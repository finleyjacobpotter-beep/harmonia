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
- `/media` and `/run/media` (USB sticks, other drives) and Flatpak Steam's
  data (its logins and config; shared games live in `~/Games`)
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

## Graphics drivers

The host runs Mesa (radeonsi for OpenGL, RADV for Vulkan) with the 32-bit
builds enabled, set in [`modules/nixos/desktop.nix`](../modules/nixos/desktop.nix).
Check it with `vulkaninfo --summary` (the GPU should say `RADV`) and
`glxinfo -B`.

Lutris doesn't use the host's Mesa: every Flatpak gets Mesa from the Flathub
runtime. The 64-bit build (`org.freedesktop.Platform.GL.default`) comes
automatically; the 32-bit one (`org.freedesktop.Platform.GL32.default`), which
32-bit Windows games and DXVK need, is installed by `gaming.nix`. Check that
both are there with `flatpak list --runtime | grep GL`. DXVK and VKD3D turn
Direct3D into Vulkan and are on by default in Lutris's Wine runner options.

## Steam

Steam comes from Flathub too (`com.valvesoftware.Steam`), in its own sandbox
([`modules/nixos/steam.nix`](../modules/nixos/steam.nix)). Start it with
`Super+o Shift+g`. Proton runs inside that sandbox, so Windows games work as
they would with any Linux Steam.

It is locked down as far as Steam still runs. Its logins, config and Proton
prefixes stay in `~/.var/app/com.valvesoftware.Steam`, and the only host
directory it can see is `~/Games`. On top of the Flathub manifest it loses:

- `~/Music`, `~/Pictures`, `/mnt`, `/media` and `/run/media`
- the Discord, MangoHud and speech-dispatcher paths
- the PipeWire socket, which reaches cameras and screen capture without the
  portal asking. Game audio still works; Steam's game recording and Remote
  Play streaming don't.
- raw Bluetooth sockets (Bluetooth controllers pair through the host as usual)
- UDisks2 on the system bus

Network, X11, `--device=all` and `/run/udev` stay, for the same reasons as
Lutris (see above).

### A library Lutris can see

`~/Games` is the one directory Steam and Lutris share. The first time you
start Steam, open **Settings → Storage**, add a drive, pick
`~/Games/SteamLibrary` and make it the default. Games installed there are
visible to Lutris; Steam's logins and config are not.

To launch a Steam game from Lutris:

1. Find the game's App ID: it's the number in its store page URL
   (`store.steampowered.com/app/<id>/`).
2. In Lutris click **+** → **Add locally installed game**. Name it, and set
   the runner to **Linux**.
3. Under **Game options**, set the executable to `/usr/bin/xdg-open` and the
   arguments to `steam://rungameid/<id>`.

Starting it asks Steam to launch the game, through the desktop portal. The
first time, the portal may ask which app should open `steam://` links: pick
Steam.

Lutris's built-in Steam runner and Steam library sync would do this for you,
but they start Steam with `flatpak-spawn --host`, the escape `gaming.nix`
revokes. The link keeps each app in its own jail.

DRM-free games bought on Steam can also run straight from Lutris: add the
game's `.exe` under `~/Games/SteamLibrary/steamapps/common/` with the Wine
runner. Games that need Steam running still need the link above.

Anything in `~/Games` can be changed by any game in either app, so a bad game
can tamper with the others there.

### Steam (Windows) in Lutris

If you'd rather keep Steam inside Lutris, the Windows client runs under
Wine: in Lutris, **+** → **Search the Lutris website for installers** →
**Steam** → the **Windows** installer, installed under `~/Games`. If its
window stays black, add `-cef-disable-gpu` under **Configure → Game options
→ Arguments**. It is rougher than Flatpak Steam: Proton's anti-cheat
support, Steam Input and the overlay work badly or not at all under Wine.

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
