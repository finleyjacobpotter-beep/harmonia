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
- **The dash**, workspace 10: everything else, as tiles in five rows: the
  machine, the system, what is plugged in, your work, and right now.

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
scroll inside the tile. Every summary has a fixed number of lines: lists
are capped (8 projects, tmux sessions and downloads; 3 displays,
notifications, clipboard copies and games; 2 flash drives and 2 of today's
events) and padded when shorter, and lines that would come and go (the
player, a VPN, a camera, a pending reboot) are always there or share a
line. So a tile keeps its height, and the dash its layout, as things
change; the open tile lists everything.

| Key | Tile | Summary | Open |
|---|---|---|---|
| `c` | **cpu** | usage, package temperature, power draw, clock, load, a bar per thread | the model, thread count, current and top clock, governor, power draw (package and cores, averaged over 3 seconds), load and uptime, processes and threads, a tall bar per thread (hover for its clock), every temperature sensor, and the busiest processes since the last reading (100% is one thread) |
| `m` | **memory** | used of total, swap | used by programs, cache and buffers, shared memory, free, available, swap, zswap's pool, memory waiting to be written to disk, and the processes with the most resident memory |
| `f` | **disk** | space used on `/`, reads and writes per second across disks, how busy the busiest is | every filesystem on a disk (`/`, `/boot`, …) with its device, type, space used and free; each disk's model, size, temperature, how busy it is, and its reads and writes per second (`home/eww/disk.py`); then mounted [flash drives](#flash-drives), each with **Open in ranger** and **Unmount** |
| `g` | **gpu** | the main GPU's load, temperature and power draw against its cap, two thin meters per GPU (load, then VRAM; the main GPU's in red and purple) | [GPUs](#gpus) |
| `n` | **network** | the shown interface, its address and rates (bps to Gbps), a coloured asterisk per kind of VPN that is up ([vpn.md](vpn.md)), whether a VPN is up, and the last connectivity test | [connectivity](#connectivity) and the programs sending and receiving right now (nethogs: each one's upload and download per second); then the VPNs with **Connect** / **Disconnect**, then every interface's rates, where **Show** picks the one in the summary (**Automatic** follows the default route) |
| `v` | **virtualization** | each microVM, running or not, and its firewall mode; how many containers run | the microVMs ([Nike](#nike)), then the [containers](#containers) |
| `y` | **system** | failed units, journal errors in the last hour, the NixOS generation and its age (with a note when a reboot is needed) | each failed unit (yours have **Restart**; the system's need `sudo systemctl`), the latest journal errors, the NixOS version, generation, kernel and whether a new kernel or initrd waits for a reboot, how old each flake input's pinned commit is (orange after 60 days, from `flake.lock` at build time), and the Nix store's disk with **Collect garbage**, which removes what nothing uses (old generations stay until removed as root). Then every listening port, the program behind it (without root, only your own are named) and whether anything outside can reach it: **this machine only**, **open** to everyone or on an interface, as the NixOS firewall allows, or **blocked by the firewall**; who is logged in and from where; and failed sudo and SSH logins over the last day |
| `i` | **usb** | how many USB devices, and up to 2 flash drives and where they are mounted | the [flash drives](#flash-drives) with **Mount**, **Open in ranger** and **Unmount**, then every USB device, hubs included, in port order |
| `d` | **displays** | up to 3 displays and their modes (★ the primary) | the display settings ([below](#displays)) |
| `s` | **sound** | the player's title, artist and progress while it plays or is paused, otherwise "Nothing playing" (and ▶ or ⏸ by the volume in the header); the default output and its volume (scroll to change it), the microphone and whether a camera is in use, Bluetooth; the microphone while something records from it and a camera in use show in red | while a player plays or is paused, the track, album, player and position with ⏮ **Pause**/**Play** ⏭ (playerctl); the output's slider, **− 5%**, **Mute** and **+ 5%**; the microphone's slider and **Mute**, and which programs are recording from it; each camera and which programs use it; Bluetooth on or off, and each paired device with its battery and **Connect** / **Disconnect** (pair new ones in bluetuith, `Super+o u`) |
| `p` | **projects** | how many git repositories are in `~/Projects` and `~/nike-share/Projects` (or one folder below), and the 8 with the latest commits, those with changes in orange | each one's branch, uncommitted changes, commits ahead and behind its upstream (as of the last fetch), and last commit, with **tmux** (a session named after it, there) and **nvim** |
| `x` | **tmux** | up to 8 sessions, attached ones green | each session's windows, with the program running and the folder, and **Attach** (in a new terminal) and **Kill** |
| `w` | **downloads** | the 8 newest files in `~/Downloads/firefox`, Firefox's only folder; `↓` while still downloading | each file's size and age, with **Show** (in ranger), **To Documents**, **To Projects** and **Bin** (the trash, so it can come back) |
| `u` | **secrets** | Bitwarden locked or unlocked, SSH keys loaded, YubiKey | Bitwarden with **Unlock** (a small terminal running `bw-unlock`) or **Lock**; ssh-agent's keys with **Add keys** (`ssh-add`) and **Forget all**; passphrases gpg-agent has cached, with **Forget**; the YubiKey, the sops age key and the last `secrets-backup`. Nothing on it reads a secret, only whether one is there ([secrets.md](secrets.md)) |
| `t` | **time** | the date and exact time, the time zone, and today's first 2 events | the time zone and the calendar ([calendar.md](calendar.md)) |
| `r` | **games** | how many Lutris and Steam games are installed and the 3 last played; GameMode and Steam while running | each game's runner and play time with **Play**, and **Close Steam** |
| `a` | **notifications** | focus on or off, how many are waiting and how many urgent, the titles of the first 3 | **Focus** (mako's do-not-disturb mode: no popups at all, but notifications still collect here), **Clear not urgent** (all but the critical ones), **Clear all**, **Restore last**, and each notification with its text, app and ✕ |
| `b` | **clipboard** | how many copies the history holds, and the latest 3 | the last 30, text and images: click one to copy it again, ✕ to drop it, **Clear all**. The history (cliphist) is kept in memory only, `$XDG_RUNTIME_DIR/cliphist.db`, and wiped whenever the screen locks; copies an app marks as sensitive are never kept |

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
| `c` `m` `f` `g` · `n` `v` `y` · `i` `d` `s` · `p` `x` `w` `u` · `t` `r` `a` `b` | open that tile (again: close it), row by row |
| `?` | show or hide the key reminders |

The selected tile has a pink border, the open one a cyan one. When the
focus goes to another display while the dash stays on screen (pinned, say),
the open tile closes and no tile is outlined until you come back; a click
on a tile brings the focus back to the dash.

The tiles have reminders of the main keys of sway, tmux and neovim under
them (set in `home/eww.nix`; [keyboard.md](keyboard.md) has them all);
`?` hides them until the next login.

### Connectivity

The network tile's test resolves `google.com` through the system's default
resolver (systemd-resolved, and the upstream server it is using), then
traces the route there with ICMP (`mtr`, three probes per hop): each hop's
name and address and its average round trip, `*` for a hop that doesn't
answer. It runs at boot, whenever NetworkManager brings a connection up or
renews its DHCP lease, and on **Run again**.

What it and two other readings need runs outside the dash, in
`modules/nixos/dash.nix`, each with as little as it can:

- `harmonia-connectivity.service`, the test: its own throwaway user with
  only raw sockets (for ICMP). Wheel may start it without a password (Run
  again); it writes `/run/harmonia-connectivity/result.json`.
- `harmonia-cpu-power.service`, the CPU's power draw: the kernel's energy
  counters are root's alone, because read quickly they leak what the CPU
  is doing (CVE-2020-8694). It reads them as root, without network or any
  capability, and publishes only a 3-second average.
- nethogs, which the network tile runs while the dash is open: a wrapper
  only wheel can run, with the capabilities it needs to map traffic to
  every process (`cap_net_admin`, `cap_net_raw`, `cap_dac_read_search`,
  `cap_sys_ptrace`).

## Flash drives

A filesystem on a USB disk shows on the usb tile (`i`) with **Mount at
/mnt/UUID**, which mounts it at `/mnt/` and its filesystem UUID, without a
password. Mounted, it shows on the disk tile too, and either tile has
**Open in ranger** (in a new terminal) and **Unmount**. FAT, exFAT and NTFS
drives are writable by the `users` group; ext4 and other Linux filesystems
keep their own owners. If something still has a file open, Unmount says the
drive is busy and leaves it mounted. Pulling a drive out unmounts it.

Mounting is a system unit per drive, `harmonia-usb-mount@UUID` (UUID
escaped for systemd, so `1A2B-3C4D` is `1A2B\x2d3C4D`), in
`modules/nixos/usb-mount.nix`: starting it mounts, stopping it unmounts,
and polkit lets wheel do either. It only mounts filesystems on a USB disk;
its errors are in `journalctl -u 'harmonia-usb-mount@*'`. Encrypted drives
aren't offered.

## Displays

The display settings are the displays tile (`d`, or **Displays** in
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
monitor is connected and when sway starts, before eww does. A display
counts as done once sway shows its saved settings, not once they are sent,
so if sway is still setting a monitor up at login and undoes them, they are
sent again on its next change, up to three times. eww is restarted whenever
a display comes, goes or changes resolution, rotation or scale, since it
keeps drawing for the displays it started with. The watcher (`eww-dash
watch`, started by sway at login) replaces itself with the new one at the
first sway event after a rebuild installs a new `eww-dash`. What it does, and
any error it hits, is in `journalctl --user -t eww-dash` (or
`journalctl -t eww-dash`); eww's own log, its script timeouts and errors
included, is in `journalctl --user -t eww`, since the watcher starts the
eww daemon in the foreground under `systemd-cat`. A daemon started by hand
(`eww daemon`) logs to `~/.cache/eww/` instead. If the primary display is
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

The virtualization tile counts the running podman containers; open, it shows
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

Each microVM has a line on the virtualization tile; Nike ([nike.md](nike.md)) is
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
