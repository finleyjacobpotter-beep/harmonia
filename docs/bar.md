# The bar

The eww bar (`home/eww.nix`, scripts in `home/eww/`). Buttons that open a
panel do so on a left click; each panel has a ✕ to close it, and clicking
the button again closes it too. Panels open on the primary display.

| On the bar | Click |
|---|---|
|  logo (top left) | opens the session panel: **Lock** (swaylock), **Log out** (exits sway) and **Power off**. `Super+Shift+e` has the same actions from the keyboard, plus suspend and reboot |
| **CAPS** / **NUM** | shown while Caps Lock or Num Lock is on |
| GameMode, Steam, LM Studio, VMs | shown while running; Steam and LM Studio open a panel with **Close** ([lmstudio.md](lmstudio.md)) |
| 󰍹 **1** 󰓎, 󰍹 **2** | one icon per display, the star marks the primary one; opens its panel (below) |
| CPU, memory | |
| 󰢮 GPU | load and temperature from `rocm-smi`; the tooltip adds VRAM use |
| 󰈀 / 󰖩 network | the shown interface with its download and upload rate, switching between bps, kbps, Mbps and Gbps; opens a panel listing every interface's rates, where **Show** picks the one on the bar (**Automatic** follows the default route) |
| 󰖂 WireGuard | active tunnels; opens the tunnel panel ([wireguard.md](wireguard.md)) |
| caffeine | stops the lock and blank timers until clicked again |
| 󰕾 volume | opens a panel with a slider, **− 5%**, **Mute** and **+ 5%**; scrolling on the icon changes the volume too |
| battery | laptops only |
| 󰥔 clock | `Wed Sep 30 14:16` and the time zone; opens the calendar ([calendar.md](calendar.md)) |

CPU, memory, GPU, network and volume each take a fixed width, sized for
their widest value (`100%`, `100% 200°C`, `999.9 kbps`), so the bar doesn't
shift as the numbers change. Shorter values are padded with spaces, which
works because the bar font is monospace.

## Displays

Every display sway sees gets an icon, numbered in sway's order; plugging in
another monitor adds its icon straight away. Clicking one opens its panel:

- **Resolution** is a dropdown of every mode the monitor offers. Picking
  one applies it at once and remembers it for that monitor (by make, model
  and serial, so it follows the monitor to another port) in
  `~/.local/state/eww/display-modes.json`. It is applied again whenever
  that monitor is connected and when sway starts.
- **Make primary** moves the bar, and the panels, to that display. It is
  remembered in `~/.local/state/eww/primary-display`; if the primary
  display is unplugged, the bar moves to the first one left and comes back
  when it returns.
- **Turn off** / **Turn on** switch a display that isn't the primary one.

`Super+Shift+b` hides and shows the bar on the primary display. Sway itself
has no primary display, so this only decides where the bar goes; the
resolutions are ordinary `swaymsg output` settings, and anything set in
`home/sway.nix` still applies first.
