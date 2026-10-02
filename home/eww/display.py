"""Displays: their saved resolution and position, and which one is primary
(the one with the bar). The settings window (display-settings.py) changes
them through `eww-display apply`.

Usage: eww-display              JSON: {"primary": name, "outputs": [...]}
       eww-display watch        the same on every output change (for deflisten);
                                also reapplies saved resolutions and positions to
                                displays as they connect and moves the bar if the
                                primary one comes or goes
       eww-display start        apply saved settings and open the bar (sway startup)
       eww-display apply JSON   set and remember every display at once:
                                {"primary": NAME, "outputs": {NAME: {"enabled": true,
                                 "mode": "2560x1440@143.998Hz", "x": 0, "y": 0}}}
       eww-display mode NAME MODE   set and remember a resolution
       eww-display primary NAME     move the bar (and its panels) to NAME, remembered
       eww-display power NAME on|off
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
LAYOUT_FILE = STATE_DIR / "display-layout.json"
RUN_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
SEEN_FILE = RUN_DIR / "eww-display.seen"
LAST_FILE = RUN_DIR / "eww-display.primary"


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


def load(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


def save(path: Path, data: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{os.getpid()}")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    tmp.replace(path)


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
        {"primary": first, "outputs": entries},
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
    """Give newly connected displays their saved resolution and position (once
    per connection, so a mode sway can't do doesn't loop)."""
    seen = read(SEEN_FILE).splitlines()
    now_on = [o["name"] for o in outs if o.get("active")]
    modes, layout = load(MODES_FILE), load(LAYOUT_FILE)
    for name in now_on:
        if name in seen:
            continue
        k = key(outs, name)
        args = []
        if modes.get(k):
            args += ["mode", modes[k]]
        if layout.get(k):
            args += ["position", *(str(int(v)) for v in layout[k])]
        if args:
            swaymsg("output", name, *args)
    SEEN_FILE.write_text("\n".join(now_on) + "\n")


def apply(wanted: dict) -> None:
    """Set every display in one sway command (so a layout never passes through
    an overlapping state), then remember resolutions, positions and primary."""
    outs = outputs()
    names = {o["name"] for o in outs}
    settings = {n: v for n, v in (wanted.get("outputs") or {}).items() if n in names}
    # Turn displays on before turning others off, so there is always one on.
    ordered = sorted(settings.items(), key=lambda item: not item[1].get("enabled", True))
    commands = []
    for name, v in ordered:
        if not v.get("enabled", True):
            commands.append(f"output {name} disable")
            continue
        command = f"output {name} enable"
        if v.get("mode"):
            command += f" mode {v['mode']}"
        if "x" in v and "y" in v:
            command += f" position {int(v['x'])} {int(v['y'])}"
        commands.append(command)
    if commands:
        swaymsg("; ".join(commands))

    modes, layout = load(MODES_FILE), load(LAYOUT_FILE)
    for name, v in settings.items():
        if not v.get("enabled", True):
            continue
        k = key(outs, name)
        if v.get("mode"):
            modes[k] = v["mode"]
        if "x" in v and "y" in v:
            layout[k] = [int(v["x"]), int(v["y"])]
    save(MODES_FILE, modes)
    save(LAYOUT_FILE, layout)
    if wanted.get("primary") in names:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        PRIMARY_FILE.write_text(wanted["primary"] + "\n")
    follow_primary(outputs())
    eww("update", f"displays={listing()}")


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
    elif command == "apply" and rest:
        apply(json.loads(rest[0]))
    elif command == "mode" and len(rest) == 2:
        apply({"outputs": {rest[0]: {"mode": rest[1]}}})
    elif command == "primary" and rest:
        apply({"primary": rest[0]})
    elif command == "power" and len(rest) == 2:
        apply({"outputs": {rest[0]: {"enabled": rest[1] == "on"}}})
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
