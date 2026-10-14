"""Which programs send and receive, for the dash's network tile
(home/eww/eww.yuck): nethogs in trace mode, through the wrapper that gives
it the capabilities to see every process's sockets (modules/nixos/dash.nix).
A deflisten: it prints a JSON line after every refresh, the busiest first,
for as long as the dash is open.

nethogs prints, per refresh, "program/pid/uid<TAB>sent<TAB>received" in KB/s.
"""

import json
import subprocess
import sys

from procs import size

NETHOGS = "/run/wrappers/bin/nethogs"
SHOWN = 8


def emit(rows: dict) -> None:
    busiest = sorted(rows.items(), key=lambda item: -(item[1][0] + item[1][1]))[:SHOWN]
    print(
        json.dumps(
            {
                "ok": True,
                "procs": [
                    {"name": name, "up": f"{size(up * 1024)}/s", "down": f"{size(down * 1024)}/s"}
                    for name, (up, down) in busiest
                    if up + down > 0
                ],
            },
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        flush=True,
    )


def name(program: str) -> str:
    """ "/nix/store/…/bin/firefox/1234/1000" -> "firefox"; nethogs' own
    "unknown TCP/0/0" stays as it is."""
    path = program.rsplit("/", 2)[0] if program.count("/") >= 2 else program
    return path.rsplit("/", 1)[-1] or path


def main() -> None:
    print(json.dumps({"ok": False, "procs": []}), flush=True)
    try:
        proc = subprocess.Popen([NETHOGS, "-t", "-d", "3"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    except OSError:
        return
    rows: dict = {}
    for line in proc.stdout or []:
        line = line.rstrip("\n")
        if line.startswith("Refreshing:"):
            if rows is not None:
                emit(rows)
            rows = {}
            continue
        parts = line.split("\t")
        if len(parts) != 3:
            continue
        try:
            up, down = float(parts[1]), float(parts[2])
        except ValueError:
            continue
        key = name(parts[0])
        old = rows.get(key, (0.0, 0.0))
        rows[key] = (old[0] + up, old[1] + down)
    sys.exit(proc.wait())


if __name__ == "__main__":
    main()
