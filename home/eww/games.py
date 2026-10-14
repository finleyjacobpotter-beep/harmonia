"""Games for the dash's games tile (home/eww/eww.yuck): installed Lutris
games from its database and Steam games from their app manifests, most
recently played first, each with a button to launch it; and whether
GameMode and Steam are running (activity.py has the same for the chips).

Lutris and Steam are Flatpaks (modules/nixos/gaming.nix, steam.nix): Lutris
keeps its database in ~/.var/app/net.lutris.Lutris, and Steam its default
library in ~/.var/app/com.valvesoftware.Steam, with another one possible
in ~/Games/SteamLibrary, the folder the two share.

Usage: eww-games                    JSON for the tile
       eww-games play lutris ID | play steam APPID
"""

import json
import re
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
LUTRIS = "net.lutris.Lutris"
STEAM = "com.valvesoftware.Steam"
LUTRIS_DB = HOME / ".var/app" / LUTRIS / "data/lutris/pga.db"
STEAM_LIBRARIES = [HOME / ".var/app" / STEAM / ".local/share/Steam/steamapps", HOME / "Games/SteamLibrary/steamapps"]
SHOWN = 12


def ago(stamp: int) -> str:
    if not stamp:
        return "never played"
    seconds = time.time() - stamp
    for unit, length in (("d", 86400), ("h", 3600), ("min", 60)):
        if seconds >= length:
            return f"played {int(seconds // length)} {unit} ago"
    return "played just now"


def lutris() -> list:
    if not LUTRIS_DB.exists():
        return []
    try:
        db = sqlite3.connect(f"file:{LUTRIS_DB}?mode=ro", uri=True)
        rows = db.execute("select id, name, runner, lastplayed, playtime from games where installed = 1").fetchall()
    except sqlite3.Error:
        return []
    return [
        {"store": "lutris", "id": str(r[0]), "name": r[1], "detail": f"{r[2] or 'lutris'} · {r[4] or 0:.1f} h", "last": int(r[3] or 0)}
        for r in rows
    ]


def steam() -> list:
    found = []
    for library in STEAM_LIBRARIES:
        for manifest in library.glob("appmanifest_*.acf"):
            fields = dict(re.findall(r'"(\w+)"\s+"([^"]*)"', manifest.read_text(errors="replace")))
            # Proton and the Steam runtimes are apps too; they never get played.
            if "name" not in fields or re.match(r"Proton|Steam Linux Runtime|Steamworks", fields["name"]):
                continue
            found.append({"store": "steam", "id": fields.get("appid", ""), "name": fields["name"], "detail": "Steam", "last": int(fields.get("LastPlayed") or 0)})
    return found


def running(app: str) -> bool:
    try:
        out = subprocess.run(["flatpak", "ps", "--columns=application"], capture_output=True, text=True).stdout
    except OSError:
        return False
    return app in out.split()


def gamemode() -> bool:
    try:
        return "is active" in subprocess.run(["gamemoded", "-s"], capture_output=True, text=True).stdout
    except OSError:
        return False


def state() -> str:
    games = sorted(lutris() + steam(), key=lambda g: (-g["last"], g["name"].lower()))
    return json.dumps(
        {
            "count": len(games),
            "games": [{**g, "played": ago(g["last"])} for g in games[:SHOWN]],
            "gamemode": gamemode(),
            "steam": running(STEAM),
            "lutris": running(LUTRIS),
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )


def main(args: list[str]) -> None:
    if args[:1] == ["play"] and len(args) == 3 and args[2].isdigit():
        if args[1] == "lutris":
            uri = [LUTRIS, f"lutris:rungameid/{args[2]}"]
        elif args[1] == "steam":
            uri = [STEAM, f"steam://rungameid/{args[2]}"]
        else:
            return
        subprocess.Popen(["flatpak", "run", *uri], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    print(state())


if __name__ == "__main__":
    main(sys.argv[1:])
