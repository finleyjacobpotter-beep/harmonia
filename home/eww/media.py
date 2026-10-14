"""Now playing, at the top of the dash's sound tile (home/eww/eww.yuck)
while something plays or is paused: the playing (else paused) MPRIS player
through playerctl (Firefox, mpv, Spotify, …), its track and position.

Usage: eww-media                          JSON for the tile
       eww-media play-pause|next|previous PLAYER
"""

import json
import sys

from common import output

SEP = "\x1f"
FORMAT = SEP.join(["{{playerName}}", "{{status}}", "{{artist}}", "{{title}}", "{{album}}", "{{position}}", "{{mpris:length}}"])


def clock(micro: str) -> str:
    seconds = int(micro or 0) // 1_000_000 if (micro or "").isdigit() else 0
    return f"{seconds // 60}:{seconds % 60:02d}"


def players() -> list:
    found = []
    for line in output("playerctl", "-a", "metadata", "--format", FORMAT).splitlines():
        f = line.split(SEP)
        if len(f) == 7:
            found.append(dict(zip(("player", "status", "artist", "title", "album", "position", "length"), f)))
    return found


def state() -> str:
    found = players()
    # The one playing, else one paused, else nothing.
    shown = next((p for p in found if p["status"] == "Playing"), None) or next((p for p in found if p["status"] == "Paused"), None)
    if not shown:
        return json.dumps({"playing": False, "paused": False, "player": "", "title": "", "artist": "", "album": "", "pct": 0, "time": ""})
    length = int(shown["length"]) if shown["length"].isdigit() else 0
    position = int(shown["position"]) if shown["position"].isdigit() else 0
    return json.dumps(
        {
            "playing": shown["status"] == "Playing",
            "paused": shown["status"] == "Paused",
            "player": shown["player"],
            "title": shown["title"] or "Unknown",
            "artist": shown["artist"],
            "album": shown["album"],
            "pct": round(position / length * 100) if length else 0,
            "time": f"{clock(shown['position'])} / {clock(shown['length'])}" if length else clock(shown["position"]),
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )


def main(args: list[str]) -> None:
    if len(args) == 2 and args[0] in ("play-pause", "next", "previous"):
        output("playerctl", "-p", args[1], args[0])
        output("eww", "update", f"media={state()}")
    else:
        print(state())


if __name__ == "__main__":
    main(sys.argv[1:])
