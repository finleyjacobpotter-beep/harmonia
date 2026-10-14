"""Projects for the dash's projects tile (home/eww/eww.yuck): every git
repository in ~/Projects and in ~/nike-share/Projects (Nike's shared folder,
modules/nixos/nike.nix), or one folder further down (~/Projects/agon/agon),
with its branch, uncommitted changes, commits
ahead of and behind its upstream (as of the last fetch; nothing is fetched
here), and its last commit. Buttons open a tmux session or neovim there.

Usage: eww-projects               JSON for the tile
       eww-projects tmux PATH     a tmux session named after it, in a terminal
       eww-projects nvim PATH
"""

import json
import subprocess
import sys
import time
from pathlib import Path

from common import output

HOME = Path.home()
ROOTS = [HOME / "Projects", HOME / "nike-share/Projects"]


def git(repo: Path, *args: str) -> str:
    return output("git", "-C", str(repo), *args).strip()


def ago(stamp: str) -> str:
    seconds = time.time() - int(stamp or 0)
    for unit, length in (("y", 31536000), ("mo", 2592000), ("d", 86400), ("h", 3600), ("min", 60)):
        if seconds >= length:
            return f"{int(seconds // length)} {unit}"
    return "now"


def repo(path: Path, root: Path) -> dict:
    changes = [line for line in git(path, "status", "--porcelain").splitlines() if line]
    counts = git(path, "rev-list", "--left-right", "--count", "HEAD...@{upstream}").split()
    last = git(path, "log", "-1", "--format=%ct\x1f%s").split("\x1f")
    return {
        "name": path.name,
        "path": str(path),
        "where": "nike" if "nike-share" in str(root) else "",
        "branch": git(path, "branch", "--show-current") or "detached",
        "changes": len(changes),
        "ahead": int(counts[0]) if len(counts) == 2 else 0,
        "behind": int(counts[1]) if len(counts) == 2 else 0,
        "upstream": len(counts) == 2,
        "last": last[1][:60] if len(last) == 2 else "",
        "age": ago(last[0]) if len(last) == 2 else "",
        "stamp": int(last[0]) if len(last) == 2 and last[0].isdigit() else 0,
    }


def find(root: Path) -> list:
    """Repositories in root or one folder below it."""
    found = []
    for p in sorted(root.iterdir()):
        if not p.is_dir() or p.name.startswith("."):
            continue
        if (p / ".git").exists():
            found.append(p)
        else:
            found += [c for c in sorted(p.iterdir()) if c.is_dir() and (c / ".git").exists()]
    return found


def state() -> str:
    repos = []
    for root in ROOTS:
        if root.is_dir():
            repos += [repo(p, root) for p in find(root)]
    repos.sort(key=lambda r: -r["stamp"])
    return json.dumps(
        {"count": len(repos), "dirty": sum(r["changes"] > 0 for r in repos), "repos": repos},
        ensure_ascii=False,
        separators=(",", ":"),
    )


def main(args: list[str]) -> None:
    command, rest = (args[0], args[1:]) if args else ("", [])
    path = Path(rest[0]) if rest else None
    if path is None or not any(root in path.parents for root in ROOTS) or not (path / ".git").exists():
        print(state())
        return
    if command == "tmux":
        session = path.name.replace(".", "-")
        subprocess.Popen(["alacritty", "-e", "tmux", "new-session", "-A", "-s", session, "-c", str(path)], start_new_session=True)
    elif command == "nvim":
        subprocess.Popen(["alacritty", "--working-directory", str(path), "-e", "nvim", "."], start_new_session=True)


if __name__ == "__main__":
    main(sys.argv[1:])
