"""Default sink volume for the bar and its panel.

Usage: eww-volume                 JSON: {"pct": N, "muted": bool, "text": " 40%", "sink": "..."}
       eww-volume up|down|mute    change it by 5% (up to 150%) or toggle mute
       eww-volume set N           set it to N%
"""

import json
import re
import subprocess
import sys

from common import output

SINK = "@DEFAULT_AUDIO_SINK@"


def state() -> str:
    out = output("wpctl", "get-volume", SINK, check=True) or "Volume: 0"
    try:
        pct = int(float(out.split()[1]) * 100 + 0.5)
    except (IndexError, ValueError):
        pct = 0
    muted = "MUTED" in out
    match = re.search(r'node\.description = "(.*)"', output("wpctl", "inspect", SINK, check=True))
    return json.dumps(
        {
            "pct": pct,
            "muted": muted,
            "sink": match.group(1) if match else "",
            # Padded to four characters ("100%") so the bar stays put.
            "text": ("mute" if muted else f"{pct}%").rjust(4),
        },
        separators=(",", ":"),
        ensure_ascii=False,
    )


def main(args: list[str]) -> None:
    command = args[0] if args else ""
    actions = {
        "up": ["wpctl", "set-volume", "-l", "1.5", SINK, "5%+"],
        "down": ["wpctl", "set-volume", SINK, "5%-"],
        "mute": ["wpctl", "set-mute", SINK, "toggle"],
    }
    if command == "set" and len(args) > 1:
        actions["set"] = ["wpctl", "set-volume", "-l", "1.5", SINK, f"{args[1]}%"]
    if command not in actions:
        print(state())
        return
    if subprocess.run(actions[command]).returncode != 0:
        sys.exit(1)
    subprocess.run(["eww", "update", f"volume={state()}"])


if __name__ == "__main__":
    main(sys.argv[1:])
