"""Connected USB devices from sysfs (world-readable), for the dash's usb
tile. Names come from the device's own strings, else from usb.ids.

Flash drives (filesystems on a USB disk) are listed too, with where they are
mounted. Mount and Unmount start and stop harmonia-usb-mount@UUID, which
mounts at /mnt/UUID as root (modules/nixos/usb-mount.nix); the disk tile
lists the mounted ones as well (disk.py).

Usage: eww-usb               print once: {"count": N (hubs left out),
                             "devices": [...], "drives": [...]}
       eww-usb watch         print, then again whenever a USB device or
                             drive comes or goes, or a mount changes
       eww-usb mount UUID    mount a flash drive at /mnt/UUID
       eww-usb unmount UUID  unmount it
       eww-usb open UUID     open it in ranger
"""

import json
import os
import re
import select
import subprocess
import sys
from pathlib import Path

from common import config, output, read
from procs import size

DEVICES = Path("/sys/bus/usb/devices")
# hwdata's usb.ids (home/eww.nix).
USB_IDS = config().get("usbIds", "/usr/share/hwdata/usb.ids")

# (icon, kind) per interface class; HID is split by protocol below.
CLASSES = {
    "01": ("󰓃", "Audio"),
    "02": ("󰏲", "Communications"),
    "03": ("󰌌", "Input"),
    "06": ("󰄀", "Imaging"),
    "07": ("󰐪", "Printer"),
    "08": ("󰋊", "Storage"),
    "09": ("󰕓", "Hub"),
    "0a": ("󰏲", "Communications"),
    "0b": ("󰆛", "Smart card"),
    "0e": ("󰄀", "Video"),
    "e0": ("󰂯", "Wireless"),
}
GENERIC = ("󰕓", "Device")


def load_ids() -> dict:
    """usb.ids as {"vvvv": name, "vvvv:pppp": name}."""
    names: dict = {}
    vendor = ""
    try:
        with open(USB_IDS, encoding="utf-8", errors="replace") as f:
            for line in f:
                if line.startswith("#") or not line.strip():
                    continue
                if line.startswith("C "):
                    break  # device classes follow the vendor list
                if line[0] != "\t":
                    vendor = line[:4]
                    names[vendor] = line[4:].strip()
                elif line[1] != "\t" and vendor:
                    names[f"{vendor}:{line[1:5]}"] = line[5:].strip()
    except OSError:
        pass
    return names


def speed_text(mbps: str) -> str:
    return {
        "1.5": "1.5 Mb/s (USB 1)",
        "12": "12 Mb/s (USB 1)",
        "480": "480 Mb/s (USB 2)",
        "5000": "5 Gb/s (USB 3)",
        "10000": "10 Gb/s (USB 3)",
        "20000": "20 Gb/s (USB 3)",
    }.get(mbps, f"{mbps} Mb/s" if mbps else "")


def kind(dev: Path) -> tuple:
    """The device's icon and kind, from its interfaces (or the device class)."""
    interfaces = []
    for intf in sorted(dev.glob(f"{dev.name}:*")):
        interfaces.append((read(intf / "bInterfaceClass"), read(intf / "bInterfaceProtocol")))
    if not interfaces:
        interfaces = [(read(dev / "bDeviceClass"), read(dev / "bDeviceProtocol"))]
    if any(c == "0b" for c, _ in interfaces):
        return ("󰌆", "Security key")  # YubiKeys are also keyboards
    protocols = {p for c, p in interfaces if c == "03"}
    if {"01", "02"} <= protocols:
        return ("󰌌", "Keyboard and mouse")
    if "01" in protocols:
        return ("󰌌", "Keyboard")
    if "02" in protocols:
        return ("󰍽", "Mouse")
    # The first interface with a known class, so a webcam's audio doesn't win.
    for c, _ in interfaces:
        if c in CLASSES:
            return CLASSES[c]
    return GENERIC


def devices() -> list:
    ids = None
    found = []
    # Devices are named like 1-2 or 1-2.4; root hubs are usb1, interfaces 1-2:1.0.
    for dev in DEVICES.glob("*-*"):
        if ":" in dev.name:
            continue
        vid, pid = read(dev / "idVendor"), read(dev / "idProduct")
        if not vid:
            continue
        vendor, product = read(dev / "manufacturer"), read(dev / "product")
        if not vendor or not product:
            if ids is None:
                ids = load_ids()
            vendor = vendor or ids.get(vid, "")
            product = product or ids.get(f"{vid}:{pid}", "")
        icon, what = kind(dev)
        found.append({
            "port": dev.name,
            "bus": read(dev / "busnum"),
            "name": product or vendor or f"{vid}:{pid}",
            "vendor": vendor if product else "",
            "id": f"{vid}:{pid}",
            "kind": what,
            "icon": icon,
            "speed": speed_text(read(dev / "speed")),
        })
    # Bus, then the port path numerically: 1-2 before 1-10, 1-2 before 1-2.1.
    found.sort(key=lambda d: [int(n) for n in d["port"].replace("-", ".").split(".") if n.isdigit()])
    return found


