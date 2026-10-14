"""Disks for the dash's disk tile (home/eww/eww.yuck): space on each mounted
filesystem, and each physical disk's reads and writes per second since the
last reading, how busy it was, and its temperature where it reports one.

The filesystems are those on a block device (so /, /boot, /home, not tmpfs
or the Nix store's bind mount), once each; the disks are /sys/block's
entries backed by hardware (not loop, zram or device-mapper devices, whose
I/O is already counted on the disk beneath them). Mounted flash drives are
listed apart, with Open and Unmount, as on the usb tile (usb.py).
"""

import json
import os
import time
from pathlib import Path

from common import RUN_DIR, read
from procs import size
from usb import drives

SAMPLE = RUN_DIR / "eww-disk.json"
SECTOR = 512


def filesystems() -> list:
    seen, found = set(), []
    for line in read(Path("/proc/self/mounts")).splitlines():
        source, target, fstype = (line.split() + ["", "", ""])[:3]
        target = target.replace("\\040", " ")
        if not source.startswith("/dev/") or source in seen:
            continue
        seen.add(source)
        try:
            st = os.statvfs(target)
        except OSError:
            continue
        total = st.f_blocks * st.f_frsize
        free = st.f_bavail * st.f_frsize
        used = total - st.f_bfree * st.f_frsize
        if total == 0:
            continue
        pct = round(used / (used + free) * 100) if used + free else 0
        found.append(
            {
                "mount": target,
                "device": source.removeprefix("/dev/").removeprefix("mapper/"),
                "type": fstype,
                "pct": pct,
                "text": f"{size(used)} of {size(total)}",
                "free": f"{size(free)} free",
            }
        )
    return found


def rate(n: float) -> str:
    return f"{size(n)}/s"


def disks() -> list:
    now = time.monotonic()
    stats = {}
    for line in read(Path("/proc/diskstats")).splitlines():
        f = line.split()
        if len(f) >= 13 and (Path("/sys/block") / f[2] / "device").exists():
            # Sectors read, sectors written, milliseconds spent doing I/O.
            stats[f[2]] = (int(f[5]), int(f[9]), int(f[12]))
    try:
        before = json.loads(SAMPLE.read_text())
    except (OSError, ValueError):
        before = {}
    SAMPLE.write_text(json.dumps({"time": now, "stats": stats}))
    elapsed = now - before.get("time", now)
    found = []
    for name, (r, w, busy) in sorted(stats.items()):
        old = before.get("stats", {}).get(name)
        dr = dw = pct = 0.0
        if old and elapsed > 0:
            dr = (r - old[0]) * SECTOR / elapsed
            dw = (w - old[1]) * SECTOR / elapsed
            pct = min((busy - old[2]) / 10 / elapsed, 100)
        dev = Path("/sys/block") / name
        temps = [t for t in (read(p) for p in sorted(dev.glob("device/hwmon*/temp1_input")) + sorted(dev.glob("device/hwmon/hwmon*/temp1_input"))) if t.isdigit()]
        sectors = read(dev / "size")
        found.append(
            {
                "name": name,
                "model": read(dev / "device/model") or name,
                "size": size(int(sectors) * SECTOR) if sectors.isdigit() else "",
                "read": rate(dr),
                "write": rate(dw),
                "bytes": dr + dw,
                "busy": round(pct),
                "temp": f"{int(temps[0]) // 1000}°C" if temps else "",
            }
        )
    return found


def main() -> None:
    usb = [d for d in drives() if d["mount"]]
    fs = [f for f in filesystems() if f["device"] not in {d["device"] for d in usb}]
    io = disks()
    root = next((f for f in fs if f["mount"] == "/"), fs[0] if fs else {"pct": 0, "text": "", "free": ""})
    print(
        json.dumps(
            {
                "root": root,
                "filesystems": fs,
                "usb": usb,
                "disks": io,
                # Every disk's reads and writes together, and the busiest disk, for the summary.
                "io": rate(sum(d.pop("bytes") for d in io)),
                "busy": max((d["busy"] for d in io), default=0),
            },
            ensure_ascii=False,
            separators=(",", ":"),
        )
    )


if __name__ == "__main__":
    main()
