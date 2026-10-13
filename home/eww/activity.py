"""What's running, as JSON for the dash's activity chips: GameMode and
Steam (Flathub or native).

{"gamemode": bool, "steam": bool}
"""

import json
import subprocess

from common import output


def main() -> None:
    apps = {line.strip() for line in output("flatpak", "ps", "--columns=application").splitlines()}
    gamemode = "is active" in output("gamemoded", "-s")
    try:
        native_steam = subprocess.run(["pgrep", "-x", "steam"], stdout=subprocess.DEVNULL).returncode == 0
    except OSError:
        native_steam = False
    steam = "com.valvesoftware.Steam" in apps or native_steam
    print(
        json.dumps(
            {
                "gamemode": gamemode,
                "steam": steam,
            },
            separators=(",", ":"),
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
