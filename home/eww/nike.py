"""Nike for the bar: whether the microVM is running, and the VPN and
utilization numbers its own status service (nike/status.py) last wrote to
the status share. The status is "fresh" while it is under STALE seconds old.

{"running": bool, "fresh": bool, ...nike/status.py's fields}
"""

import json
import subprocess
import time

STATUS_FILE = "/var/lib/nike/status/status.json"
STALE = 10  # seconds

# What the bar sees before Nike has written anything, so every field exists.
EMPTY = {
    "cpu": 0, "cpu_text": "", "mem": 0, "mem_text": "", "disk": 0, "disk_text": "",
    "load": "", "uptime_text": "",
    "vpn": {"up": False, "dev": "", "address": "", "remote": "", "outbound": "",
            "via_vpn": False, "summary": "", "rx_text": "", "tx_text": ""},
}


def main() -> None:
    try:
        running = subprocess.run(
            ["systemctl", "is-active", "--quiet", "microvm@nike.service"],
            stderr=subprocess.DEVNULL,
        ).returncode == 0
    except OSError:
        running = False
    status = EMPTY
    fresh = False
    if running:
        try:
            with open(STATUS_FILE) as f:
                data = json.load(f)
            fresh = time.time() - float(data.get("time", 0)) < STALE
            if fresh:
                status = {**EMPTY, **data, "vpn": {**EMPTY["vpn"], **data.get("vpn", {})}}
        except (OSError, ValueError, TypeError, AttributeError):
            pass
    print(json.dumps({"running": running, "fresh": fresh, **status},
                     separators=(",", ":"), ensure_ascii=False))


if __name__ == "__main__":
    main()
