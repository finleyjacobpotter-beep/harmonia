"""Month grid for the bar's calendar panel, with a coloured dot per calendar
on each day that has events.

Usage: eww-cal                 JSON for the panel
       eww-cal prev|next|today move the shown month
       eww-cal day YYYY-MM-DD  show that day's events under the grid
       eww-cal refresh         push fresh JSON to eww (after a sync or a time zone change)

Events are read from the .ics files vdirsyncer keeps under
~/.local/share/calendars (docs/calendar.md). Each directory holding .ics
files is one calendar: its colour comes from the `color` file vdirsyncer's
metasync writes there (falling back to the palette), its name from
`displayname`. A lone .ics file dropped straight into the root is a
calendar of its own.

Days are split in the time zone picked in the panel (the same state file
the bar clock reads).
"""

import calendar
import datetime as dt
import json
import os
import subprocess
import sys
from pathlib import Path
from zoneinfo import ZoneInfo

import icalendar
import recurring_ical_events

# home/eww.nix replaces these with the Miami Wind accents, and "eww" with its store path.
COLORS = ["#ff5faf", "#5fd7ff", "#ffd75f"]
EWW = "eww"

HOME = Path.home()
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "eww"
VIEW = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "eww-cal.json"
ROOT = Path(os.environ.get("HARMONIA_CALENDARS", HOME / ".local/share/calendars"))
MAX_DOTS = 4


def zone() -> dt.tzinfo:
    try:
        name = (STATE / "timezone").read_text().strip()
    except OSError:
        name = "local"
    if name and name != "local":
        try:
            return ZoneInfo(name)
        except (KeyError, ValueError):
            pass
    return dt.datetime.now().astimezone().tzinfo


def read_view(today: dt.date) -> dict:
    try:
        view = json.loads(VIEW.read_text())
        return {"month": dt.date.fromisoformat(view["month"]), "day": dt.date.fromisoformat(view["day"])}
    except (OSError, ValueError, KeyError):
        return {"month": today.replace(day=1), "day": today}


def write_view(view: dict) -> None:
    VIEW.write_text(json.dumps({"month": view["month"].isoformat(), "day": view["day"].isoformat()}))


def shift_month(first: dt.date, months: int) -> dt.date:
    n = first.year * 12 + first.month - 1 + months
    return dt.date(n // 12, n % 12 + 1, 1)


def read_text(path: Path) -> str:
    try:
        return path.read_text().strip()
    except OSError:
        return ""


def calendars() -> list[dict]:
    """[{name, color, files}] for every calendar under ROOT."""
    found = []
    if not ROOT.is_dir():
        return found
    for directory, _, names in sorted(os.walk(ROOT)):
        path = Path(directory)
        files = sorted(path / n for n in names if n.endswith(".ics"))
        if not files:
            continue
        if path == ROOT:
            found += [{"name": f.stem, "color": "", "files": [f]} for f in files]
        else:
            found.append({
                "name": read_text(path / "displayname") or path.name,
                "color": read_text(path / "color")[:7],  # "#RRGGBBAA" -> "#RRGGBB"
                "files": files,
            })
    for i, cal in enumerate(found):
        if not (len(cal["color"]) == 7 and cal["color"].startswith("#")):
            cal["color"] = COLORS[i % len(COLORS)]
    return found


def as_local(value, tz: dt.tzinfo) -> dt.datetime:
    """A DTSTART/DTEND value (date, naive or aware datetime) in tz."""
    if isinstance(value, dt.datetime):
        return value.astimezone(tz) if value.tzinfo else value.replace(tzinfo=tz)
    return dt.datetime.combine(value, dt.time(), tzinfo=tz)


def events(cals: list[dict], start: dt.date, end: dt.date, tz: dt.tzinfo) -> list[dict]:
    """Every event occurrence touching [start, end), split into days."""
    out = []
    lo = dt.datetime.combine(start, dt.time(), tzinfo=tz)
    hi = dt.datetime.combine(end, dt.time(), tzinfo=tz)
    for cal in cals:
        for path in cal["files"]:
            try:
                parsed = icalendar.Calendar.from_ical(path.read_bytes())
                found = recurring_ical_events.of(parsed).between(lo, hi)
            except Exception as err:  # one bad file shouldn't blank the calendar
                print(f"eww-cal: skipping {path}: {err}", file=sys.stderr)
                continue
            for ev in found:
                if ev.name != "VEVENT" or "DTSTART" not in ev:
                    continue
                raw_start = ev["DTSTART"].dt
                all_day = not isinstance(raw_start, dt.datetime)
                begin = as_local(raw_start, tz)
                finish = as_local(ev["DTEND"].dt, tz) if "DTEND" in ev else None
                if finish is None or finish <= begin:
                    finish = begin + (dt.timedelta(days=1) if all_day else dt.timedelta(minutes=1))
                # An event ending at midnight doesn't touch the next day.
                last = (finish - dt.timedelta(microseconds=1)).date()
                day = begin.date()
                while day <= last:
                    out.append({
                        "date": day,
                        "time": "all day" if all_day else (
                            begin.strftime("%H:%M") if day == begin.date() else "cont."),
                        "sort": "" if all_day else begin.strftime("%H:%M"),
                        "summary": str(ev.get("SUMMARY", "(no title)")),
                        "calendar": cal["name"],
                        "color": cal["color"],
                    })
                    day += dt.timedelta(days=1)
    return out


def build() -> dict:
    tz = zone()
    today = dt.datetime.now(tz).date()
    view = read_view(today)
    first = view["month"]
    weeks = calendar.Calendar(firstweekday=6).monthdatescalendar(first.year, first.month)  # Sunday first
    cals = calendars()
    evs = events(cals, weeks[0][0], weeks[-1][-1] + dt.timedelta(days=1), tz)

    by_day: dict[dt.date, list[dict]] = {}
    for ev in evs:
        by_day.setdefault(ev["date"], []).append(ev)

    def dots(day: dt.date) -> list[str]:
        colors = []
        for ev in by_day.get(day, []):
            if ev["color"] not in colors:
                colors.append(ev["color"])
        return colors[:MAX_DOTS]

    selected = view["day"]
    todays = sorted(by_day.get(selected, []), key=lambda e: (e["sort"], e["summary"]))
    return {
        "title": first.strftime("%B %Y"),
        "zone": getattr(tz, "key", "local"),
        "calendars": [{"name": c["name"], "color": c["color"]} for c in cals],
        "weeks": [[{
            "date": d.isoformat(),
            "day": d.day,
            "other": d.month != first.month,
            "today": d == today,
            "selected": d == selected,
            "dots": dots(d),
        } for d in week] for week in weeks],
        "selected": {
            "label": selected.strftime("%a %b %-d"),
            "events": [{k: e[k] for k in ("time", "summary", "calendar", "color")} for e in todays],
        },
    }


def push() -> None:
    subprocess.run([EWW, "update", f"cal={json.dumps(build())}"], check=False)


def main() -> None:
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if not cmd:
        print(json.dumps(build()))
        return
    today = dt.datetime.now(zone()).date()
    view = read_view(today)
    if cmd in ("prev", "next"):
        view["month"] = shift_month(view["month"], -1 if cmd == "prev" else 1)
    elif cmd == "today":
        view = {"month": today.replace(day=1), "day": today}
    elif cmd == "day":
        day = dt.date.fromisoformat(sys.argv[2])
        view = {"month": day.replace(day=1), "day": day}
    elif cmd != "refresh":
        sys.exit(f"eww-cal: unknown command {cmd}")
    write_view(view)
    push()


if __name__ == "__main__":
    main()
