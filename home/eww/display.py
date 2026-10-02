"""Displays for the bar: one icon per sway output, a panel per display to pick
its resolution, and which display is primary (the one with the bar).

Usage: eww-display              JSON: {"primary": name, "outputs": [...]}
       eww-display watch        the same on every output change (for deflisten);
                                also reapplies saved resolutions to displays as they
                                connect and moves the bar if the primary one comes or goes
       eww-display start        apply saved resolutions and open the bar (sway startup)
       eww-display mode NAME MODE   set and remember a resolution, e.g. 2560x1440@143.998Hz
       eww-display primary NAME     move the bar (and its panels) to NAME, remembered
       eww-display power NAME on|off
       eww-display select NAME      open (or close) NAME's panel from its bar icon
       eww-display dropdown         open or close the resolution list in that panel
       eww-display menu WINDOW      toggle one of the bar's panels on the primary display
       eww-display toggle-bar
"""

import json
import math
import os
import subprocess
import sys
from pathlib import Path

STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "eww"
PRIMARY_FILE = STATE_DIR / "primary-display"
MODES_FILE = STATE_DIR / "display-modes.json"
RUN_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
SEEN_FILE = RUN_DIR / "eww-display.seen"
LAST_FILE = RUN_DIR / "eww-display.primary"
SEL_FILE = RUN_DIR / "eww-display.selected"


def read(path: Path) -> str:
    try:
        return path.read_text().rstrip("\n")
    except OSError:
        return ""


def run(*args: str) -> str:
    """Run a command quietly and return its output ("" if it fails)."""
    try:
        return subprocess.run(args, capture_output=True, text=True).stdout
    except OSError:
        return ""


def eww(*args: str) -> str:
    return run("eww", *args)


def swaymsg(*args: str) -> str:
    return run("swaymsg", *args)


def outputs() -> list:
    try:
        return json.loads(swaymsg("-r", "-t", "get_outputs") or "[]")
    except ValueError:
        return []


def saved_modes() -> dict:
    try:
        return json.loads(MODES_FILE.read_text())
    except (OSError, ValueError):
        return {}


def primary(outs: list) -> str:
    """The remembered primary display if it is connected and on, else the first one that is."""
    saved = read(PRIMARY_FILE)
    on = [o["name"] for o in outs if o.get("active")]
    return saved if saved in on else (on[0] if on else "")


def number(x: float) -> str:
    """A number the way jq prints it: 60, 143.998."""
    return str(int(x)) if float(x).is_integer() else str(x)


def mode_id(m: dict) -> str:
    return f"{m['width']}x{m['height']}@{number(m['refresh'] / 1000)}Hz"


def mode_label(m: dict) -> str:
    return f"{m['width']}x{m['height']} @ {math.floor(m['refresh'] / 1000 + 0.5)} Hz"


def listing(outs: list | None = None) -> str:
    outs = outputs() if outs is None else outs
    first = primary(outs)
    sel = read(SEL_FILE)
    entries = []
    for i, o in enumerate(outs):
        # One entry per mode (the first by id, as jq's unique_by), biggest and fastest first.
        modes: dict = {}
        for m in sorted(o.get("modes") or [], key=mode_id):
            modes.setdefault(mode_id(m), m)
        ordered = sorted(modes.values(), key=lambda m: (-(m["width"] * m["height"]), -m["refresh"]))
        current = o.get("current_mode") if o.get("active") else None
        entries.append(
            {
                "name": o["name"],
                "number": i + 1,
                "active": o.get("active"),
                "primary": o["name"] == first,
                "title": " ".join(p for p in (o.get("make"), o.get("model")) if p and p != "Unknown"),
                "current": mode_label(current) if current else "off",
                "current_id": mode_id(current) if current else "",
                "modes": [{"id": mode_id(m), "label": mode_label(m)} for m in ordered],
            }
        )
    return json.dumps(
        {
            "primary": first,
            "outputs": entries,
            # The display whose panel is open, as a list of zero or one for the
            # panel to loop over (it only builds that one).
            "selected": [e for e in entries if e["name"] == sel],
        },
        separators=(",", ":"),
        ensure_ascii=False,
    )


