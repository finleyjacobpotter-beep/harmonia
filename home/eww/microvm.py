"""A microVM for the bar (Nike): whether it is running, its firewall
mode (modules/nixos/vm-firewall.nix), and the VPN and utilization numbers
its own status service (nike/status.py) last wrote to its status share. The
status is "fresh" while it is under STALE seconds old.

Usage: eww-microvm NAME             the JSON below
       eww-microvm NAME set MODE    switch its firewall mode (the panel's
                                    dropdown), then refresh the bar
       eww-microvm NAME start|stop  start or stop the VM (the panel's
                                    button), then refresh the bar

{"running": bool, "fresh": bool, "mode": "permissive", ...nike/status.py's fields}
"""

import json
import subprocess
import sys
import time

STALE = 10  # seconds

# What the bar sees before the VM has written anything, so every field exists.
EMPTY = {
    "cpu": 0, "cpu_text": "", "mem": 0, "mem_text": "", "disk": 0, "disk_text": "",
    "load": "", "uptime_text": "",
    "vpn": {"up": False, "dev": "", "address": "", "remote": "", "outbound": "",
            "via_vpn": False, "summary": "", "rx_text": "", "tx_text": ""},
}


def firewall_mode(name: str) -> str:
    """The saved mode, else the VM's default from the firewall's config."""
    try:
        with open(f"/var/lib/vm-firewall/{name}") as f:
            mode = f.read().strip()
        if mode:
            return mode
    except OSError:
        pass
    try:
        with open("/etc/vm-firewall/config.json") as f:
            return json.load(f)[name]["default"]
    except (OSError, ValueError, KeyError):
        return ""


def status(name: str) -> dict:
    try:
        running = subprocess.run(
            ["systemctl", "is-active", "--quiet", f"microvm@{name}.service"],
            stderr=subprocess.DEVNULL,
        ).returncode == 0
    except OSError:
        running = False
    info = EMPTY
    fresh = False
    if running:
        try:
            with open(f"/var/lib/{name}/status/status.json") as f:
                data = json.load(f)
            fresh = time.time() - float(data.get("time", 0)) < STALE
            if fresh:
                info = {**EMPTY, **data, "vpn": {**EMPTY["vpn"], **data.get("vpn", {})}}
        except (OSError, ValueError, TypeError, AttributeError):
            pass
    return {"running": running, "fresh": fresh, "mode": firewall_mode(name), **info}


def refresh(name: str, *extra: str) -> None:
    subprocess.run(["eww", "update", *extra,
                    f"{name}={json.dumps(status(name), separators=(',', ':'), ensure_ascii=False)}"])


def main() -> None:
    name = sys.argv[1]
    if sys.argv[2:] in (["start"], ["stop"]):
        # Allowed without a password by modules/nixos/vm-firewall.nix. The
        # button reads "Starting…"/"Stopping…" until systemctl returns.
        subprocess.run(["eww", "update", f"{name}_busy={sys.argv[2]}"])
        subprocess.run(["/run/wrappers/bin/sudo", "-n", "/run/current-system/sw/bin/systemctl",
                        sys.argv[2], f"microvm@{name}.service"])
        refresh(name, f"{name}_busy=")
        return
    if sys.argv[2:3] == ["set"] and len(sys.argv) == 4:
        # Allowed without a password by modules/nixos/vm-firewall.nix.
        subprocess.run(["/run/wrappers/bin/sudo", "-n", "/run/current-system/sw/bin/vm-firewall",
                        "set", name, sys.argv[3]])
        refresh(name, f"{name}_fw_open=false")
        return
    print(json.dumps(status(name), separators=(",", ":"), ensure_ascii=False))


if __name__ == "__main__":
    main()
