"""{"name": ..., "hint": ...} whenever the sway binding mode changes."""

import json
import subprocess

# home/eww.nix replaces this with the key hints for each mode.
HINTS: dict = {}


def emit(name: str) -> None:
    print(json.dumps({"name": name, "hint": HINTS.get(name, "")}, separators=(",", ":"), ensure_ascii=False), flush=True)


def main() -> None:
    emit("default")
    with subprocess.Popen(
        ["swaymsg", "-r", "-t", "subscribe", "-m", '["mode"]'], stdout=subprocess.PIPE, text=True
    ) as events:
        for line in events.stdout or []:
            try:
                emit(json.loads(line)["change"])
            except (ValueError, KeyError, TypeError):
                continue


if __name__ == "__main__":
    main()