def key(outs: list, name: str) -> str:
    """Saved resolutions are keyed by make, model and serial, so they follow a
    monitor from port to port."""
    for o in outs:
        if o["name"] == name:
            return " ".join("null" if o.get(f) is None else str(o[f]) for f in ("make", "model", "serial"))
    return ""


def apply_saved(outs: list) -> None:
    """Give newly connected displays their saved resolution (once per
    connection, so a mode sway can't do doesn't loop)."""
    seen = read(SEEN_FILE).splitlines()
    now_on = [o["name"] for o in outs if o.get("active")]
    saved = saved_modes()
    for name in now_on:
        if name in seen:
            continue
        mode = saved.get(key(outs, name))
        if mode:
            swaymsg("output", name, "mode", mode)
    SEEN_FILE.write_text("\n".join(now_on) + "\n")


def open_bar(screen: str) -> None:
    eww("open", "bar", *(["--screen", screen] if screen else []))
    LAST_FILE.write_text(screen + "\n")


def follow_primary(outs: list) -> None:
    """Move the bar when the primary display changes (unplugged, or back again)."""
    want = primary(outs)
    if want == read(LAST_FILE):
        return
    for line in eww("active-windows").splitlines():
        window = line.split(":")[0].strip()
        if window and window != "bar":
            eww("close", window)
    open_bar(want)


def reopen_panel() -> None:
    """GTK windows grow but don't shrink: reopen the panel after closing the list."""
    eww("open", "display-menu", "--screen", primary(outputs()))


def watch() -> None:
    apply_saved(outputs())
    print(listing(), flush=True)
    with subprocess.Popen(
        ["swaymsg", "-r", "-t", "subscribe", "-m", '["output"]'], stdout=subprocess.PIPE, text=True
    ) as events:
        for _ in events.stdout or []:
            apply_saved(outputs())
            follow_primary(outputs())
            print(listing(), flush=True)


def main(args: list[str]) -> None:
    command, rest = (args[0], args[1:]) if args else ("", [])
    if command == "watch":
        watch()
    elif command == "start":
        SEEN_FILE.unlink(missing_ok=True)
        apply_saved(outputs())
        open_bar(primary(outputs()))
    elif command == "mode" and len(rest) == 2:
        name, mode = rest
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        modes = saved_modes()
        modes[key(outputs(), name)] = mode
        tmp = MODES_FILE.with_name(f"{MODES_FILE.name}.{os.getpid()}")
        tmp.write_text(json.dumps(modes, indent=2) + "\n")
        tmp.replace(MODES_FILE)
        swaymsg("output", name, "mode", mode)
        eww("update", "display_modes_open=false", f"displays={listing()}")
        reopen_panel()
    elif command == "dropdown":
        if eww("get", "display_modes_open").strip() == "true":
            eww("update", "display_modes_open=false")
            reopen_panel()
        else:
            eww("update", "display_modes_open=true")
    elif command == "primary" and rest:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        PRIMARY_FILE.write_text(rest[0] + "\n")
        eww("close", "display-menu")
        follow_primary(outputs())
        eww("update", f"displays={listing()}")
    elif command == "power" and len(rest) == 2:
        swaymsg("output", rest[0], "enable" if rest[1] == "on" else "disable")
        eww("update", f"displays={listing()}")
        reopen_panel()
    elif command == "select" and rest:
        panel_open = any(line.endswith(": display-menu") for line in eww("active-windows").splitlines())
        if read(SEL_FILE) == rest[0] and panel_open:
            eww("close", "display-menu")
        else:
            SEL_FILE.write_text(rest[0] + "\n")
            eww("update", "display_modes_open=false", f"displays={listing()}")
            reopen_panel()
    elif command == "menu" and rest:
        eww("open", "--toggle", rest[0], "--screen", primary(outputs()))
    elif command == "toggle-bar":
        if any(line.startswith("bar:") for line in eww("active-windows").splitlines()):
            eww("close", "bar")
        else:
            open_bar(primary(outputs()))
    else:
        print(listing())


if __name__ == "__main__":
    main(sys.argv[1:])
