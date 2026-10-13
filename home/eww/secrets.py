"""Secrets at a glance for the dash's secrets tile (home/eww/eww.yuck,
home/secrets.nix): whether the Bitwarden vault is unlocked, which keys
ssh-agent and gpg-agent hold, whether a YubiKey is plugged in, the KeePassXC
database, the sops age key, and the last secrets-backup. Nothing here reads
a secret: only whether one is there.

Usage: eww-secrets              JSON for the tile
       eww-secrets bw-lock      lock the Bitwarden vault (as bw-lock does)
       eww-secrets ssh-forget   remove every key from ssh-agent
       eww-secrets gpg-forget   make gpg-agent forget cached passphrases
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

from common import RUN_DIR, output, read

HOME = Path.home()
BW_SESSION = RUN_DIR / "bw-session"
YUBICO = "1050"


def ago(path: Path) -> str:
    """How long ago a file changed, roughly."""
    try:
        seconds = time.time() - path.stat().st_mtime
    except OSError:
        return ""
    for unit, size in (("d", 86400), ("h", 3600), ("min", 60)):
        if seconds >= size:
            return f"{int(seconds // size)} {unit} ago"
    return "just now"


def agent_env() -> dict:
    """ssh-agent's socket, from home-manager's services.ssh-agent, in case
    eww started without it."""
    env = dict(os.environ)
    env.setdefault("SSH_AUTH_SOCK", str(RUN_DIR / "ssh-agent"))
    return env


def ssh_keys() -> list:
    out = subprocess.run(["ssh-add", "-l"], capture_output=True, text=True, env=agent_env()).stdout
    keys = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[1].startswith("SHA256:"):
            # "256 SHA256:… comment (ED25519)": the comment, else the fingerprint.
            comment = " ".join(parts[2:-1]) or parts[1][:20]
            keys.append({"name": comment, "type": parts[-1].strip("()")})
    return keys


def gpg_cached() -> int:
    """Keys whose passphrase gpg-agent has cached (KEYINFO's 7th field)."""
    out = output("gpg-connect-agent", "keyinfo --list", "/bye")
    return sum(1 for line in out.splitlines() if line.startswith("S KEYINFO") and line.split()[6:7] == ["1"])


def yubikeys() -> list:
    found = []
    for dev in Path("/sys/bus/usb/devices").glob("*"):
        if read(dev / "idVendor") == YUBICO:
            found.append(read(dev / "product") or "YubiKey")
    return sorted(found)


def main(args: list[str]) -> None:
    command = args[0] if args else ""
    if command == "bw-lock":
        session = read(BW_SESSION).removeprefix("BW_SESSION=")
        subprocess.run(["bw", "lock"], env=dict(os.environ, BW_SESSION=session), capture_output=True)
        BW_SESSION.unlink(missing_ok=True)
    elif command == "ssh-forget":
        subprocess.run(["ssh-add", "-D"], capture_output=True, env=agent_env())
    elif command == "gpg-forget":
        output("gpgconf", "--reload", "gpg-agent")
    if command:
        output("eww", "update", f"secrets={state()}")
    else:
        print(state())


def state() -> str:
    db = Path(os.environ.get("KEEPASSXC_DB") or HOME / ".local/share/keepassxc/passwords.kdbx")
    config = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config")
    age = Path(os.environ.get("SOPS_AGE_KEY_FILE") or config / "sops/age/keys.txt")
    backups = sorted(HOME.glob("secrets-backup-*.tar.gz.gpg"), key=lambda p: p.stat().st_mtime)
    keys = ssh_keys()
    return json.dumps(
        {
            # bw-unlock leaves the session here and bw-lock removes it
            # (home/secrets.nix); asking bw itself takes a second or two.
            "bw": BW_SESSION.exists(),
            "ssh": keys,
            "gpg": gpg_cached(),
            "yubikeys": yubikeys(),
            "keepass": {"exists": db.exists(), "path": str(db).replace(str(HOME), "~"), "changed": ago(db)},
            "age": age.exists(),
            "backup": ago(backups[-1]) if backups else "",
            "locked": not BW_SESSION.exists() and not keys,
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )


if __name__ == "__main__":
    main(sys.argv[1:])
