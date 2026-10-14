"""The CPU's power draw for the dash's cpu tile (home/eww/cpu.py), run as a
service by modules/nixos/dash.nix.

The kernel's RAPL energy counters (/sys/class/powercap/intel-rapl*, AMD's
too) are root's alone: read quickly, they leak what the CPU is doing
(CVE-2020-8694, "Platypus"). This reads them as root every few seconds and
publishes only the average power over that time, which is no use for that,
in /run/harmonia-cpu-power/power.json:

    {"package": 45.2, "core": 30.1, "time": 1791925968}
"""

import json
import os
import time
from pathlib import Path

POWERCAP = Path("/sys/class/powercap")
OUT = Path(os.environ.get("RUNTIME_DIRECTORY", "/run/harmonia-cpu-power")) / "power.json"
INTERVAL = 3


def zones() -> dict:
    """{"package": zone dir, "core": zone dir}: the first package zone and its core subzone."""
    found = {}
    for zone in sorted(POWERCAP.glob("intel-rapl:*")):
        name = (zone / "name").read_text().strip() if (zone / "name").exists() else ""
        if name.startswith("package") and "package" not in found:
            found["package"] = zone
        elif name == "core" and "core" not in found:
            found["core"] = zone
    return found


def energy(zone: Path) -> tuple:
    return int((zone / "energy_uj").read_text()), int((zone / "max_energy_range_uj").read_text())


def main() -> None:
    found = zones()
    before = {k: energy(z) for k, z in found.items()}
    last = time.monotonic()
    while True:
        time.sleep(INTERVAL)
        now = time.monotonic()
        watts = {}
        for k, z in found.items():
            value, wrap = energy(z)
            used = value - before[k][0]
            if used < 0:  # the counter wrapped around
                used += wrap
            watts[k] = round(used / 1e6 / (now - last), 1)
            before[k] = (value, wrap)
        last = now
        tmp = OUT.with_suffix(".tmp")
        tmp.write_text(json.dumps({**watts, "time": int(time.time())}))
        tmp.replace(OUT)


if __name__ == "__main__":
    main()
