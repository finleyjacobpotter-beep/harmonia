"""Copy themes, configs and add-ons into flatpak sandboxes (see
home/flatpak-files.nix). Sandboxed apps can't follow links into /nix/store,
so everything is a real, writable copy.

Usage: flatpak-miami-wind MANIFEST   (the wrapper passes the manifest)

MANIFEST is JSON: {"copies": {"<dest under ~>": "<store path>"},
                   "firefoxProfile": {"<dest in each profile>": "<store path>"}}
A directory is copied whole, and only again when its store path changes; a
file is reinstalled every time.
"""

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

HOME = Path.home()
FIREFOX = HOME / ".var/app/org.mozilla.firefox"
# Profiles live in ~/.mozilla/firefox, or in the XDG location newer Firefox
# uses for fresh installs (~/.config inside the sandbox).
FIREFOX_ROOTS = [FIREFOX / ".mozilla/firefox", FIREFOX / "config/mozilla/firefox"]


def install(src: str, dest: Path) -> None:
    """A real, writable copy (install -Dm644), replacing whatever is there."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.is_symlink() or dest.exists():
        dest.unlink()
    shutil.copyfile(src, dest)
    dest.chmod(0o644)


def copy_tree(src: Path, dest: Path) -> None:
    """cp -r --no-preserve=mode,ownership: links stay links, the rest is writable."""
    for root, dirs, files in os.walk(src):
        target = dest / Path(root).relative_to(src)
        target.mkdir(parents=True, exist_ok=True)
        for name in dirs + files:
            path = Path(root, name)
            if path.is_symlink():
                (target / name).symlink_to(os.readlink(path))
            elif path.is_file():
                shutil.copyfile(path, target / name)


def copy_dir(src: str, dest: Path) -> None:
    """Real files, recopied only when the store path changes."""
    marker = dest / ".source"
    if marker.is_file() and marker.read_text().strip() == src:
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix=".copy.", dir=dest.parent))
    copy_tree(Path(src), tmp)
    (tmp / ".source").write_text(src + "\n")
    shutil.rmtree(dest, ignore_errors=True)
    tmp.rename(dest)
    print(f"flatpak-miami-wind: copied {dest}")


def copy(src: str, dest: Path) -> None:
    if Path(src).is_dir():
        copy_dir(src, dest)
    else:
        install(src, dest)


def firefox_profiles() -> list[Path]:
    profiles = []
    for root in FIREFOX_ROOTS:
        if not root.is_dir():
            continue
        for profile in sorted(root.iterdir()):
            if (profile / "prefs.js").is_file() or (profile / "times.json").is_file():
                profiles.append(profile)
    return profiles


def main() -> None:
    with open(sys.argv[1]) as f:
        manifest = json.load(f)

    for dest, src in manifest.get("copies", {}).items():
        copy(src, HOME / dest)

    profile_files = manifest.get("firefoxProfile", {})
    if not profile_files:
        return
    profiles = firefox_profiles()
    if not profiles:
        print("flatpak-miami-wind: no Firefox profile yet — start Firefox once, then re-run.", file=sys.stderr)
        return
    for profile in profiles:
        for dest, src in profile_files.items():
            install(src, profile / dest)
        print(f"flatpak-miami-wind: themed {profile}/")


if __name__ == "__main__":
    main()
