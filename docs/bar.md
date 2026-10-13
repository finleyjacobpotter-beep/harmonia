# The bar and the dash

Two eww windows, laid out in `home/eww/eww.yuck`, styled in
`home/eww/eww.scss`, with the scripts behind them in `home/eww/*.py`
(packaged together as `harmonia-bar`). `home/eww.nix` fills in the store
paths, the palette, the wallpaper and the widgets for the host's microVMs.

- **The bar**, along the top of the primary display on every workspace but
  the dash: the workspaces (the focused one in pink, an urgent one in red),
  the sway mode and its keys while one is active, the focused window's
  title, and the time in words only (`quarter past two`). Hover it for the
  exact time; click it for the calendar on the dash, which shows the exact
  time.
- **The dash**, workspace 10: everything else, as thirteen tiles in four rows.

## The dash

`Super+0` goes to the dash, a workspace named `10:dash` (shown as **dash**
on the bar). It belongs to the primary display, and sway starts on it. No
window stays there: one opened on the dash (from fuzzel, say) is moved to
the last workspace you were on, and you follow it. `Super+Shift+0` does
nothing, since there is nothing to move there.

### Pinning the dash to a display

The 󰐃 button at the top of the dash pins it to the display it is on, and
shows that display's name while pinned (click again to unpin). A pinned dash
keeps its display to itself: every other workspace there moves to another
display, so `Super+1…9` from the dash opens or shows workspaces on the other
monitor while the dash stays on screen. Unpinned, the dash shares the
primary display like any workspace, and sway opens a new workspace on the
display you are focused on, which then covers the dash. The pin is
remembered per monitor (by make, model and serial) in
`~/.local/state/eww/dash-display`; with only one display connected it does
nothing.

### The bar's switch and the workspaces

The **bar on/off** button at the top turns the bar off everywhere, or back
on (as `Super+Shift+b` does); it is remembered in
`~/.local/state/eww/bar-hidden`. While the dash covers the primary display,
the bar moves to another one.

Under it, every workspace: the ones on screen bright, the focused one pink.
Click one to go there.

### How it works

`home/eww/dash.py` runs from sway's startup and keeps it all in step: it
opens the dash while its workspace is on screen and closes the bar there,
sends windows away, and switches sway into the dash's key mode while the
dash is focused. eww only reads the numbers while the dash is open, so it
costs nothing on the other workspaces.

### Layout

The dash is a square, and the wallpaper is drawn beside it: on a landscape
display the dash fills the left half (a square as tall as the display, or
as wide as the half, whichever is smaller) and the wallpaper is centred in
the right half; on a vertical display the dash is on the top half and the
wallpaper below. The other workspaces have a plain background.

If that square would be under 640 pixels a side, the wallpaper is dropped
and the dash fills the whole display; if the display is under 640 pixels
even then, the dash scrolls.

### Tiles

Each tile shows a headline number and a summary. Opening one (a click on
its header, or its key) expands it to show everything about it: the open
tile's row grows while the others flatten to their headers, and the tiles
beside it narrow to theirs, so the dash keeps its shape. Long details
scroll inside the tile.

