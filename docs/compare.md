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
| LM Studio | ✓ | ✓ | |
| Blender and Godot (Flatpak) | ✓ | ✓ | |
| Nike and Zelus microVMs | ✓ | ✓ | |
| Claude Code and opencode | ✓ native, for [game dev](gamedev.md); also in Zelus | in Zelus | ✓ native |
| Rust CLI tools | ✓ | ✓ | ✓ |
| Fan control | LACT (AMD GPU) | thinkfan | |
| Wi-Fi firmware, lid, power profiles | | ✓ | |
| fwupd | | ✓ | |
| Guest tools (SPICE, VirtualBox) | | | ✓ |
| Extra unfree packages | `claude-code` | | `claude-code` |

## MicroVMs

Both run on harmonia and cadmus, built as part of the host.

| | [Nike](nike.md) | [Zelus](zelus.md) |
| --- | --- | --- |
| Purpose | VPN work and OSCP practice | Coding agents |
| User | `k`, password `k` | `c`, no password |
| Accent colour | Orange | Cyan |
| Address (host side) | `10.20.0.2` (`10.20.0.1`) | `10.20.1.2` (`10.20.1.1`) |
| Resources | 4 vCPUs, 6 GiB | 4 vCPUs, 6 GiB |
| Volumes | `/home` 16 GiB, `/var` 24 GiB | `/home` 32 GiB, `/var` 4 GiB |
| Shared folders | `~/nike-share` ↔ `~/share` | `~/zelus-share` ↔ `~/share`, `~/Projects` ↔ `~/Projects` |
| Open key | `Super+o v` | `Super+o z` |
| Firewall modes | Lockdown, OSCP, Hack The Box, Permissive | Lockdown, Local inference, Permissive |
| Main software | OSCP toolset, podman lab stacks (Ligolo-ng, BloodHound, CyberChef, ZAP, Mythic) | Claude Code, opencode, Blender and Godot MCP |
