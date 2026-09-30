"""Network rates for the bar and its interface panel.

Usage: eww-net              JSON: {"shown": {...}, "auto": bool, "ifaces": [...]}
       eww-net show IFACE   show IFACE on the bar ("auto" = the default route's)

Rates come from /sys/class/net/*/statistics, against the previous sample
kept in $XDG_RUNTIME_DIR.
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "eww"
STATE = STATE_DIR / "net-iface"
PREV = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "eww-net.prev"
SYS = Path("/sys/class/net")
OFFLINE = {"name": "offline", "state": "down", "wireless": False, "down": "  0.0 bps ", "up": "  0.0 bps ", "address": ""}


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


def rate(bytes_per_second: float) -> str:
    """Bits per second, scaled to bps, kbps, Mbps or Gbps and padded to a
    fixed width: the number is "0.0" to "999.9", padded to five characters
    ("  0.0 bps " to "999.9 Gbps") so the bar stays put."""
    v, units = bytes_per_second * 8, ["bps", "kbps", "Mbps", "Gbps"]
    i = 0
    while v >= 999.95 and i < len(units) - 1:
        v, i = v / 1000, i + 1
    return f"{min(v, 999.9):5.1f} {units[i]:<4}"


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
        down = up = 0.0
        if dt > 0 and name in old:
            if rx >= old[name][0]:
                down = (rx - old[name][0]) / dt
            if tx >= old[name][1]:
                up = (tx - old[name][1]) / dt
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
