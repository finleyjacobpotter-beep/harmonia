"""Connectivity for the dash's network tile (home/eww/eww.yuck): the last
result of the DNS check and ICMP traceroute to google.com, which the
harmonia-connectivity service writes (modules/nixos/dash.nix, at boot and
on every NetworkManager connect or DHCP renewal).

Usage: eww-conn          JSON for the tile
       eww-conn run      run the test again now (wheel may, via polkit)
"""

import json
import sys
import time
from pathlib import Path

from common import output

RESULT = Path("/run/harmonia-connectivity/result.json")
UNIT = "harmonia-connectivity.service"


def ago(seconds: float) -> str:
    for unit, length in (("d", 86400), ("h", 3600), ("min", 60)):
        if seconds >= length:
            return f"{int(seconds // length)} {unit} ago"
    return "just now"


def state() -> str:
    try:
        r = json.loads(RESULT.read_text())
    except (OSError, ValueError):
        r = {}
    hops = (r.get("trace") or {}).get("hops") or []
    last = hops[-1] if hops else {}
    # Every field the tile reads, even before the first test.
    dns = r.get("dns") or {"ok": False, "ms": 0, "server": ""}
    return json.dumps(
        {
            "known": bool(r),
            "running": output("systemctl", "is-active", UNIT).strip() == "activating",
            "when": ago(time.time() - r["time"]) if r else "",
            "gateway": r.get("gateway", ""),
            "dns": dns,
            "dns_text": (f"google.com in {dns['ms']} ms via {dns.get('server') or 'resolver'}" if dns.get("ok") else f"DNS failed: {dns.get('error', 'no answer')}") if r else "",
            "reached": bool((r.get("trace") or {}).get("ok")),
            "hops": [{**h, "avg_text": f"{h['avg']:.1f} ms", "lost": h["loss"] >= 100} for h in hops],
            "hop_count": len(hops),
            "rtt": f"{last.get('avg', 0):.0f} ms" if last else "",
            "loss": f"{last.get('loss', 0):.0f}%" if last else "",
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )


def main(args: list[str]) -> None:
    if args[:1] == ["run"]:
        output("systemctl", "start", "--no-block", UNIT)
        time.sleep(0.3)
        output("eww", "update", f"conn={state()}")
    else:
        print(state())


if __name__ == "__main__":
    main(sys.argv[1:])
