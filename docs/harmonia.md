# harmonia (desktop)

harmonia is the desktop the project is named after: an AMD GPU workstation
with the full set of apps and both microVMs. Build it with
`sudo nixos-rebuild switch --flake .#harmonia`.

It is [`hosts/base.nix`](../hosts/base.nix) plus
[`hosts/common.nix`](../hosts/common.nix) and
[`home/default.nix`](../home/default.nix) (see
[What every environment shares](common.md)), plus the pieces below from
[`hosts/harmonia/`](../hosts/harmonia).

## Only on harmonia

**GPU fan control** ([`modules/nixos/fans.nix`](../modules/nixos/fans.nix)).
The LACT daemon runs as root and its window comes from Flathub, for the AMD
GPU's fan curve; amdgpu overdrive is on so RX 7000/9000 cards accept a custom
curve; `rocm-smi` and lm_sensors report temperatures. Case and CPU fans are
set in the BIOS. See [Fans](fans.md).

**Game dev agents** ([`home/gamedev.nix`](../home/gamedev.nix)). opencode with
oh-my-openagent runs natively on the host: Claude writes the plans and
finishes the work, and the local Ornith 1.5 9B model in LM Studio does
everything in between. Claude Code is installed too, with the Blender and
Godot MCP servers for both. This is why harmonia adds `claude-code` to
`harmonia.allowedUnfree`. See [Game dev](gamedev.md).

**Python for uv** (`hosts/harmonia/default.nix`). A Python from nixpkgs, with
`UV_PYTHON` pointing at it and `UV_PYTHON_DOWNLOADS=never`, because a Python
that uv downloads itself can't run on NixOS. The host-side MCP servers use it.

## Shared with cadmus

Everything in [hosts/common.nix](common.md#desktop-and-laptop-hostscommonnix):
Lutris and Steam, LM Studio, Blender and Godot in Flatpak, QEMU, and the
[Nike](nike.md) and [Zelus](zelus.md) microVMs with their bar badges and
firewall modes. The Zelus side of the Blender and Godot MCP bridges runs on
the host, so Zelus's agents can drive the editors here.

## Hardware

[`hosts/harmonia/hardware-configuration.nix`](../hosts/harmonia/hardware-configuration.nix)
is a **placeholder** so the flake evaluates. Replace it with your own before
the first switch:

```sh
sudo nixos-generate-config --show-hardware-config > hosts/harmonia/hardware-configuration.nix
```

The bar's GPU module reads the AMD card through `rocm-smi`; it hides itself
when there is no GPU to report.
