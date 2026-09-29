# Gaming

Steam comes from Flathub (`com.valvesoftware.Steam`) and runs in a Flatpak
sandbox, the same way as the [Zen browser](zen.md). Start it with `Super+o g`
or from fuzzel.

## What the jail does

Steam, Proton, every game and every Wine prefix live in
`~/.var/app/com.valvesoftware.Steam`. That is the only part of your home
directory the sandbox can see: a game can't read `~/.ssh`, `~/.gnupg`, your
password store, browser profile or this repo, and can't drop anything into
`~/.bashrc` or `~/.config/autostart`. The rest of the host filesystem is
read-only runtime files, and nothing runs as root.

On top of the Flathub manifest, [`modules/nixos/gaming.nix`](../modules/nixos/gaming.nix)
revokes:

- read access to `~/Music` and `~/Pictures`
- read-write access to `/mnt`, `/media` and `/run/media` (other drives, USB sticks)
- the Discord rich-presence socket
- UDisks2 on the system bus, so Wine can't list or mount drives

Check the effective permissions with
`flatpak info --show-permissions com.valvesoftware.Steam`.

## What it doesn't do

A sandbox is a strong fence, not a VM. Kept deliberately, because games
break without them:

- **Network.** Games can reach the internet and your LAN.
- **X11.** The Steam client and most Proton games are X11 apps under
  Xwayland. An X11 app can read input to and screenshots of other Xwayland
  windows. Native Wayland apps (alacritty, Zen, most of the desktop) are
  invisible to it.
- **Devices.** `--device=all` stays so controllers, wheels and VR headsets
  work. That includes webcams and microphones.
- **Kernel.** A game and the host share one kernel, so a kernel exploit
  escapes any sandbox.

For a game you really don't trust, use a VM ([VMs and containers](vms-and-containers.md))
with the `isolated` or `internet-only` firewall, accepting worse graphics.

## Why Flatpak and not…

| Option | Isolation | GPU / performance | Anti-cheat |
| --- | --- | --- | --- |
| **Flatpak Steam** (this) | own home dir, revoked host paths | native | EAC and BattlEye games that support Linux work |
| nixpkgs `programs.steam` | none: games run as you with full home access | native | same |
| A separate `gaming` user | strong for files, but it needs its own sway session or access to yours | native | same |
| libvirt VM | strongest | virgl only, or a second GPU for passthrough | many anti-cheats refuse to run in VMs |

Flatpak is the only option that keeps full GPU performance and costs nothing
to use day to day. It also keeps the unfree Steam package out of nixpkgs'
allow-list.

## Proton and anti-cheat

Enable Proton for all titles in *Steam → Settings → Compatibility*. Proton runs
inside the same sandbox (Steam's own pressure-vessel container nests inside
Flatpak). Proton-GE is available as a Flatpak too:

```sh
flatpak install flathub com.valvesoftware.Steam.CompatibilityTool.Proton-GE
```

Easy Anti-Cheat and BattlEye work for games whose developers enabled Linux
support. Games with kernel-level anti-cheat (Valorant, some Call of Duty,
Fortnite) don't run on Linux at all, jailed or not. Check a game on
[ProtonDB](https://www.protondb.com/) or [Are We Anti-Cheat Yet?](https://areweanticheatyet.com/).

## Controllers and GameMode

`hardware.steam-hardware.enable` installs udev rules for Steam Controllers,
DualShock/DualSense, Switch Pro and Valve Index hardware.

[GameMode](https://github.com/FeralInteractive/gamemode) runs on the host and
the sandbox reaches it through the desktop portal. Set a game's launch options
to `gamemoderun %command%` to use it.

In sway, Steam's friends list and settings windows float, and a fullscreen
game stops the screen from locking or blanking.

## A library on another drive

Grant just that directory back in `modules/nixos/gaming.nix`:

```nix
filesystems = [
  # ...
  "/mnt/games"
];
```

rebuild, then add it in *Steam → Settings → Storage*. For a one-off without
rebuilding: `flatpak override --user --filesystem=/mnt/games com.valvesoftware.Steam`.
