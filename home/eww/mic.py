"""The microphone and cameras, for the dash's sound tile (home/eww/eww.yuck):
the default input's volume and mute, the cameras, and which programs are
recording from either right now.

A program records audio while PipeWire has a capture stream from it; it
uses a camera while it holds /dev/video* open (any of your processes,
Flatpak apps included) or has a PipeWire video stream (the camera portal).

Usage: eww-mic             JSON for the tile
       eww-mic mute        mute or unmute the microphone
       eww-mic set PCT
"""

import json
import os
import sys
from pathlib import Path

from common import output, read

SOURCE = "@DEFAULT_AUDIO_SOURCE@"


def mic() -> dict:
    # "Volume: 0.40 [MUTED]"; an error when there is no input at all.
    parts = output("wpctl", "get-volume", SOURCE).split()
    if len(parts) < 2 or parts[0] != "Volume:":
        return {"present": False, "pct": 0, "muted": False, "name": ""}
    name = ""
    for line in output("wpctl", "inspect", SOURCE).splitlines():
        key, _, value = line.strip().lstrip("* ").partition(" = ")
        if key == "node.description":
            name = value.strip('"')
    return {"present": True, "pct": round(float(parts[1]) * 100), "muted": "[MUTED]" in parts, "name": name}


def streams() -> tuple:
    """Programs with a PipeWire capture stream: (audio, video)."""
    try:
        nodes = json.loads(output("pw-dump") or "[]")
    except ValueError:
        nodes = []
    audio, video = set(), set()
    for node in nodes:
        props = ((node.get("info") or {}).get("props")) or {}
        name = props.get("application.name") or props.get("node.name") or ""
        if props.get("media.class") == "Stream/Input/Audio":
            audio.add(name)
        elif props.get("media.class") == "Stream/Input/Video":
            video.add(name)
    return sorted(audio), sorted(video)


def camera_users() -> set:
    users = set()
    for fd_dir in Path("/proc").glob("[0-9]*/fd"):
        try:
            for fd in os.scandir(fd_dir):
                if os.readlink(fd.path).startswith("/dev/video"):
                    users.add(read(fd_dir.parent / "comm"))
                    break
        except OSError:
            continue
    return users


def cameras() -> list:
    # One camera often has several /dev/video nodes (video, metadata).
    return sorted({read(p / "name") for p in Path("/sys/class/video4linux").glob("video*")} - {""})


def main(args: list[str]) -> None:
    command, rest = (args[0], args[1:]) if args else ("", [])
    if command == "mute":
        output("wpctl", "set-mute", SOURCE, "toggle")
    elif command == "set" and rest:
        output("wpctl", "set-volume", SOURCE, f"{max(0, min(int(float(rest[0])), 100))}%")
    if command:
        output("eww", "update", f"mic={state()}")
    else:
        print(state())


def state() -> str:
    audio, video = streams()
    users = sorted(camera_users() | set(video))
    return json.dumps(
        {
            **mic(),
            "recording": audio,
            "recording_text": ", ".join(audio),
            "cameras": cameras(),
            "camera_users": users,
            "camera_text": ", ".join(users),
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )


if __name__ == "__main__":
    main(sys.argv[1:])
