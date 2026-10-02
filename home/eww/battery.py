"""The first battery's charge in percent, or an empty line without one."""

from pathlib import Path


def capacity() -> str:
    for battery in sorted(Path("/sys/class/power_supply").glob("BAT*")):
        try:
            return (battery / "capacity").read_text().strip()
        except OSError:
            continue
    return ""


if __name__ == "__main__":
    print(capacity())
