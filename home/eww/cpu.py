"""CPU details for the dash's CPU tile (home/eww/eww.yuck): the model, every
temperature sensor, clocks, load, uptime, how many processes and threads
there are, and the busiest processes (procs.py). eww's own EWW_CPU gives
the usage per thread. The power draw comes from a root service that reads
the CPU's energy counters (modules/nixos/dash.nix).

Temperatures come from k10temp or zenpower (AMD) or coretemp (Intel); the
first one is the package's, shown in the tile's summary.
"""

import json
from pathlib import Path

from common import read
from procs import snapshot, top_cpu

SENSORS = ("k10temp", "zenpower", "coretemp")
CPUFREQ = Path("/sys/devices/system/cpu")
POWER = Path("/run/harmonia-cpu-power/power.json")


def model() -> str:
    for line in read(Path("/proc/cpuinfo")).splitlines():
        key, _, value = line.partition(":")
        if key.strip() == "model name":
            return value.strip()
    return ""


def temps() -> list:
    """[{"label": "Tctl", "value": 52}, ...]: the package sensor first."""
    found = []
    for hwmon in sorted(Path("/sys/class/hwmon").glob("hwmon*")):
        if read(hwmon / "name") not in SENSORS:
            continue
        for sensor in sorted(hwmon.glob("temp*_input"), key=lambda p: int(p.name[4:-6] or 0)):
            milli = read(sensor)
            if milli.lstrip("-").isdigit():
                label = read(sensor.with_name(sensor.name.replace("_input", "_label"))) or sensor.name[:-6]
                found.append({"label": label, "value": int(milli) // 1000})
        break
    return found[:12]


def ghz(khz: str) -> str:
    return f"{int(khz) / 1e6:.1f} GHz" if khz.isdigit() else ""


def clocks() -> dict:
    """The highest current clock across threads, the top clock and the governor."""
    current = [int(v) for v in (read(p) for p in CPUFREQ.glob("cpu[0-9]*/cpufreq/scaling_cur_freq")) if v.isdigit()]
    policy = CPUFREQ / "cpu0/cpufreq"
    return {
        "freq": ghz(str(max(current))) if current else "",
        "freq_max": ghz(read(policy / "cpuinfo_max_freq")),
        "governor": read(policy / "scaling_governor"),
    }


def power() -> dict:
    """The package's (and cores') average power over the last few seconds."""
    try:
        p = json.loads(POWER.read_text())
    except (OSError, ValueError):
        return {"power": "", "power_core": ""}
    return {
        "power": f"{p['package']:.0f} W" if "package" in p else "",
        "power_core": f"{p['core']:.0f} W" if "core" in p else "",
    }


def uptime() -> str:
    seconds = int(float((read(Path("/proc/uptime")) or "0").split()[0]))
    days, rest = divmod(seconds, 86400)
    hours, minutes = rest // 3600, rest % 3600 // 60
    return f"{days} d {hours} h" if days else f"{hours} h {minutes} min"


def main() -> None:
    loadavg = (read(Path("/proc/loadavg")) or "0 0 0 0/0").split()
    procs = snapshot()
    sensors = temps()
    package = sensors[0]["value"] if sensors else 0
    print(
        json.dumps(
            {
                "model": model(),
                "temp": package,
                "temp_text": f"{package}°C" if sensors else "",
                "temps": [{"label": t["label"], "text": f"{t['value']}°C"} for t in sensors],
                "load": " ".join(loadavg[:3]),
                "uptime": uptime(),
                "tasks": f"{len(procs)} processes · {loadavg[3].split('/')[-1]} threads",
                "top": top_cpu(procs),
                **clocks(),
                **power(),
            },
            ensure_ascii=False,
            separators=(",", ":"),
        )
    )


if __name__ == "__main__":
    main()
