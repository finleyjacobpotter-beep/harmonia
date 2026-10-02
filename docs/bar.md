# The bar

The eww bar (`home/eww.nix`, scripts in `home/eww/`). Buttons that open a
panel do so on a left click; each panel has a ✕ to close it, and clicking
the button again closes it too. Panels open on the primary display.

| On the bar | Click |
|---|---|
| **CAPS** / **NUM** | shown while Caps Lock or Num Lock is on |
| GameMode, Steam, LM Studio, VMs | shown while running; Steam and LM Studio open a panel with **Close** ([lmstudio.md](lmstudio.md)) |
| 󰍹 **2** | how many displays there are; opens the display settings window (below) |
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

The display button on the bar opens one window for all of them (also in
fuzzel as **Displays**, or `display-settings`; the button closes it again):

- **Layout**: every display that is on, drawn to scale. Drag one to move
  it; on release it snaps beside the others, lining up with their edges
  when close, so the pointer can always cross from one to the next. Click
  a display to change it in the form below.
- **On** turns the selected display on or off (the primary one stays on).
- **Resolution** lists every mode the monitor offers, biggest and fastest
  first.
- **Primary** moves the bar, and its panels, to that display.

Nothing changes until **Apply**, which sets every display in one go.
After a new resolution, or a display turned on or off, a dialog asks to
keep it and reverts by itself after 15 seconds, in case the picture is
gone. **Reset** drops what hasn't been applied yet.

What you apply is remembered per monitor (by make, model and serial, so it
follows the monitor to another port): resolutions in
`~/.local/state/eww/display-modes.json`, positions in
`~/.local/state/eww/display-layout.json`, and the primary display in
`~/.local/state/eww/primary-display`. They are applied again whenever that
monitor is connected and when sway starts. If the primary display is
unplugged, the bar moves to the first one left and comes back when it
returns.

`Super+Shift+b` hides and shows the bar on the primary display. Sway itself
has no primary display, so this only decides where the bar goes; the
resolutions and positions are ordinary `swaymsg output` settings, and anything set in
`home/sway.nix` still applies first.
