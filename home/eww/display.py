"""Displays: their saved resolution, rotation and position, which one is primary
(the one with the bar and the dash), and the GPU each is plugged into (gpu.py).
The settings window (display-settings.py) changes them through `eww-display apply`;
the dash (dash.py) gives displays their saved settings as they connect.

Usage: eww-display              JSON: {"primary": name, "outputs": [...]}
       eww-display watch        the same on every output change (for deflisten)
       eww-display apply JSON   set and remember every display at once:
                                {"primary": NAME, "outputs": {NAME: {"enabled": true,
                                 "mode": "2560x1440@143.998Hz", "transform": "90",
                                 "x": 0, "y": 0}}}
       eww-display mode NAME MODE   set and remember a resolution
       eww-display rotate NAME normal|90|180|270
                                    set and remember a rotation (clockwise)
       eww-display primary NAME     move the bar and the dash to NAME, remembered
       eww-display power NAME on|off
"""

import json
import math
import os
import subprocess
import sys
from pathlib import Path

from common import RUN_DIR, STATE_DIR, output, read
from gpu import output_gpu

PRIMARY_FILE = STATE_DIR / "primary-display"
MODES_FILE = STATE_DIR / "display-modes.json"
LAYOUT_FILE = STATE_DIR / "display-layout.json"
ROTATION_FILE = STATE_DIR / "display-rotation.json"
SEEN_FILE = RUN_DIR / "eww-display.seen"


def eww(*args: str) -> str:
    return output("eww", *args)


def swaymsg(*args: str) -> str:
    return output("swaymsg", *args)


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
                "transform": o.get("transform") or "normal",
                "gpu": output_gpu(o["name"]),
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
    """Give newly connected displays their saved resolution, rotation and
    position (once per connection, so a mode sway can't do doesn't loop)."""
    seen = read(SEEN_FILE).splitlines()
    now_on = [o["name"] for o in outs if o.get("active")]
    modes, layout, rotation = load(MODES_FILE), load(LAYOUT_FILE), load(ROTATION_FILE)
    for name in now_on:
        if name in seen:
            continue
        k = key(outs, name)
        args = []
        if modes.get(k):
            args += ["mode", modes[k]]
        if rotation.get(k):
            args += ["transform", rotation[k]]
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
        if v.get("transform"):
            command += f" transform {v['transform']}"
        if "x" in v and "y" in v:
            command += f" position {int(v['x'])} {int(v['y'])}"
        commands.append(command)
    if commands:
        swaymsg("; ".join(commands))

    modes, layout, rotation = load(MODES_FILE), load(LAYOUT_FILE), load(ROTATION_FILE)
    for name, v in settings.items():
        if not v.get("enabled", True):
            continue
        k = key(outs, name)
        if v.get("mode"):
            modes[k] = v["mode"]
        if v.get("transform"):
            rotation[k] = v["transform"]
        if "x" in v and "y" in v:
            layout[k] = [int(v["x"]), int(v["y"])]
    save(MODES_FILE, modes)
    save(LAYOUT_FILE, layout)
    save(ROTATION_FILE, rotation)
    if wanted.get("primary") in names:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        PRIMARY_FILE.write_text(wanted["primary"] + "\n")
    # Move the bar and the dash if the primary display changed.
    output("eww-dash", "sync")
    eww("update", f"displays={listing()}")


def watch() -> None:
    print(listing(), flush=True)
    with subprocess.Popen(
        ["swaymsg", "-r", "-t", "subscribe", "-m", '["output"]'], stdout=subprocess.PIPE, text=True
    ) as events:
        for _ in events.stdout or []:
            print(listing(), flush=True)


def main(args: list[str]) -> None:
    command, rest = (args[0], args[1:]) if args else ("", [])
    if command == "watch":
        watch()
    elif command == "apply" and rest:
        apply(json.loads(rest[0]))
    elif command == "mode" and len(rest) == 2:
        apply({"outputs": {rest[0]: {"mode": rest[1]}}})
    elif command == "rotate" and len(rest) == 2:
        apply({"outputs": {rest[0]: {"transform": rest[1]}}})
    elif command == "primary" and rest:
        apply({"primary": rest[0]})
    elif command == "power" and len(rest) == 2:
        apply({"outputs": {rest[0]: {"enabled": rest[1] == "on"}}})
    else:
        print(listing())


if __name__ == "__main__":
    main(sys.argv[1:])
