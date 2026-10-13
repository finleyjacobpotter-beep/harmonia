# harmonia (desktop)

harmonia is the desktop the project is named after: an AMD GPU workstation
with the full set of apps, the Nike microVM, and the coding agents. Build it with
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

**AI agents** ([`home/ai.nix`](../home/ai.nix), [`home/gamedev.nix`](../home/gamedev.nix)). pi and
Claude Code run natively on the host with no global prompts, and the
Blender, Godot and radare2 MCP servers for both. Claude Code's license is
why harmonia adds `claude-code` to `harmonia.allowedUnfree`. See [pi](pi.md) and
[Game dev](gamedev.md).

**Forgejo CLI.** `fj` for repositories, issues and pull requests on Forgejo
instances such as Codeberg; `fj auth login` signs in.

**Python for uv** (`hosts/harmonia/default.nix`). A Python from nixpkgs, with
`UV_PYTHON` pointing at it and `UV_PYTHON_DOWNLOADS=never`, because a Python
that uv downloads itself can't run on NixOS. The host-side MCP servers use it.

## Shared with cadmus

Everything in [hosts/common.nix](common.md#desktop-and-laptop-hostscommonnix):
Lutris and Steam, native Blender and Godot, QEMU, and the
[Nike](nike.md) microVM with its dash tile and firewall modes. The AI agents
(Claude Code and pi) are harmonia only.

## Hardware

[`hosts/harmonia/hardware-configuration.nix`](../hosts/harmonia/hardware-configuration.nix)
is a **placeholder** so the flake evaluates. Replace it with your own before
the first switch:

```sh
sudo nixos-generate-config --show-hardware-config > hosts/harmonia/hardware-configuration.nix
```

The dash's gpu tile reads both AMD cards (the RX 9070 and the RX 5600 XT)
through `rocm-smi`, with a load and a VRAM meter for each; open it to pick
which card's numbers the summary shows ([GPUs](bar.md#gpus)). It says so
when there is no GPU to report.
