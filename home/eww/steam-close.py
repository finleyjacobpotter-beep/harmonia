"""Quit Steam the way its own menu does (steam -shutdown), for whichever
install is running: Flathub or native.
"""

import shutil
import subprocess


def flatpak_running(app: str) -> bool:
    try:
        out = subprocess.run(["flatpak", "ps", "--columns=application"], capture_output=True, text=True).stdout
    except OSError:
        return False
    return app in (line.strip() for line in out.splitlines())


if __name__ == "__main__":
    if flatpak_running("com.valvesoftware.Steam"):
        subprocess.run(["flatpak", "run", "com.valvesoftware.Steam", "-shutdown"])
    elif shutil.which("steam"):
        subprocess.run(["steam", "-shutdown"])
