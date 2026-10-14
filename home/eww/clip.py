"""Clipboard history for the dash's clipboard tile (home/eww/eww.yuck), from
cliphist (home/sway.nix runs it). The history lives in
$XDG_RUNTIME_DIR/cliphist.db, a private tmpfs, so it never reaches the disk
and is gone at logout; locking the screen wipes it too (harmonia-lock).
Copies an app marks as sensitive are never stored.

Usage: eww-clip               JSON for the tile
       eww-clip copy ID       put an entry on the clipboard again
       eww-clip delete ID
       eww-clip wipe
"""

import json
import os
import subprocess
import sys
from pathlib import Path

from common import output

DB = str(Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "cliphist.db")
SHOWN = 30


def cliphist(*args: str, **kw) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(["cliphist", "-db-path", DB, *args], capture_output=True, **kw)
    except OSError:
        return subprocess.CompletedProcess(args, 1, b"", b"")


def entries() -> tuple[int, list]:
    """How many copies the history holds, and the latest SHOWN of them."""
    lines = cliphist("list").stdout.decode(errors="replace").splitlines()
    rows = []
    for line in lines[:SHOWN]:
        ident, _, preview = line.partition("\t")
        image = preview.startswith("[[ binary data")
        rows.append({"id": ident, "text": " ".join(preview.split())[:200], "image": image})
    return len(lines), rows


def state() -> str:
    count, rows = entries()
    return json.dumps({"count": count, "entries": rows}, ensure_ascii=False, separators=(",", ":"))


def main(args: list[str]) -> None:
    command, rest = (args[0], args[1:]) if args else ("", [])
    if command == "copy" and rest:
        # cliphist decode takes the whole list line; the id and a tab are enough.
        data = cliphist("decode", input=f"{rest[0]}\t".encode()).stdout
        subprocess.run(["wl-copy"], input=data)
    elif command == "delete" and rest:
        cliphist("delete", input=f"{rest[0]}\t".encode())
    elif command == "wipe":
        cliphist("wipe")
    else:
        print(state())
        return
    output("eww", "update", f"clip={state()}")


if __name__ == "__main__":
    main(sys.argv[1:])
