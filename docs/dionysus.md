# Dionysus

Dionysus is harmonia's Sway desktop with the coding and creative toolset built
straight into the host, and **no microVMs**. Where harmonia keeps those tools
in a microVM (Zelus) or in flatpak sandboxes, Dionysus runs them natively, so
the whole configuration builds and boots on both **aarch64-linux** and
**x86_64-linux** — handy for a VM on an Apple-silicon machine as much as on an
x86 one.

## What it is

- The same Miami Wind Sway environment as harmonia: `modules/nixos/desktop.nix`
  plus the shared `home/*.nix` modules (sway, eww bar, alacritty, tmux, bash,
  ranger, neovim, GTK theme, the TUI tools, the keymap contract and the local
  secrets store).
- The dev toolset on the host (`home/dionysus/dev.nix`):
  - **Blender** and **Godot 4**;
  - **opencode** (with oh-my-openagent, and a local LM Studio provider at
    `127.0.0.1:1234` if you run one);
  - **Claude Code**;
  - the **Blender and Godot MCP servers** (pinned, run through `uvx`), wired
    into both agents;
  - the **Rust command-line tools** (ripgrep, fd, bat, eza, …) with the usual
    aliases in interactive shells only;
  - `uv`, Node, Python and a C toolchain.
- Flatpak apps (`modules/nixos/flatpak.nix` and `element.nix`, the same
  tightened sandboxes as harmonia):
  - **Element** (Matrix) — on both architectures (Flathub ships x86_64 and
    aarch64 builds);
  - **Firefox** — on both architectures, with the same vertical tabs,
    uBlock Origin, Vimium and theming as harmonia.
- Guest tools for both hypervisors, on both architectures, side by side:
  - **SPICE** (virt-manager/QEMU): `spice-vdagentd` for clipboard and display
    resizing, `spice-webdavd` for the shared folder;
  - **VirtualBox guest additions** (x86_64, or VirtualBox 7.1+ on Apple
    silicon): display resizing, shared clipboard, drag and drop, and `vboxsf`
    shared folders (`d` is in the `vboxsf` group). The VirtualBox services
    only start when the hypervisor is VirtualBox, so they sit idle under
    QEMU. Give the VM the **VMSVGA** graphics controller and enable **EFI**
    (Dionysus boots with systemd-boot).
- Login `d`, initial password `changeme` (change it after first boot).

## What harmonia has that Dionysus leaves out

Everything architecture-specific or flatpak-only, so both arches build:

- the **Nike** and **Zelus** microVMs and all the host-side microVM wiring;
- **Steam** and the **gaming** stack (32-bit, x86-only);
- the **LM Studio** and **studio** (Blender/Godot/opencode) flatpaks — those
  tools are native here — and the Lutris/LACT flatpak theme sync;
- 32-bit graphics (`hardware.graphics.enable32Bit`), which has no aarch64 Mesa.

Set `ANTHROPIC_API_KEY` (or use opencode's `/connect`) to reach Claude from
opencode.

## Building

```sh
# On an x86_64 host:
sudo nixos-rebuild switch --flake .#dionysus

# On an aarch64 host:
sudo nixos-rebuild switch --flake .#dionysus-aarch64

# Try it as a throwaway VM (matches your current architecture):
nixos-rebuild build-vm --flake .#dionysus && ./result/bin/run-dionysus-vm
```

Replace `hosts/dionysus/hardware-configuration.nix` with the output of
`nixos-generate-config` on real hardware; the checked-in file is an
architecture-neutral QEMU-guest placeholder so the flake evaluates and boots
as a plain UEFI VM.
