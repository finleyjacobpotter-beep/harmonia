# The bar

The eww bar: the layout is `home/eww/eww.yuck`, the styles
`home/eww/eww.scss`, and the scripts behind the widgets `home/eww/*.py`
(packaged together as `harmonia-bar`). `home/eww.nix` fills in the store
paths, the palette and the widgets for the host's microVMs. Buttons that open a
panel do so on a left click; each panel has a ✕ to close it, and clicking
the button again closes it too. Panels open on the primary display.

| On the bar | Click |
|---|---|
|  logo (top left) | opens the session panel: **Lock** (swaylock), **Log out** (exits sway) and **Power off**. `Super+Shift+e` has the same actions from the keyboard, plus suspend and reboot |
| **CAPS** / **NUM** | shown while Caps Lock or Num Lock is on |
| GameMode, Steam | shown while running; Steam opens a panel with **Close** |
| 󰚩 local model | harmonia only: grey while stopped, yellow while it starts or loads, pink while it serves `ai`; opens a panel with **Start** or **Stop** ([llama-server.md](llama-server.md)) |
| Nike, Zelus | always shown: running or not, and the firewall mode; each opens its VM panel (below) |
| 󰍹 **2** | how many displays there are; opens the display settings window (below) |
| CPU, memory | |
| 󰢮 GPU | load and temperature from `rocm-smi`; the tooltip adds VRAM use |
| 󰈀 / 󰖩 network | the shown interface with its download and upload rate, switching between bps, kbps, Mbps and Gbps, and a stack of coloured asterisks beside the icon, one per kind of VPN that is up ([vpn.md](vpn.md)); opens a panel listing the VPNs with **Connect** / **Disconnect**, then every interface's rates, where **Show** picks the one on the bar (**Automatic** follows the default route) |
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

## Nike and Zelus

Each microVM has the same 󰒋 badge ([nike.md](nike.md), [zelus.md](zelus.md)).
The icon is grey while the VM is stopped, and orange (Nike) or cyan (Zelus)
while it runs, and the badge ends with the VM's firewall mode: **open**
(permissive), **lock** in red, or **oscp**, **htb** or **local** in purple.
The mode keeps its space when it changes, so the bar doesn't shift. While a
VM's VPN is up, the network button shows an asterisk in the VM's colour
([vpn.md](vpn.md)). Hover the badge to see whether Nike's traffic actually
leaves through the tunnel.

Clicking a badge opens the VM's panel:

- **Start / Stop** (top right): starts or stops `microvm@<vm>`, allowed
  without a password. It reads **Starting…** or **Stopping…** until
  systemd is done.
- **VPN outbound** (Nike only): the interface Nike's internet traffic leaves
  through, the tunnel's address and the VPN server, and the tunnel's download
  and upload rates.
- **System**: the VM's CPU (100% means all its vCPUs), memory, and `/home`
  disk use, its load average and uptime.
- **Firewall**: the current mode; click it for the list of modes, and click
  one to switch to it (`vm-firewall`, allowed without a password).

Each VM measures its own numbers (`nike/status.py`, every 2 seconds) and
writes them to `/var/lib/<vm>/status` on the host; the bar reads them every 3
seconds (`home/eww/microvm.py`). While a VM is still booting, its panel says it
is starting.
