"""What the bar scripts share: where they keep state, reading files and
command output quietly, and the settings home/eww.nix passes in
($HARMONIA_BAR_CONFIG, a JSON file)."""

import json
import os
import subprocess
from pathlib import Path

# Settings that survive a reboot (the shown interface, the time zone, the
# displays), and scratch files that don't.
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "eww"
RUN_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))


def read(path: Path, default: str = "") -> str:
    """A file's contents, stripped (default if it can't be read)."""
    try:
        return path.read_text().strip()
    except OSError:
        return default


def output(*args: str, check: bool = False) -> str:
    """A command's output ("" if it is missing, or with check, if it fails)."""
    try:
        return subprocess.run(args, capture_output=True, text=True, check=check).stdout
    except (OSError, subprocess.CalledProcessError):
        return ""


def config() -> dict:
    """The settings from home/eww.nix ({} outside the wrapper)."""
    try:
        with open(os.environ["HARMONIA_BAR_CONFIG"]) as f:
            return json.load(f)
    except (KeyError, OSError, ValueError):
        return {}
