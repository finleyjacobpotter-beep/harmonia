"""A connectivity test for the dash's network tile (home/eww/conn.py), run as
a service by modules/nixos/dash.nix: at boot, when NetworkManager brings a
connection up or renews its DHCP lease, and from the tile's Run again.

It resolves google.com through the system's default resolver (as any
program would, through systemd-resolved) and traces the route there with
ICMP (mtr), then writes /run/harmonia-connectivity/result.json:

    {"time": …, "gateway": "192.168.1.1 (eno1)",
     "dns": {"ok": true, "server": "192.168.1.1", "ms": 12, "addresses": [...]},
     "trace": {"ok": true, "hops": [{"host": …, "loss": 0.0, "avg": 1.2}, ...]}}
"""

import json
import os
import socket
import subprocess
import time
from pathlib import Path

TARGET = "google.com"
OUT = Path(os.environ.get("RUNTIME_DIRECTORY", "/run/harmonia-connectivity")) / "result.json"


def run(*args: str, timeout: float = 30) -> str:
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def gateway() -> str:
    parts = run("ip", "route", "show", "default").split()
    via = parts[parts.index("via") + 1] if "via" in parts else ""
    dev = parts[parts.index("dev") + 1] if "dev" in parts else ""
    return f"{via} ({dev})" if via else ""


def dns_server() -> str:
    """The upstream server systemd-resolved is using right now."""
    for line in run("resolvectl", "status").splitlines():
        key, _, value = line.strip().partition(":")
        if key == "Current DNS Server" and value.strip():
            return value.strip()
    return ""


def dns() -> dict:
    start = time.monotonic()
    try:
        infos = socket.getaddrinfo(TARGET, None, proto=socket.IPPROTO_TCP)
    except OSError as e:
        return {"ok": False, "error": str(e), "server": dns_server(), "ms": 0, "addresses": []}
    ms = round((time.monotonic() - start) * 1000)
    addresses = sorted({info[4][0] for info in infos})
    return {"ok": True, "server": dns_server(), "ms": ms, "addresses": addresses[:4]}


def trace() -> dict:
    """mtr's report: three ICMP probes per hop, names and addresses both."""
    out = run("mtr", "--json", "--report-cycles", "3", "--show-ips", TARGET, timeout=60)
    try:
        hubs = json.loads(out)["report"]["hubs"]
    except (ValueError, KeyError, TypeError):
        return {"ok": False, "hops": []}
    hops = [
        {"n": h.get("count"), "host": h.get("host", "???"), "loss": h.get("Loss%", 100.0), "avg": h.get("Avg", 0.0)}
        for h in hubs
    ]
    reached = bool(hops) and hops[-1]["loss"] < 100
    return {"ok": reached, "hops": hops}


def main() -> None:
    result = {
        "time": int(time.time()),
        "gateway": gateway(),
        "dns": dns(),
        "trace": trace(),
    }
    tmp = OUT.with_suffix(".tmp")
    tmp.write_text(json.dumps(result))
    tmp.replace(OUT)


if __name__ == "__main__":
    main()
