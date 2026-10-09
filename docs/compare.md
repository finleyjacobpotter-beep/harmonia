# Comparing environments

What each environment has, side by side. ✓ means it has it, blank means it
doesn't. [What every environment shares](common.md) explains the shared
pieces.

## Hosts

| | [harmonia](harmonia.md) | [cadmus](cadmus.md) | [Dionysus](dionysus.md) |
| --- | --- | --- | --- |
| Kind | Desktop | Laptop (ThinkPad E14 Gen 2) | VM (QEMU/SPICE or VirtualBox) |
| Architectures | x86_64 | x86_64 | x86_64 and aarch64 |
| Flake output | `.#harmonia` | `.#cadmus` | `.#dionysus`, `.#dionysus-aarch64` |
| User | `u` | `u` | `d` |
| Config | `base` + `common` + `hosts/harmonia` | `base` + `common` + `hosts/cadmus` | `base` + `hosts/dionysus` |
| Home | `home/default.nix` | `home/default.nix` | `home/dionysus/` |
| Sway, eww bar, terminal tools, Miami Wind | ✓ | ✓ | ✓ (software rendering) |
| Firefox, Element (Flatpak) | ✓ | ✓ | ✓ |
| Podman, VPNs, secrets tools | ✓ | ✓ | ✓ |
| Lutris and Steam | ✓ | ✓ | |
| Blender and Godot (native) | ✓ | ✓ | |
| [Local model server](llama-server.md) (llama.cpp, `ai`) | ✓ | | |
| Nike microVM | ✓ | ✓ | |
| Claude Code and opencode | ✓ for [game dev](gamedev.md) | | |
| radare2 MCP | ✓ (game dev) | | |
| OSCP toolset and lab stacks | in Nike | in Nike | ✓ native |
| Forgejo CLI (`fj`) | ✓ | | |
| Rust CLI tools | ✓ | ✓ | ✓ |
| Git identity set | | | `Dionysus` |
| Fan control | LACT (AMD GPU) | thinkfan | |
| Wi-Fi firmware, lid, power profiles | | ✓ | |
| fwupd | | ✓ | |
| Guest tools (SPICE, VirtualBox) | | | ✓ |
| Extra unfree packages | `claude-code` | | |

## MicroVMs

Nike is the only microVM. It runs on harmonia and cadmus, built as part of
the host.

| | [Nike](nike.md) |
| --- | --- |
| Purpose | VPN work and OSCP practice |
| User | `k`, password `k` |
| Accent colour | Orange |
| Address (host side) | `10.20.0.2` (`10.20.0.1`) |
| Resources | 4 vCPUs, 6 GiB |
| Volumes | `/home` 16 GiB, `/var` 24 GiB |
| Shared folder | `~/nike-share` ↔ `~/share` |
| Open key | `Super+o v` |
| Firewall modes | Lockdown, OSCP, Hack The Box, Permissive |
| Main software | OSCP toolset, podman lab stacks (Ligolo-ng, BloodHound, CyberChef, ZAP, Mythic) |
