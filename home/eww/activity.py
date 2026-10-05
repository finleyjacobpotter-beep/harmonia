"""What's running, as JSON for the bar's activity badges: GameMode, Steam
(Flathub or native), LM Studio and the models it has loaded (its API on
localhost:1234, docs/lmstudio.md).

{"gamemode": bool, "steam": bool,
 "lmstudio": {"running": bool, "serving": bool, "first": id, "list": "id, id"}}
"""

import json
import subprocess
import urllib.request

from common import output

LMSTUDIO_MODELS = "http://127.0.0.1:1234/api/v0/models"


def loaded_models() -> list[str]:
    """LM Studio's own REST API lists every model with its load state."""
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(LMSTUDIO_MODELS, timeout=1) as response:
            data = json.load(response).get("data") or []
        return [m["id"] for m in data if m.get("state") == "loaded"]
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        return []


def main() -> None:
    apps = {line.strip() for line in output("flatpak", "ps", "--columns=application").splitlines()}
    gamemode = "is active" in output("gamemoded", "-s")
    try:
        native_steam = subprocess.run(["pgrep", "-x", "steam"], stdout=subprocess.DEVNULL).returncode == 0
    except OSError:
        native_steam = False
    steam = "com.valvesoftware.Steam" in apps or native_steam
    lms = "ai.lmstudio.lm-studio" in apps
    models = loaded_models() if lms else []
    print(
        json.dumps(
            {
                "gamemode": gamemode,
                "steam": steam,
                "lmstudio": {
                    "running": lms,
                    "serving": len(models) > 0,
                    "first": models[0] if models else "",
                    "list": ", ".join(models),
                },
            },
            separators=(",", ":"),
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
