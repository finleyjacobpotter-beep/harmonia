"""Copy themes, configs and add-ons into flatpak sandboxes (see
home/flatpak-files.nix). Sandboxed apps can't follow links into /nix/store,
so everything is a real, writable copy.

Usage: flatpak-miami-wind MANIFEST   (the wrapper passes the manifest)

MANIFEST is JSON: {"copies": {"<dest under ~>": "<store path>"},
                   "firefoxProfile": {"<dest in each profile>": "<store path>"}}
A directory is copied whole, and only again when its store path changes; a
file is reinstalled every time.
"""

import configparser
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

# The profile made before Firefox's first start, so the theme, vertical tabs
# and add-ons are there from the first launch. MOZ_LEGACY_PROFILES (set in
# modules/nixos/flatpak.nix) makes Firefox open it instead of making its own.
PROFILES_INI = """\
[General]
StartWithLastProfile=1
Version=2

[Profile0]
Name=harmonia
IsRelative=1
Path=harmonia
Default=1
"""


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


def read_ini(path: Path) -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str  # keep Firefox's key case
    parser.read(path)
    return parser


def ensure_firefox_profile() -> None:
    """Make the harmonia profile if Firefox has none yet. If Firefox made its
    own, mark the one it opens (installs.ini) as the default, so that with
    MOZ_LEGACY_PROFILES it keeps opening that one."""
    for root in FIREFOX_ROOTS:
        ini = root / "profiles.ini"
        if not ini.is_file():
            continue
        installs = read_ini(root / "installs.ini")
        used = [installs[s]["Default"] for s in installs.sections() if "Default" in installs[s]]
        if not used:
            return
        profiles = read_ini(ini)
        changed = False
        for section in profiles.sections():
            if not section.startswith("Profile"):
                continue
            want = profiles[section].get("Path") == used[0]
            if (profiles[section].get("Default") == "1") != want:
                changed = True
                if want:
                    profiles[section]["Default"] = "1"
                else:
                    profiles[section].pop("Default", None)
        if changed:
            with open(ini, "w") as f:
                profiles.write(f, space_around_delimiters=False)
            print(f"flatpak-miami-wind: made {used[0]} the default Firefox profile")
        return
    root = FIREFOX_ROOTS[0]
    (root / "harmonia").mkdir(parents=True, exist_ok=True)
    (root / "profiles.ini").write_text(PROFILES_INI)
    print(f"flatpak-miami-wind: made the Firefox profile {root / 'harmonia'}/")


def firefox_profiles() -> list[Path]:
    """Every profile profiles.ini lists, and any other directory Firefox has used."""
    profiles = set()
    for root in FIREFOX_ROOTS:
        ini = root / "profiles.ini"
        if ini.is_file():
            parser = read_ini(ini)
            for section in parser.sections():
                path = parser[section].get("Path")
                if section.startswith("Profile") and path:
                    relative = parser[section].get("IsRelative", "1") == "1"
                    profiles.add(root / path if relative else Path(path))
        if root.is_dir():
            for profile in root.iterdir():
                if (profile / "prefs.js").is_file() or (profile / "times.json").is_file():
                    profiles.add(profile)
    return sorted(p for p in profiles if p.is_dir())


def main() -> None:
    with open(sys.argv[1]) as f:
        manifest = json.load(f)

    for dest, src in manifest.get("copies", {}).items():
        copy(src, HOME / dest)

    profile_files = manifest.get("firefoxProfile", {})
    if not profile_files:
        return
    ensure_firefox_profile()
    for profile in firefox_profiles():
        for dest, src in profile_files.items():
            install(src, profile / dest)
        print(f"flatpak-miami-wind: themed {profile}/")


if __name__ == "__main__":
    main()
