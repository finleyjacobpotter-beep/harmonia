# Dionysus

Dionysus is harmonia's Sway desktop for a VM, with [Nike](nike.md)'s OSCP
toolset built straight into the host and **no microVMs**. Where harmonia keeps
the pentesting tools in a microVM (Nike), Dionysus runs the same packages and
podman lab stacks natively, so the whole configuration builds and boots on
both **aarch64-linux** and **x86_64-linux**: handy for a VM on an
Apple-silicon machine as much as on an x86 one.

## What it is

- The same Miami Wind Sway environment as harmonia: `modules/nixos/desktop.nix`
  plus the shared `home/*.nix` modules (sway, eww bar, alacritty, tmux, bash,
  ranger, neovim, GTK theme, the TUI tools, the keymap contract and the local
  secrets tools).
- Nike's pentesting toolset, native ([`nike/tools.nix`](../nike/tools.nix)
  and [`nike/labs.nix`](../nike/labs.nix), imported by
  [`hosts/dionysus/default.nix`](../hosts/dionysus/default.nix)):
  - the OSCP package set, the same as on Nike ([Nike](nike.md) lists it);
  - the podman lab stacks: CyberChef, ZAP, BloodHound, Mythic and Ligolo-ng;
  - OpenVPN for lab connection packs, and the `tun` module Ligolo-ng needs.
- Command-line tooling on the host ([`home/dionysus/dev.nix`](../home/dionysus/dev.nix)):
  - the **Rust command-line tools** (ripgrep, fd, bat, eza, …) with the usual
    aliases in interactive shells only;
  - `uv`, Node, Python and a C toolchain.
- No AI coding agents: Claude Code and pi are not on Dionysus, so it
  allows no unfree packages beyond the Tulasi icons.
- A git identity of its own: `Dionysus <dionysus@localhost.local>`.
- Flatpak apps (`modules/nixos/flatpak.nix` and `element.nix`, the same
  tightened sandboxes as harmonia):
  - **Element** (Matrix), on both architectures (Flathub ships x86_64 and
    aarch64 builds);
  - **Firefox**, on both architectures, with the same vertical tabs,
    uBlock Origin, Vimium and theming as harmonia.
- Guest tools for both hypervisors, on both architectures, side by side:
  - **SPICE** (virt-manager/QEMU): `spice-vdagentd` for clipboard and display
    resizing, `spice-webdavd` for the shared folder;
  - **VirtualBox guest additions** (x86_64, or VirtualBox 7.1+ on Apple
    silicon): display resizing, shared clipboard, drag and drop, and `vboxsf`
    shared folders (`d` is in the `vboxsf` group). The VirtualBox services
    only start when the hypervisor is VirtualBox, so they sit idle under
    QEMU. Give the VM the **VMSVGA** graphics controller and enable **EFI**
    (Dionysus boots with systemd-boot). See "VirtualBox on a Mac" below.
  - A VirtualBox shared folder named `share` is automounted at `/mnt/share`,
    owned by `d`. Without one (under QEMU, say) the mount is skipped and boot
    carries on.
- Sway renders in software with a software cursor (`WLR_RENDERER=pixman`,
  `WLR_NO_HARDWARE_CURSORS=1`), since VM display adapters have no usable
  GPU or cursor plane.
- Login `d`, initial password `changeme` (change it after first boot).

## What harmonia has that Dionysus leaves out

Everything architecture-specific or that needs a microVM, so both arches
build:

- the **Nike** microVM and all the host-side microVM wiring
  (Nike's tools are here natively instead);
- **Steam** and the **gaming** stack (32-bit, x86-only);
- **Blender** and **Godot**, the game dev agents and the local model server;
- the Lutris/LACT flatpak theme sync;
- 32-bit graphics (`hardware.graphics.enable32Bit`), which has no aarch64 Mesa.

## Building

```sh
# On an x86_64 host:
sudo nixos-rebuild switch --flake .#dionysus

# On an aarch64 host:
sudo nixos-rebuild switch --flake .#dionysus-aarch64

# Try it as a throwaway VM (use .#dionysus-aarch64 on aarch64):
nixos-rebuild build-vm --flake .#dionysus && ./result/bin/run-dionysus-vm
```

Both outputs set the hostname `dionysus`, so a bare `--flake .` always picks
the x86_64 one and fails on aarch64 with "a 'x86_64-linux' with features {}
is required to build ..., but I am a 'aarch64-linux'". Once installed, the
`rebuild` alias names the right output for the machine.

## VirtualBox on a Mac

- **Display:** Settings > Display: graphics controller **VMSVGA**, 128 MB
  video memory, **3D acceleration off** (not supported on Apple silicon).
- **Keyboard access:** System Settings > Privacy & Security: allow
  VirtualBox under **Accessibility** and **Input Monitoring**, then restart
  VirtualBox.
- **Super key:** VirtualBox's default Host key on macOS is Left ⌘, which is
  the key the guest sees as Super, so Sway never gets it. In VirtualBox
  Settings > Input > Virtual Machine, set **Host Key Combination** to Right ⌘
  (or Right ⌥) and tick **Auto Capture Keyboard**. Clicking into the VM
  then captures the keyboard; the Host key releases it.
- **Mouse:** with the guest additions the pointer moves in and out freely.
  To capture it instead, turn off Input > **Mouse Integration** (Host+I);
  a click captures and the Host key releases.

Replace `hosts/dionysus/hardware-configuration.nix` with the output of
`nixos-generate-config` on real hardware; the checked-in file is an
architecture-neutral QEMU-guest placeholder so the flake evaluates and boots
as a plain UEFI VM.
