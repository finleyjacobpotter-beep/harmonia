"""CPU details for the bar's CPU tooltip, as
{"model": "...", "temp": " · 52°C" (or "" without a sensor), "load": "0.52 0.61 0.70"}.
The temperature is the package sensor: k10temp (AMD), zenpower or coretemp (Intel).
"""

import json
from pathlib import Path

from common import read

SENSORS = ("k10temp", "zenpower", "coretemp")


def model() -> str:
    for line in read(Path("/proc/cpuinfo")).splitlines():
        key, _, value = line.partition(":")
        if key.strip() == "model name":
            return value.strip()
    return ""


def temp() -> str:
    for hwmon in sorted(Path("/sys/class/hwmon").glob("hwmon*")):
        if read(hwmon / "name") in SENSORS:
            milli = read(hwmon / "temp1_input")
            if milli.isdigit():
                return f" · {int(milli) // 1000}°C"
    return ""


def main() -> None:
    load = " ".join(read(Path("/proc/loadavg")).split()[:3])
    print(json.dumps({"model": model(), "temp": temp(), "load": load}, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()
