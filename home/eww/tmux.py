"""tmux sessions for the dash's tmux tile (home/eww/eww.yuck): every session,
whether a terminal is attached, and its windows with what each runs.

Usage: eww-tmux                JSON for the tile
       eww-tmux attach NAME    open a terminal attached to it
       eww-tmux kill NAME
"""

import json
import subprocess
import sys
from pathlib import Path

from common import output

SEP = "\x1f"  # tmux format fields can hold anything but this


def tmux(*args: str) -> str:
    return output("tmux", *args)


def state() -> str:
    sessions = {}
    for line in tmux("list-sessions", "-F", SEP.join(["#{session_name}", "#{session_attached}", "#{session_windows}", "#{t:session_activity}"])).splitlines():
        f = line.split(SEP)
        if len(f) == 4:
            sessions[f[0]] = {"name": f[0], "attached": f[1] != "0", "count": int(f[2] or 0), "activity": f[3], "windows": []}
    fmt = SEP.join(["#{session_name}", "#{window_index}", "#{window_name}", "#{pane_current_command}", "#{pane_current_path}", "#{window_active}"])
    for line in tmux("list-windows", "-a", "-F", fmt).splitlines():
        f = line.split(SEP)
        if len(f) == 6 and f[0] in sessions:
            sessions[f[0]]["windows"].append(
                {"index": f[1], "name": f[2], "command": f[3], "path": f[4].replace(str(Path.home()), "~", 1), "active": f[5] == "1"}
            )
    return json.dumps(
        {"count": len(sessions), "sessions": sorted(sessions.values(), key=lambda s: s["name"])},
        ensure_ascii=False,
        separators=(",", ":"),
    )


def main(args: list[str]) -> None:
    command, rest = (args[0], args[1:]) if args else ("", [])
    if command == "attach" and rest:
        subprocess.Popen(["alacritty", "-e", "tmux", "attach-session", "-t", rest[0]], start_new_session=True)
        return
    if command == "kill" and rest:
        tmux("kill-session", "-t", rest[0])
        output("eww", "update", f"tmux={state()}")
        return
    print(state())


if __name__ == "__main__":
    main(sys.argv[1:])
