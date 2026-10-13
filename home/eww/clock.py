"""The clock, in the time zone picked on the dash's calendar: the bar shows
the fuzzy time, the dash the exact one.

Usage: eww-clock           JSON: {"text": "Wed Sep 30 14:16", "clock": "14:16", "date": "Wed Sep 30",
                                  "fuzzy": "quarter past two", "abbr": "EDT", "zone": "America/New_York"}
       eww-clock tz ZONE   switch to ZONE ("local" = the system time zone)
"""

import datetime as dt
import json
import subprocess
import sys
from zoneinfo import ZoneInfo

from common import STATE_DIR

STATE = STATE_DIR / "timezone"

HOURS = "twelve one two three four five six seven eight nine ten eleven".split()
# The time to the nearest five minutes, past the hour up to half past and
# to the next hour after it.
PHRASES = {
    5: "five past {}",
    10: "ten past {}",
    15: "quarter past {}",
    20: "twenty past {}",
    25: "twenty-five past {}",
    30: "half past {}",
    35: "twenty-five to {}",
    40: "twenty to {}",
    45: "quarter to {}",
    50: "ten to {}",
    55: "five to {}",
}


def fuzzy(time: dt.datetime) -> str:
    minutes = round((time.hour * 60 + time.minute) / 5) * 5
    hour, five = divmod(minutes, 60)
    if five > 30:
        hour += 1
    hour %= 24
    if five == 0:
        return {0: "midnight", 12: "noon"}.get(hour, f"{HOURS[hour % 12]} o'clock")
    return PHRASES[five].format({0: "midnight", 12: "noon"}.get(hour, HOURS[hour % 12]))


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
        {
            "text": time.strftime("%a %b %-d %H:%M"),
            "clock": time.strftime("%H:%M"),
            "date": time.strftime("%a %b %-d"),
            "fuzzy": fuzzy(time),
            "abbr": time.strftime("%Z"),
            "zone": zone,
        },
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
