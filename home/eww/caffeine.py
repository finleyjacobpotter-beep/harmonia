"""Caffeine: stopping swayidle (home/sway.nix) turns off the lock and blank
timers until it is started again. The bar button toggles it.

Usage: eww-caffeine          "on" (swayidle stopped) or "off"
       eww-caffeine toggle
"""

import subprocess
import sys


def state() -> str:
    idle = subprocess.run(["systemctl", "--user", "is-active", "--quiet", "swayidle.service"])
    return "off" if idle.returncode == 0 else "on"


def main(args: list[str]) -> None:
    if args[:1] != ["toggle"]:
        print(state())
        return
    action = "stop" if state() == "off" else "start"
    if subprocess.run(["systemctl", "--user", action, "swayidle.service"]).returncode != 0:
        sys.exit(1)
    subprocess.run(["eww", "update", f"caffeine={state()}"])


if __name__ == "__main__":
    main(sys.argv[1:])
