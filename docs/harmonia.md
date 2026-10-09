# harmonia (desktop)

harmonia is the desktop the project is named after: an AMD GPU workstation
with the full set of apps, the Nike microVM, and the local model server that
the coding agents use. Build it with
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

**Local model server** ([`modules/nixos/llama-server.nix`](../modules/nixos/llama-server.nix)).
llama.cpp's server in a podman container serves Ornith 1.5 9B (Q4_K_M, with
its multi-token prediction head) as `ai` on the AMD GPU through Vulkan, at
`127.0.0.1:1235`. The robot icon on the bar starts and stops it; it doesn't
start at boot. See
[The local model](llama-server.md).

**Game dev agents** ([`home/gamedev.nix`](../home/gamedev.nix)). opencode with
oh-my-openagent runs natively on the host, every agent on the local model,
four at a time, with no other provider. Claude Code is installed too, with
the Blender, Godot and radare2 MCP servers for both. This is why harmonia
adds `claude-code` to `harmonia.allowedUnfree`. See [Game dev](gamedev.md).

**Forgejo CLI.** `fj` for repositories, issues and pull requests on Forgejo
instances such as Codeberg; `fj auth login` signs in.

**Python for uv** (`hosts/harmonia/default.nix`). A Python from nixpkgs, with
`UV_PYTHON` pointing at it and `UV_PYTHON_DOWNLOADS=never`, because a Python
that uv downloads itself can't run on NixOS. The host-side MCP servers use it.

## Shared with cadmus

Everything in [hosts/common.nix](common.md#desktop-and-laptop-hostscommonnix):
Lutris and Steam, native Blender and Godot, QEMU, and the
[Nike](nike.md) microVM with its bar badge and firewall modes. The AI agents
(Claude Code and opencode) are harmonia only.

## Hardware

[`hosts/harmonia/hardware-configuration.nix`](../hosts/harmonia/hardware-configuration.nix)
is a **placeholder** so the flake evaluates. Replace it with your own before
the first switch:

```sh
sudo nixos-generate-config --show-hardware-config > hosts/harmonia/hardware-configuration.nix
```

The bar's GPU module reads the AMD card through `rocm-smi`; it hides itself
when there is no GPU to report.
