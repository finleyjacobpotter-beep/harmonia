# cadmus (laptop)

cadmus is harmonia on a **Lenovo ThinkPad E14 Gen 2**: the same desktop, apps
and microVMs, plus what a laptop needs. Build it with
`sudo nixos-rebuild switch --flake .#cadmus`.

It is [`hosts/base.nix`](../hosts/base.nix) plus
[`hosts/common.nix`](../hosts/common.nix) and
[`home/default.nix`](../home/default.nix) (see
[What every environment shares](common.md)), plus the pieces below from
[`hosts/cadmus/`](../hosts/cadmus).

## Only on cadmus

**Hardware profile.** nixos-hardware's E14 Gen 2 profile sets CPU microcode,
the graphics driver, TrackPoint, SSD trim and native backlight control. The
E14 Gen 2 shipped with either an Intel or an AMD CPU, so set `cpu` in
[`hosts/cadmus/default.nix`](../hosts/cadmus/default.nix) to `"intel"` (the
default) or `"amd"`; `lscpu` tells you which. The AMD profile also keeps the
IOMMU in software mode, which amdgpu needs on BIOS versions before 1.13.

**Laptop basics** ([`modules/nixos/laptop.nix`](../modules/nixos/laptop.nix)):

- Redistributable firmware and the wireless regulatory database, so Wi-Fi
  and Bluetooth chips come up and use the channels allowed where you are.
- Join a Wi-Fi network with `Super+o n` (`nmtui`, on every host) or
  `nmcli device wifi connect <SSID> --ask`. The bar shows a Wi-Fi icon when
  the default route is wireless.
- Closing the lid suspends, on battery and on mains; docked with an external
  display, it keeps running. swayidle locks the screen first.
- Power profiles (saver, balanced, performance) with `powerprofilesctl`.
- `iw` and `powertop` for checking the card and the battery.

**ThinkPad fans and firmware** ([`modules/nixos/thinkpad.nix`](../modules/nixos/thinkpad.nix)):

- thinkfan drives the fan from the CPU temperature through `thinkpad_acpi`,
  quieter than Lenovo's curve at idle; the hottest step hands control back to
  the firmware, so it is never quieter than Lenovo's own curve when hot.
  Edit `levels` to change it; `cat /proc/acpi/ibm/fan` and `sensors` show
  what it is doing.
- fwupd for BIOS and firmware updates.

## Not on cadmus

- The AMD GPU fan control (LACT); cadmus uses thinkfan instead.
- The [local model server](llama-server.md) and the [game dev agents](gamedev.md);
  they are harmonia only. cadmus has no AI agents: no Claude Code, no
  omo.
- The Forgejo CLI.

## Shared with harmonia

Everything in [hosts/common.nix](common.md#desktop-and-laptop-hostscommonnix):
Lutris and Steam, native Blender and Godot, QEMU, and the
[Nike](nike.md) microVM. The bar adds a battery module
when there is a battery to show.

## Hardware

[`hosts/cadmus/hardware-configuration.nix`](../hosts/cadmus/hardware-configuration.nix)
is a **placeholder**. Replace it with your own before the first switch:

```sh
sudo nixos-generate-config --show-hardware-config > hosts/cadmus/hardware-configuration.nix
```
