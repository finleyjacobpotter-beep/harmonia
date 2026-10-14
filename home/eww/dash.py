"""The dash: workspace 10, named "10:dash", on the primary display. No window
stays there, and while it is on screen eww draws the dash over it: a square
of tiles beside the wallpaper (home/eww/eww.yuck). The bar shows everywhere
else. On the dash, sway is in its "dash" mode (home/sway.nix), whose bare
keys come here.

Usage: eww-dash watch        keep sway and eww in step (sway startup; one at a time)
       eww-dash sync         the same once (after display changes)
       eww-dash key KEY      a key from sway's dash mode: h j k l move,
                             e expand or collapse, esc collapse, a tile's letter opens it
       eww-dash open TILE    expand TILE, or collapse it if it is open (a click,
                             which also focuses the dash)
       eww-dash show TILE    go to the dash with TILE expanded
       eww-dash toggle-bar   turn the bar off or on (remembered)
       eww-dash pin          keep the dash on the display it is on, which
                             then holds no other workspace (again: unpin)

The dash lives on the primary display, sharing it with other workspaces,
unless it is pinned to a display: then every other workspace moves to
another display, so the dash stays on screen there and Super+1…9 opens
workspaces beside it. The pin is remembered per monitor (make, model and
serial) in ~/.local/state/eww/dash-display.
"""

import fcntl
import json
import os
import shutil
import subprocess
import sys
import time
from contextlib import contextmanager
from typing import Iterator

import display
from common import RUN_DIR, STATE_DIR, output, read

DASH = "10:dash"

# The tiles, as on screen, and the key that opens each (shown on the tile).
GRID = [
    ["cpu", "mem", "disk", "gpu"],
    ["net", "virt", "system"],
    ["usb", "displays", "sound"],
    ["projects", "tmux", "downloads", "secrets"],
    ["time", "games", "notify", "clip"],
]
KEYS = {
    "c": "cpu",
    "m": "mem",
    "f": "disk",
    "g": "gpu",
    "n": "net",
    "v": "virt",
    "y": "system",
    "p": "projects",
    "x": "tmux",
    "w": "downloads",
    "b": "clip",
    "u": "secrets",
    "a": "notify",
    "r": "games",
    "i": "usb",
    "d": "displays",
    "s": "sound",
    "t": "time",
}
MOVES = {"h": (0, -1), "j": (1, 0), "k": (-1, 0), "l": (0, 1)}

# Below this many pixels a side the dash takes the whole display, and below
# it there too, it scrolls.
MIN_SIDE = 640

STATE = RUN_DIR / "eww-dash.json"
PIN = STATE_DIR / "dash-display"
# Present while the bar is turned off (Super+Shift+b, or the dash's button).
NO_BAR = STATE_DIR / "bar-hidden"
LOCK = RUN_DIR / "eww-dash.lock"
WATCH_LOCK = RUN_DIR / "eww-dash.watch"


def eww(*args: str) -> str:
    return output("eww", *args)


def swaymsg(*args: str) -> str:
    return output("swaymsg", *args)


def sway(kind: str):
    try:
        return json.loads(swaymsg("-r", "-t", kind) or "null")
    except ValueError:
        return None


