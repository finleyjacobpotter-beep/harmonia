"""Network rates for the bar and its interface panel.

Usage: eww-net              JSON: {"shown": {...}, "auto": bool, "ifaces": [...]}
       eww-net show IFACE   show IFACE on the bar ("auto" = the default route's)

Rates come from /sys/class/net/*/statistics, against the previous sample
kept in $XDG_RUNTIME_DIR.
"""

import json
import math
import os
import subprocess
import sys
import time
from pathlib import Path

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "eww"
STATE = STATE_DIR / "net-iface"
PREV = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "eww-net.prev"
SYS = Path("/sys/class/net")
OFFLINE = {"name": "offline", "state": "down", "wireless": False, "down": "0B/s", "up": "0B/s", "address": ""}


def read(path: Path, default: str = "") -> str:
    try:
        return path.read_text().strip()
    except OSError:
        return default


def ip_json(*args: str) -> list:
    try:
        out = subprocess.run(["ip", "-j", *args], capture_output=True, text=True).stdout
        return json.loads(out) if out.strip() else []
    except (OSError, ValueError):
        return []


def rate(n: int) -> str:
    if n < 1024:
        return f"{n}B/s"
    for size, prefix in ((1073741824, "G"), (1048576, "M"), (1024, "K")):
        if n >= size or prefix == "K":
            x = math.floor(n / size * 10 + 0.5) / 10
            return f"{int(x) if x.is_integer() else x}{prefix}B/s"
    return ""


def sample() -> dict:
    """name -> (rx bytes, tx bytes, operstate, wireless), without lo."""
    ifaces = {}
    for d in sorted(SYS.iterdir()):
        if d.name == "lo":
            continue
        try:
            rx = int(read(d / "statistics/rx_bytes", "0"))
            tx = int(read(d / "statistics/tx_bytes", "0"))
        except ValueError:
            continue
        ifaces[d.name] = (rx, tx, read(d / "operstate"), (d / "wireless").is_dir())
    return ifaces


def listing() -> str:
    now = time.time_ns()
    cur = sample()
    try:
        prev = json.loads(PREV.read_text())
        last, old = int(prev["time"]), prev["ifaces"]
    except (OSError, ValueError, KeyError, TypeError):
        last, old = 0, {}
    tmp = PREV.with_name(f"{PREV.name}.{os.getpid()}")
    tmp.write_text(json.dumps({"time": now, "ifaces": {n: v[:2] for n, v in cur.items()}}))
    tmp.replace(PREV)

    routes = ip_json("route", "show", "default")
    default = routes[0].get("dev", "") if routes else ""
    choice = read(STATE, "auto") or "auto"
    shown = default if choice == "auto" or not (SYS / choice).exists() else choice
    addresses = {
        a.get("ifname"): next((i.get("local", "") for i in a.get("addr_info", [])), "")
        for a in ip_json("-4", "addr", "show")
    }

    dt = (now - last) / 1e9 if last > 0 and now > last else 0
    ifaces = []
    for name, (rx, tx, operstate, wireless) in cur.items():
        down = up = 0
        if dt > 0 and name in old:
            if rx >= old[name][0]:
                down = int((rx - old[name][0]) / dt)
            if tx >= old[name][1]:
                up = int((tx - old[name][1]) / dt)
        ifaces.append(
            {
                "name": name,
                "state": operstate,
                "wireless": wireless,
                "down": rate(down),
                "up": rate(up),
                "address": addresses.get(name, ""),
                "shown": name == shown,
                "default": name == default,
            }
        )
    return json.dumps(
        {
            "auto": choice == "auto",
            "default": default,
            "shown": next((i for i in ifaces if i["shown"]), OFFLINE),
            "ifaces": ifaces,
        },
        separators=(",", ":"),
    )


def main(args: list[str]) -> None:
    if args[:1] == ["show"] and len(args) > 1:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        STATE.write_text(args[1] + "\n")
        subprocess.run(["eww", "update", f"net={listing()}"])
    else:
        print(listing())


if __name__ == "__main__":
    main(sys.argv[1:])