def unit(uuid: str) -> str:
    """The mount unit's name: the UUID escaped as systemd does (- is \\x2d)."""
    escaped = uuid.replace("-", "\\x2d")
    return f"harmonia-usb-mount@{escaped}.service"


def drives() -> list:
    """Each filesystem on a USB disk: the disk's partitions, or the disk itself
    when it is formatted whole."""
    try:
        tree = json.loads(output(
            "lsblk", "-J", "-b", "-o",
            "NAME,TRAN,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINT,FSAVAIL,FSSIZE,FSUSED,MODEL,VENDOR",
        ) or "{}")
    except ValueError:
        return []
    found = []
    for disk in tree.get("blockdevices", []):
        if disk.get("tran") != "usb":
            continue
        model = " ".join(p for p in ((disk.get("vendor") or "").strip(), (disk.get("model") or "").strip()) if p)
        for part in disk.get("children") or [disk]:
            uuid = part.get("uuid") or ""
            # Encrypted, swap and unformatted space can't be mounted here.
            if not re.fullmatch(r"[A-Za-z0-9-]+", uuid) or part.get("fstype") in (None, "", "swap", "crypto_LUKS"):
                continue
            mount = part.get("mountpoint") or ""
            total, used = int(part.get("fssize") or 0), int(part.get("fsused") or 0)
            found.append({
                "uuid": uuid,
                "device": part["name"],
                "name": model or part["name"],
                "label": part.get("label") or "",
                "size": size(int(part.get("size") or 0)),
                "type": part["fstype"],
                "mount": mount,
                # Only what harmonia-usb-mount mounted can be unmounted here.
                "ours": mount == f"/mnt/{uuid}",
                "target": f"/mnt/{uuid}",
                "free": f"{size(int(part.get('fsavail') or 0))} free" if mount else "",
                "text": f"{size(used)} of {size(total)}" if mount else "",
                "pct": round(used / total * 100) if mount and total else 0,
            })
    return found


def listing() -> str:
    found = devices()
    # Hubs are listed on the dash, but its count is of what's plugged into them.
    count = sum(d["kind"] != "Hub" for d in found)
    return json.dumps({"count": count, "devices": found, "drives": drives()},
                      separators=(",", ":"), ensure_ascii=False)


def notify(text: str) -> None:
    output("notify-send", "-a", "harmonia", "USB drive", text)


def mount(uuid: str) -> None:
    result = subprocess.run(["systemctl", "start", unit(uuid)], capture_output=True, text=True)
    if result.returncode != 0:
        notify(f"Couldn't mount it: {result.stderr.strip() or 'see journalctl -u ' + unit(uuid)}")


def unmount(uuid: str) -> None:
    # A failed unmount (something still has a file open) leaves the unit
    # stopped but the drive mounted: start it again, which sees the mount and
    # does nothing, so the stop tries again.
    if os.path.ismount(f"/mnt/{uuid}"):
        subprocess.run(["systemctl", "start", unit(uuid)], capture_output=True)
    subprocess.run(["systemctl", "stop", unit(uuid)], capture_output=True)
    if os.path.ismount(f"/mnt/{uuid}"):
        notify(f"/mnt/{uuid} is busy: close what has files open on it, then unmount again.")


def open_drive(uuid: str) -> None:
    subprocess.Popen(
        ["alacritty", "--class", "ranger", "-e", "ranger", f"/mnt/{uuid}"],
        start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


def watch() -> None:
    last = listing()
    print(last, flush=True)
    try:
        monitor = subprocess.Popen(
            ["udevadm", "monitor", "--udev", "--subsystem-match=usb/usb_device", "--subsystem-match=block"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        )
    except OSError:
        return
    # udev events for devices and drives; /proc/self/mounts turns readable
    # with an error flag whenever something is mounted or unmounted.
    mounts = open("/proc/self/mounts")
    poller = select.poll()
    poller.register(monitor.stdout, select.POLLIN)
    poller.register(mounts, select.POLLPRI | select.POLLERR)
    while True:
        for fd, _ in poller.poll():
            if fd == monitor.stdout.fileno():
                if not os.read(fd, 65536):
                    return  # udevadm exited
            else:
                mounts.seek(0)
                mounts.read()
        # Print only when the listing changed.
        now = listing()
        if now != last:
            print(now, flush=True)
            last = now


def main(args: list[str]) -> None:
    command, rest = (args[0], args[1:]) if args else ("", [])
    if command == "watch":
        watch()
    elif command in ("mount", "unmount", "open") and rest and re.fullmatch(r"[A-Za-z0-9-]+", rest[0]):
        {"mount": mount, "unmount": unmount, "open": open_drive}[command](rest[0])
    else:
        print(listing())


if __name__ == "__main__":
    main(sys.argv[1:])
