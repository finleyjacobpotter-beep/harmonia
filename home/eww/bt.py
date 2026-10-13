"""Bluetooth for the dash's sound tile (home/eww/eww.yuck): whether the
adapter is on, and every paired device with whether it is connected and its
battery. bluetoothctl waits for an adapter that isn't there, so a machine
without one is never asked, and every call has a time limit.

Usage: eww-bt                    JSON for the tile
       eww-bt power on|off
       eww-bt connect MAC | disconnect MAC
"""

import json
import re
import subprocess
import sys
from pathlib import Path

from common import output


def ctl(*args: str, timeout: float = 4) -> str:
    try:
        return subprocess.run(["bluetoothctl", *args], capture_output=True, text=True, timeout=timeout).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def fields(text: str) -> dict:
    out = {}
    for line in text.splitlines():
        key, _, value = line.strip().partition(": ")
        out.setdefault(key, value)
    return out


def state() -> str:
    if not any(Path("/sys/class/bluetooth").glob("hci*")):
        return json.dumps({"present": False, "powered": False, "connected": 0, "devices": []})
    powered = fields(ctl("show")).get("Powered") == "yes"
    devices = []
    for line in ctl("devices", "Paired").splitlines():
        parts = line.split(" ", 2)
        if len(parts) == 3 and parts[0] == "Device":
            info = fields(ctl("info", parts[1]))
            battery = re.search(r"\((\d+)\)", info.get("Battery Percentage", ""))
            devices.append(
                {
                    "mac": parts[1],
                    "name": parts[2],
                    "connected": info.get("Connected") == "yes",
                    "battery": f"{battery.group(1)}%" if battery else "",
                    "icon": info.get("Icon", ""),
                }
            )
    devices.sort(key=lambda d: (not d["connected"], d["name"].lower()))
    return json.dumps(
        {"present": True, "powered": powered, "connected": sum(d["connected"] for d in devices), "devices": devices},
        ensure_ascii=False,
        separators=(",", ":"),
    )


def main(args: list[str]) -> None:
    command, rest = (args[0], args[1:]) if args else ("", [])
    if command == "power" and rest[:1] in (["on"], ["off"]):
        ctl("power", rest[0])
    elif command in ("connect", "disconnect") and rest:
        ctl(command, rest[0], timeout=20)
    else:
        print(state())
        return
    output("eww", "update", f"bt={state()}")


if __name__ == "__main__":
    main(sys.argv[1:])