| Key | Tile | Summary | Open |
|---|---|---|---|
| `c` | **cpu** | usage, package temperature, clock, load, a bar per thread | the model, thread count, current and top clock, governor, load and uptime, processes and threads, a tall bar per thread (hover for its clock), every temperature sensor, and the busiest processes since the last reading (100% is one thread) |
| `m` | **memory** | used of total, swap | used by programs, cache and buffers, shared memory, free, available, swap, zswap's pool, memory waiting to be written to disk, and the processes with the most resident memory |
| `f` | **disk** | space used on `/`, reads and writes per second across disks, how busy the busiest is | every filesystem on a disk (`/`, `/boot`, …) with its device, type, space used and free; each disk's model, size, temperature, how busy it is, and its reads and writes per second (`home/eww/disk.py`) |
| `g` | **gpu** | the main GPU's load and temperature, two thin meters per GPU (load, then VRAM; the main GPU's in red and purple) | [GPUs](#gpus) |
| `n` | **network** | the shown interface, its address and rates (bps to Gbps), and a coloured asterisk per kind of VPN that is up ([vpn.md](vpn.md)) | the VPNs with **Connect** / **Disconnect**, then every interface's rates, where **Show** picks the one in the summary (**Automatic** follows the default route) |
| `p` | **containers** | how many podman containers run, and their names | [Containers](#containers) |
| `v` | **microvms** | each microVM, running or not, and its firewall mode | [Nike](#nike) |
| `y` | **system** | failed units, journal errors in the last hour, the NixOS generation and its age, and a note when a reboot is needed | each failed unit (yours have **Restart**; the system's need `sudo systemctl`), the latest journal errors, the NixOS version, generation, kernel and whether a new kernel or initrd waits for a reboot, how old each flake input's pinned commit is (orange after 60 days, from `flake.lock` at build time), and the Nix store's disk with **Collect garbage**, which removes what nothing uses (old generations stay until removed as root) |
| `u` | **secrets** | Bitwarden locked or unlocked, SSH keys loaded, YubiKey | Bitwarden with **Unlock** (a small terminal running `bw-unlock`) or **Lock**; ssh-agent's keys with **Add keys** (`ssh-add`) and **Forget all**; passphrases gpg-agent has cached, with **Forget**; the YubiKey, the KeePassXC database, the sops age key and the last `secrets-backup`. Nothing on it reads a secret, only whether one is there ([secrets.md](secrets.md)) |
| `a` | **notifications** | focus on or off, how many are waiting and how many urgent, their titles | **Focus** (mako's do-not-disturb mode: no popups at all, but notifications still collect here), **Clear not urgent** (all but the critical ones), **Clear all**, **Restore last**, and each notification with its text, app and ✕ |
| `d` | **devices** | each display and its mode (★ the primary), the USB count | the display settings ([below](#displays)), and every USB device, hubs included, in port order |
| `s` | **sound** | the default output and its volume (scroll to change it), the microphone, whether a camera is in use, Bluetooth; anything recording shows in red | the output's slider, **− 5%**, **Mute** and **+ 5%**; the microphone's slider and **Mute**, and which programs are recording from it; each camera and which programs use it; Bluetooth on or off, and each paired device with its battery and **Connect** / **Disconnect** (pair new ones in bluetuith, `Super+o u`) |
| `t` | **time** | the date and exact time, and the time zone | the time zone and the calendar ([calendar.md](calendar.md)) |

Above the tiles: **CAPS** / **NUM** while on, GameMode and Steam while
running (✕ quits Steam), the battery on laptops, the bar's switch, the
pin, caffeine (stops the lock and blank timers until clicked again), and
**Lock**, **Log out** and **Power off**. `Super+Shift+e` has the same actions, plus suspend and reboot.

### Keys

On the dash sway is in its **dash** mode, so bare keys reach the dash and
not a window (there is none). Every `Super` key works as anywhere else; the
mode ends as soon as you leave the dash. As in btop, each tile's key is
shown on it in a block, and the line under the tiles lists them all.

| Key | |
|---|---|
| `h` `j` `k` `l` (or the arrows) | select the tile left, below, above, right; with one open, open that one instead |
| `e`, `Return` or `Space` | open or close the selected tile |
| `Esc` | close the open tile |
| `c` `m` `f` `g` `n` `p` `v` `y` `u` `a` `d` `s` `t` | open that tile (again: close it) |

The selected tile has a pink border, the open one a cyan one.

Under the tiles are reminders of the main keys of sway, tmux and neovim
(set in `home/eww.nix`; [keyboard.md](keyboard.md) has them all).

## Displays

The display settings are part of the devices tile (`d`, or **Displays** in
fuzzel, which opens it), worked by `home/eww/display-edit.py`:

- **The map**: every display that is on, drawn to scale where it sits, the
  picked one with a pink border and the primary one's number in cyan. Click
  one, or its name under the map, to pick it; a display that is off is only
  under the map.
- **On / Off** turns the picked display on or off (the primary one, and the
  last one on, stay on). **Make primary** moves the bar and the dash there.
- **Resolution** lists every mode the monitor offers, biggest and fastest
  first.
- **Rotation**: **Landscape**, **Portrait ↻** (90° clockwise),
  **Upside down** or **Portrait ↺** (90° counter-clockwise), whichever way
  the monitor is turned. Displays right of or below it move with its new
  edge. On its side, the dash sits above the wallpaper.
- **Place** puts the picked display left of, right of, above or below
  another one, with their shared edges lined up at the **start** (top or
  left), **centre** or **end**. Anything it would overlap moves aside, and
  the layout starts at 0,0 again.

Changes are a draft until **Apply**, which sets every display in one go;
**Reset** drops the draft. After a new resolution or rotation, or a display
turned on or off, the dash asks to **Keep** them and puts the old ones back
by itself after 15 seconds, in case the picture is gone.

What you apply is remembered per monitor (by make, model and serial, so it
follows the monitor to another port): resolutions in
`~/.local/state/eww/display-modes.json`, rotations in
`~/.local/state/eww/display-rotation.json`, positions in
`~/.local/state/eww/display-layout.json`, and the primary display in
`~/.local/state/eww/primary-display`. They are applied again whenever that
monitor is connected and when sway starts. If the primary display is
unplugged, the bar moves to the first one left and comes back when it
returns; the dash moves the next time you open it.

Sway itself has no primary display, so this only decides where the bar and
the dash go; the
resolutions, rotations and positions are ordinary `swaymsg output` settings, and anything set in
`home/sway.nix` still applies first.

## GPUs

The open gpu tile lists every AMD GPU `rocm-smi` sees, read every 3
seconds (`home/eww/gpu.py`):

- **Automatic** puts the GPU with the most VRAM in the summary (the RX 9070
  on harmonia). **Set main** on a GPU puts that one there instead; it is
  remembered in `~/.local/state/eww/gpu-main` (by PCI address), and if that
  GPU goes away the dash falls back to Automatic.
- Each GPU: its name (from hwdata's `pci.ids`), chip, PCI address and link,
  then meters for **Load**, **VRAM** (used/total) and **Memory bus**
  activity, its edge, hotspot and memory temperatures, power draw against
  its cap, fan speed, core and memory clocks, and the displays plugged into
  it.

The main GPU only decides what the summary shows; which card renders the
desktop is up to sway.

## Containers

The containers tile counts the running podman containers; open, it shows
each one, read every 5 seconds (`home/eww/pods.py`): its name and pod (if
it is in one), whether it is yours or the system's (root's), its image name
and ID, its container ID, status and restarts, CPU and memory use, network
and disk I/O, PIDs, published ports and mounted volumes. Stopped ones are
only counted.

Your own containers come from rootless `podman`. Root's (from
`virtualisation.oci-containers`) come through `sudo -n`, which
`modules/nixos/podman.nix` allows without a password for exactly
`podman ps -a --format json` and `podman stats --no-stream --format json`.
Not `podman inspect`, which would also print the containers' environment
variables; so root's containers show where volumes are mounted inside, but
not which host folder they come from.

## Nike

Each microVM has a line on the microvms tile; Nike ([nike.md](nike.md)) is
the only one. The 󰒋 icon is grey while the VM is stopped and in the VM's
colour (orange for Nike) while it runs, and the line ends with the VM's
firewall mode: **open** (permissive), **lock** in red, or **oscp** or
**htb** in purple. While a VM's VPN is up, the network tile shows an
asterisk in the VM's colour ([vpn.md](vpn.md)). Hover the line to see
whether Nike's traffic actually leaves through the tunnel.

Open, the tile has a part for each VM:

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
writes them to `/var/lib/<vm>/status` on the host; the dash reads them every 3
seconds (`home/eww/microvm.py`). While a VM is still booting, it says it
is starting.
