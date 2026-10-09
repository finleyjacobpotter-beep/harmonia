"""What's running, as JSON for the bar's activity badges: GameMode, Steam
(Flathub or native), and the local model server (harmonia's llama.cpp
server, modules/nixos/llama-server.nix): its unit's state and whether the
model is loaded and answering.

Usage: eww-activity              the JSON below
       eww-activity ai start|stop  start or stop the server (the panel's
                                   button; polkit allows it), then return

{"gamemode": bool, "steam": bool,
 "ai": {"on": bool, "ready": bool, "text": "serving on …"}}
"""

import json
import subprocess
import sys
import urllib.request

from common import output

AI_UNIT = "podman-llama-server.service"
# 200 once the model is loaded, 503 while it loads.
AI_HEALTH = "http://127.0.0.1:1235/health"


def ai_ready() -> bool:
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(AI_HEALTH, timeout=1) as response:
            return response.status == 200
    except (OSError, ValueError):
        return False


def ai_status() -> dict:
    state = output("systemctl", "is-active", AI_UNIT).strip() or "inactive"
    ready = state == "active" and ai_ready()
    if ready:
        text = "serving on 127.0.0.1:1235"
    elif state == "active":
        text = "loading the model (the first start downloads it, ~6 GB)"
    else:
        text = {
            "activating": "starting (the first start pulls the image)",
            "deactivating": "stopping",
            "failed": "failed: see journalctl -u podman-llama-server",
        }.get(state, "stopped")
    return {"on": state not in ("inactive", "failed"), "ready": ready, "text": text}


def main() -> None:
    if sys.argv[1:2] == ["ai"] and sys.argv[2:3] in (["start"], ["stop"]):
        # --no-block: the first start pulls the image, and the bar shows the
        # unit as starting meanwhile.
        subprocess.run(["systemctl", sys.argv[2], "--no-block", AI_UNIT])
        return
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
                "ai": ai_status(),
            },
            separators=(",", ":"),
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
