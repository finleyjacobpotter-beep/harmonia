"""The bar clock, in the time zone picked in the calendar panel.

Usage: eww-clock           JSON: {"text": "Wed Sep 30 14:16", "abbr": "EDT", "zone": "America/New_York"}
       eww-clock tz ZONE   switch to ZONE ("local" = the system time zone)
"""

import datetime as dt
import json
import os
import subprocess
import sys
from pathlib import Path
from zoneinfo import ZoneInfo

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "eww"
STATE = STATE_DIR / "timezone"


def now() -> str:
    try:
        zone = STATE.read_text().strip() or "local"
    except OSError:
        zone = "local"
    time = dt.datetime.now().astimezone()
    if zone != "local":
        try:
            time = dt.datetime.now(ZoneInfo(zone))
        except (KeyError, ValueError):
            pass
    return json.dumps(
        {"text": time.strftime("%a %b %-d %H:%M"), "abbr": time.strftime("%Z"), "zone": zone},
        separators=(",", ":"),
    )


def main(args: list[str]) -> None:
    if args[:1] == ["tz"] and len(args) > 1:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        STATE.write_text(args[1] + "\n")
        subprocess.run(["eww", "update", f"time={now()}"])
        subprocess.run(["eww-cal", "refresh"])
    else:
        print(now())


if __name__ == "__main__":
    main(sys.argv[1:])
