"""Connected USB devices from sysfs (world-readable), for the bar button and
its panel. Names come from the device's own strings, else from usb.ids.

Usage: eww-usb        print once: {"count": N (hubs left out), "devices": [...]}
       eww-usb watch  print, then again whenever a USB device comes or goes
"""

import json
import subprocess
import sys
from pathlib import Path

DEVICES = Path("/sys/bus/usb/devices")
# home/eww.nix replaces this with the usb.ids from hwdata.
USB_IDS = "/usr/share/hwdata/usb.ids"

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


def read(path: Path) -> str:
    try:
        return path.read_text().strip()
    except OSError:
        return ""


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


def listing() -> str:
    found = devices()
    # Hubs are listed in the panel, but the bar counts what's plugged into them.
    count = sum(d["kind"] != "Hub" for d in found)
    return json.dumps({"count": count, "devices": found},
                      separators=(",", ":"), ensure_ascii=False)


def watch() -> None:
    last = listing()
    print(last, flush=True)
    try:
        monitor = subprocess.Popen(
            ["udevadm", "monitor", "--udev", "--subsystem-match=usb/usb_device"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True,
        )
    except OSError:
        return
    # One line per add/remove event; print only when the list changed.
    for line in monitor.stdout:
        if not line.startswith("UDEV"):
            continue
        now = listing()
        if now != last:
            print(now, flush=True)
            last = now


if __name__ == "__main__":
    if sys.argv[1:] == ["watch"]:
        watch()
    else:
        print(listing())