@contextmanager
def locked() -> Iterator[dict]:
    """The dash's state, read and written back under a lock, since sway's
    keys, clicks and the watcher all change it."""
    with open(LOCK, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            state = json.loads(STATE.read_text())
        except (OSError, ValueError):
            state = {}
        yield state
        STATE.write_text(json.dumps(state))


def row_of(tile: str) -> int:
    return next((r for r, row in enumerate(GRID) if tile in row), -1)


def push(state: dict) -> None:
    """Show the selected and expanded tiles; the row lets eww.yuck squeeze
    the other tiles, and while the focus is elsewhere it outlines none."""
    sel, opened = state.get("sel", "cpu"), state.get("open", "")
    value = {
        "sel": sel,
        "open": opened,
        "focused": state.get("focused", True),
        "row": row_of(opened) if opened else -1,
        "pinned": state.get("pinned", ""),
        "bar": not NO_BAR.exists(),
        "hints": state.get("hints", True),
    }
    eww("update", "dash=" + json.dumps(value, separators=(",", ":")))


def key(state: dict, k: str) -> None:
    sel, opened = state.get("sel", "cpu"), state.get("open", "")
    # A tile from an older layout (devices, media) is gone.
    if not any(sel in row for row in GRID):
        sel, opened = "cpu", ""
    if k == "hints":
        state["hints"] = not state.get("hints", True)
    elif k in MOVES:
        r, c = row_of(sel), GRID[row_of(sel)].index(sel)
        dr, dc = MOVES[k]
        r = min(max(r + dr, 0), len(GRID) - 1)
        sel = GRID[r][min(max(c + dc, 0), len(GRID[r]) - 1)]
        # Moving while a tile is open opens the next one, like flipping pages.
        opened = sel if opened else ""
    elif k == "e":
        opened = "" if opened == sel else sel
    elif k == "esc":
        opened = ""
    elif k in KEYS or k in KEYS.values():
        tile = KEYS.get(k, k)
        sel, opened = tile, ("" if opened == tile else tile)
    state.update(sel=sel, open=opened)
    push(state)


def layout(out: dict) -> dict:
    """The dash's size on a display: a square on the left half beside the
    wallpaper (the top half of a vertical display), else the whole display,
    scrolling if even that is under MIN_SIDE."""
    w, h = out["rect"]["width"], out["rect"]["height"]
    orient = "h" if w >= h else "v"
    side = min(w // 2, h) if orient == "h" else min(w, h // 2)
    if side >= MIN_SIDE:
        return {"orient": orient, "split": True, "w": side, "h": side}
    return {"orient": orient, "split": False, "w": max(w, MIN_SIDE), "h": max(h, MIN_SIDE)}


def tree_workspaces(node: dict) -> Iterator[dict]:
    if node.get("type") == "workspace":
        yield node
    for child in node.get("nodes", []):
        yield from tree_workspaces(child)


def evict(target: str) -> None:
    """Send any window that lands on the dash to the last other workspace, and follow it."""
    dash = next((w for w in tree_workspaces(sway("get_tree") or {}) if w.get("name") == DASH), None)
    windows = (dash or {}).get("nodes", []) + (dash or {}).get("floating_nodes", [])
    for con in windows:
        swaymsg(f'[con_id={con["id"]}] move container to workspace "{target}"')
    if windows:
        swaymsg(f'workspace "{target}"')


def windows(state: dict, screen: str, primary: str, outs: list) -> None:
    """The dash on the display showing its workspace; the bar on the primary
    one, or while the dash is there, on the next display (unless hidden)."""
    want = {"dash": screen}
    free = [o["name"] for o in outs if o.get("active") and o["name"] != screen]
    bar = primary if primary in free else (free[0] if free else "")
    want["bar"] = "" if NO_BAR.exists() else bar
    active = {line.split(":")[0].strip() for line in eww("active-windows").splitlines() if ":" in line}
    opened = state.setdefault("windows", {})
    if screen:
        out = next((o for o in outs if o["name"] == screen), None)
        # Every time: `eww reload` puts the defvar back to its initial value.
        if out:
            state["layout"] = layout(out)
            eww("update", "dash_layout=" + json.dumps(state["layout"], separators=(",", ":")))
    for name, target in want.items():
        if name in active and opened.get(name) != target:
            eww("close", name)
            active.discard(name)
        if target and name not in active:
            eww("open", name, "--screen", target)
        opened[name] = target


def pinned(outs: list) -> str:
    """The display the dash is pinned to, if it is connected and on."""
    pin = read(PIN)
    return next((o["name"] for o in outs if o.get("active") and pin and display.key(outs, o["name"]) == pin), "")


def keep_pinned(home: str, outs: list, spaces: list) -> None:
    """Give the pinned display to the dash: move every other workspace on it
    to another display and show the dash there, keeping the focus where it was."""
    other = next((o["name"] for o in outs if o.get("active") and o["name"] != home), "")
    if not other:
        return
    focused = next((w["name"] for w in spaces if w.get("focused")), "")
    commands = []
    for w in spaces:
        if w["name"] != DASH and w["output"] == home:
            commands.append(f'workspace "{w["name"]}"; move workspace to output "{other}"')
    dash = next((w for w in spaces if w["name"] == DASH), None)
    if commands or not dash or not dash.get("visible") or dash["output"] != home:
        if dash and dash["output"] != home:
            commands.append(f"workspace {DASH}; move workspace to output {home}")
        commands.append(f"workspace {DASH}")
        if focused and focused != DASH:
            commands.append(f'workspace "{focused}"')
        swaymsg("; ".join(commands))


def sync(state: dict) -> None:
    outs = display.outputs()
    primary = display.primary(outs)
    home = pinned(outs)
    if state.get("pinned") != home:
        state["pinned"] = home
        push(state)
    if (home or primary) and state.get("assigned") != (home or primary):
        # Where sway creates the dash; moving to another primary display
        # takes effect the next time the dash is opened.
        swaymsg(f"workspace {DASH} output {home or primary}")
        state["assigned"] = home or primary
    spaces = sway("get_workspaces") or []
    if home:
        keep_pinned(home, outs, spaces)
        spaces = sway("get_workspaces") or []
    focused = next((w for w in spaces if w.get("focused")), {})
    on_dash = focused.get("name") == DASH
    if focused and not on_dash:
        state["last"] = focused["name"]
    if state.get("focused", True) != on_dash:
        # Leaving the dash (for another display, while it stays on screen)
        # closes the open tile, which eww.yuck's revealers animate shut.
        state["focused"] = on_dash
        if not on_dash:
            state["open"] = ""
        push(state)
    dash = next((w for w in spaces if w.get("name") == DASH), None)
    if dash:
        evict(state.get("last") or "1")
    # The dash's keys work only on the dash; the other modes (Super+r, …)
    # come back to it when they end.
    mode = (sway("get_binding_state") or {}).get("name")
    if on_dash and mode == "default":
        swaymsg("mode", "dash")
    elif not on_dash and mode == "dash":
        swaymsg("mode", "default")
    windows(state, dash["output"] if dash and dash.get("visible") else "", primary, outs)


def start_eww() -> None:
    """The eww daemon, started here so it gets sway's environment. It stays in
    the foreground under systemd-cat, so its log (timeouts, script errors)
    goes to the journal as eww, beside this watcher's (home/sway.nix):
    journalctl --user -t eww. Its own session, so it outlives this watcher."""
    if eww("ping").strip() == "pong":
        return
    subprocess.Popen(
        ["systemd-cat", "-t", "eww", "eww", "daemon", "--no-daemonize"],
        stdin=subprocess.DEVNULL,
        start_new_session=True,
    )
    for _ in range(50):
        if eww("ping").strip() == "pong":
            return
        time.sleep(0.1)


def shape(outs: list) -> list:
    """What eww's windows are sized and placed by: the displays that are on,
    their resolution, rotation and scale (not their position)."""
    return sorted(
        [o["name"], display.mode_id(o["current_mode"]) if o.get("current_mode") else "", o.get("transform"), o.get("scale")]
        for o in outs
        if o.get("active")
    )


def follow_displays(state: dict) -> None:
    """eww keeps the displays as they were when its daemon started, so after a
    display comes, goes or changes resolution it would draw the dash at the
    old size, or not at all. A new daemon sees them as they are; sync opens
    the windows again."""
    now = shape(display.outputs())
    if state.get("displays") not in (None, now):
        print(f"displays changed to {now}; restarting eww", file=sys.stderr, flush=True)
        eww("kill")
        start_eww()
        state.pop("windows", None)
        push(state)
    state["displays"] = now


def installed() -> str:
    """The eww-dash a rebuild last installed, to tell whether this one is it."""
    found = shutil.which("eww-dash")
    return os.path.realpath(found) if found else ""


def watch() -> None:
    # sway runs this on every reload too, so only the first one stays.
    lock = open(WATCH_LOCK, "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return
    with locked() as state:
        new_session = state.get("session") != os.environ.get("SWAYSOCK")
        if new_session:
            # A new sway session: forget the last one's windows and give
            # displays their saved settings before eww starts, so it starts
            # with the displays as they will be.
            state.clear()
            state["session"] = os.environ.get("SWAYSOCK")
            display.SEEN_FILE.unlink(missing_ok=True)
            display.apply_saved(display.outputs())
    start_eww()
    with locked() as state:
        if new_session:
            swaymsg(f"workspace {DASH} output {display.primary(display.outputs())}")
            swaymsg(f"workspace {DASH}")
        state.pop("windows", None)
        state["displays"] = shape(display.outputs())
        push(state)
        sync(state)
    me = installed()
    with subprocess.Popen(
        ["swaymsg", "-r", "-t", "subscribe", "-m", '["workspace", "window", "mode", "output"]'],
        stdout=subprocess.PIPE,
        text=True,
    ) as events:
        for line in events.stdout or []:
            # A rebuild installs a new eww-dash, but sway started this one
            # at login and a second one would exit (above): hand over to the
            # new one, which takes the lock as this one's closes on exec.
            if installed() != me:
                events.terminate()
                break
            try:
                event = json.loads(line)
            except ValueError:
                continue
            # Of the window events only a new or moved window can land on the dash.
            if "container" in event and event.get("change") not in ("new", "move", "floating"):
                continue
            if "container" not in event and "current" not in event and "pango_markup" not in event:
                # An output event: a display came, went or changed.
                display.apply_saved(display.outputs())
                with locked() as state:
                    follow_displays(state)
                    sync(state)
                continue
            with locked() as state:
                sync(state)
    if installed() != me:
        print("a new eww-dash was installed; restarting", file=sys.stderr, flush=True)
        os.execvp("eww-dash", ["eww-dash", "watch"])


def main(args: list[str]) -> None:
    command, rest = (args[0], args[1:]) if args else ("", [])
    if command == "watch":
        watch()
        return
    with locked() as state:
        if command == "key" and rest:
            key(state, rest[0])
        elif command == "open" and rest:
            # A click on the dash while another display has the focus
            # brings the focus here, so the tile it opens stays open.
            if not state.get("focused", True):
                swaymsg(f"workspace {DASH}")
                state["focused"] = True
            key(state, rest[0])
        elif command == "show" and rest:
            swaymsg(f"workspace {DASH}")
            state.update(sel=rest[0], open=rest[0], focused=True)
            push(state)
        elif command == "pin":
            outs = display.outputs()
            spaces = sway("get_workspaces") or []
            dash = next((w for w in spaces if w.get("name") == DASH), {})
            if pinned(outs):
                PIN.unlink(missing_ok=True)
            elif dash.get("output"):
                STATE_DIR.mkdir(parents=True, exist_ok=True)
                PIN.write_text(display.key(outs, dash["output"]) + "\n")
            sync(state)
            push(state)
        elif command == "toggle-bar":
            if NO_BAR.exists():
                NO_BAR.unlink()
            else:
                STATE_DIR.mkdir(parents=True, exist_ok=True)
                NO_BAR.touch()
            sync(state)
            push(state)
        elif command == "sync":
            sync(state)
        else:
            print(__doc__.strip())


if __name__ == "__main__":
    main(sys.argv[1:])
