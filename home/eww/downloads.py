"""Downloads for the dash's downloads tile (home/eww/eww.yuck): the newest
files in ~/Downloads/firefox, the only folder Firefox's sandbox can write
to (modules/nixos/flatpak.nix), with buttons to open, keep or bin them.
Binning moves a file to the freedesktop trash (~/.local/share/Trash), so
it can still come back.

Usage: eww-downloads                 JSON for the tile
       eww-downloads open NAME       show it in ranger
       eww-downloads keep NAME DIR   move it to ~/Documents or ~/Projects
       eww-downloads trash NAME
"""

import json
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

from common import output
from procs import size

HOME = Path.home()
FOLDER = HOME / "Downloads/firefox"
PLACES = {"documents": HOME / "Documents", "projects": HOME / "Projects"}
TRASH = HOME / ".local/share/Trash"
SHOWN = 15


def ago(seconds: float) -> str:
    for unit, length in (("d", 86400), ("h", 3600), ("min", 60)):
        if seconds >= length:
            return f"{int(seconds // length)} {unit}"
    return "now"


def state() -> str:
    try:
        files = [f for f in FOLDER.iterdir() if not f.name.startswith(".")]
    except OSError:
        files = []
    files.sort(key=lambda f: f.stat().st_mtime, reverse=True)
    now = time.time()
    rows = []
    for f in files[:SHOWN]:
        st = f.stat()
        # Firefox writes a .part file next to one it is still downloading.
        partial = f.suffix == ".part" or (f.parent / f"{f.name}.part").exists()
        rows.append({"name": f.name, "size": size(st.st_size) if f.is_file() else "folder", "age": ago(now - st.st_mtime), "partial": partial})
    return json.dumps({"count": len(files), "files": rows, "folder": str(FOLDER).replace(str(HOME), "~")}, ensure_ascii=False, separators=(",", ":"))


def target(name: str) -> Path:
    """A file in the folder, by name only (no path tricks)."""
    path = FOLDER / Path(name).name
    if not path.exists():
        raise SystemExit(f"no such download: {name}")
    return path


def unique(path: Path) -> Path:
    n = 1
    candidate = path
    while candidate.exists():
        candidate = path.with_name(f"{path.stem} ({n}){path.suffix}")
        n += 1
    return candidate


def trash(path: Path) -> None:
    """The freedesktop trash: the file under files/, and a .trashinfo saying where it was."""
    (TRASH / "files").mkdir(parents=True, exist_ok=True)
    (TRASH / "info").mkdir(parents=True, exist_ok=True)
    dest = unique(TRASH / "files" / path.name)
    (TRASH / "info" / f"{dest.name}.trashinfo").write_text(
        f"[Trash Info]\nPath={urllib.parse.quote(str(path))}\nDeletionDate={time.strftime('%Y-%m-%dT%H:%M:%S')}\n"
    )
    path.rename(dest)


def main(args: list[str]) -> None:
    command, rest = (args[0], args[1:]) if args else ("", [])
    if command == "open" and rest:
        subprocess.Popen(["alacritty", "--class", "ranger", "-e", "ranger", f"--selectfile={target(rest[0])}"], start_new_session=True)
        return
    if command == "keep" and len(rest) == 2 and rest[1] in PLACES:
        PLACES[rest[1]].mkdir(parents=True, exist_ok=True)
        path = target(rest[0])
        path.rename(unique(PLACES[rest[1]] / path.name))
    elif command == "trash" and rest:
        trash(target(rest[0]))
    else:
        print(state())
        return
    output("eww", "update", f"downloads={state()}")


if __name__ == "__main__":
    main(sys.argv[1:])
