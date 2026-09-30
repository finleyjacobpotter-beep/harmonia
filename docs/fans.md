# Fans

## GPU (AMD)

[LACT](https://github.com/ilya-zlobintsev/LACT) is split in two
([`modules/nixos/fans.nix`](../modules/nixos/fans.nix)): its daemon runs on
the host as root, because it writes to the GPU, and its window comes from
Flathub (`io.github.ilya_zlobintsev.LACT`) in a Flatpak sandbox that can only
reach the daemon's socket. The window uses the desktop theme (Miami Wind
colours, Tulasi icons, the font), copied in by
[`home/flatpak-theme.nix`](../home/flatpak-theme.nix).

Open **LACT** from fuzzel, go to *Thermals*, switch fan control from automatic to
custom, and drag the curve points. Apply, and the daemon keeps the curve across reboots in
`/etc/lact/config.yaml`.

RX 7000/9000 cards only take a custom curve with amdgpu overdrive enabled,
which `hardware.amdgpu.overdrive.enable` does (it needs one reboot).

To pin the curve in the flake, copy `/etc/lact/config.yaml` into
`services.lact.settings` in `fans.nix` (YAML keys become Nix attributes) and
rebuild. The GUI can't change it after that; edit `fans.nix` instead.

## Case and CPU fans

These are wired to the motherboard, and every board exposes them
differently, so the reliable place for their curves is the BIOS/UEFI setup
(often *Hardware Monitor* or *Q-Fan*/*Smart Fan*). Run `sensors` to see
temperatures and fan speeds from Linux.

Software control is possible with NixOS's `hardware.fancontrol`, but its
config names your board's exact hwmon paths, so it has to be generated on
the machine with `sudo pwmconfig` and then pasted into
`hardware.fancontrol.config`.
