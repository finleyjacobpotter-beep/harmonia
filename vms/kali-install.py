#!/usr/bin/env python3
"""Set up harmonia's i3 desktop in the Kali guest: installs i3 and the tools
the config uses, then copies everything next to this script into place
(existing files are kept as *.bak).

Usage (in the Kali guest; see docs/vms-and-containers.md):
  mkdir -p ~/shared && sudo mount -t virtiofs shared ~/shared
  python3 ~/shared/harmonia/install.py
"""

import getpass
import os
import pwd
import shutil
import subprocess
from pathlib import Path

# modules/nixos/vms.nix replaces this with the share's path on the host.
HOST_SHARE = "the host's share"

SRC = Path(__file__).resolve().parent
HOME = Path.home()
PACKAGES = """
    kali-desktop-i3 i3status rofi dunst feh maim xclip i3lock xss-lock
    x11-xserver-utils python3 alacritty neovim ripgrep fd-find git
    bash-completion fzf tmux ranger
""".split()


def run(*args: str) -> None:
    subprocess.run(args, check=True)


def put(src: str, dest: Path) -> None:
    """Copy src (following links) to dest, keeping what was there as dest.bak."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() or dest.is_symlink():
        backup = dest.with_name(dest.name + ".bak")
        if backup.is_dir() and not backup.is_symlink():
            shutil.rmtree(backup)
        elif backup.exists() or backup.is_symlink():
            backup.unlink()
        dest.rename(backup)
    source = SRC / src
    if source.is_dir():
        shutil.copytree(source, dest)
    else:
        shutil.copy2(source, dest)
    for root, dirs, files in os.walk(dest):
        for path in [root] + [os.path.join(root, f) for f in files]:
            os.chmod(path, os.stat(path).st_mode | 0o200)


def main() -> None:
    run("sudo", "apt-get", "update")
    run("sudo", "apt-get", "install", "-y", *PACKAGES)

    put("i3/config", HOME / ".config/i3/config")
    put("i3status/config", HOME / ".config/i3status/config")
    put("harmonia-status", HOME / ".local/bin/harmonia-status")
    (HOME / ".local/bin/harmonia-status").chmod(0o755)
    put("wallpaper.png", HOME / ".local/share/harmonia/wallpaper.png")
    put("nvim/config", HOME / ".config/nvim")
    put("nvim/pack", HOME / ".local/share/nvim/site/pack/hm")
    put("bash/bashrc", HOME / ".bashrc")
    put("bash/inputrc", HOME / ".inputrc")

    # bash instead of Kali's default zsh
    user = getpass.getuser()
    if pwd.getpwnam(user).pw_shell != "/bin/bash":
        run("sudo", "chsh", "-s", "/bin/bash", user)

    # Mount the read-write share (host: HOST_SHARE) at ~/shared on boot.
    (HOME / "shared").mkdir(parents=True, exist_ok=True)
    fstab = Path("/etc/fstab").read_text()
    if not any(line.startswith("shared ") for line in fstab.splitlines()):
        entry = f"shared {HOME}/shared virtiofs defaults,nofail 0 0\n"
        subprocess.run(["sudo", "tee", "-a", "/etc/fstab"], input=entry, text=True, stdout=subprocess.DEVNULL, check=True)
    run("sudo", "systemctl", "daemon-reload")

    print("Done. Log out and pick i3 at the login screen; the i3 modifier is Alt.")
    print(f"~/shared is the read-write share with the host ({HOST_SHARE}); re-run this script after a host rebuild to update.")


if __name__ == "__main__":
    main()
