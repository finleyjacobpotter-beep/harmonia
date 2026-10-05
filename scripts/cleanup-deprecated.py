#! /usr/bin/env nix-shell
#! nix-shell -i python3 -p python3
"""Remove what harmonia used to install but no longer manages.

nixos-rebuild and home-manager drop the packages, units and dotfiles a
config stops declaring, but not the state those things left behind: Flathub
apps (nix-flatpak never uninstalls), their ~/.var/app data, libvirt's disks
and definitions, app settings in ~/.config. This script finds that state and
removes it. Everything it knows about:

  Zen browser        app.zen_browser.zen flatpak and override, its
                     ~/.var/app data, mimeapps.list entries, ~/Downloads/zen
                     (replaced by Firefox, PR #37)
  opencode flatpak   ai.opencode.opencode and its ~/.var/app data (opencode
                     moved into Zelus, PR #28)
  libvirt VMs        harmonia-kali / harmonia-ubuntu: disks, ISOs, NVRAM,
                     TPM state, nwfilters, the default network, virbr0,
                     virt-manager settings, ~/vms/kali-shared (replaced by the
                     Nike microVM, PR #26)
  Proton VPN app     its ~/.config, ~/.cache and ~/.local/share dirs
                     (replaced by openfortivpn, PR #32)
  Vagrant            ~/.vagrant.d (removed in PR #5)
  cadmus: LACT       the LACT flatpak, its data and /etc/lact (cadmus uses
                     thinkfan, PR #29)
  dionysus: Blender, Godot and native Firefox settings (PR #36, PR #37)
  unused flatpak runtimes left behind by the apps above

It only reports, never deletes, the pass entry opencode/anthropic-api-key.

Dry run by default: it lists what it would remove and changes nothing.

    sudo harmonia-cleanup                       # list
    sudo harmonia-cleanup --apply               # remove
    sudo harmonia-cleanup --apply --user-files

Every host has it on its PATH (hosts/base.nix); before the first rebuild
that adds it, run this file directly: sudo ./scripts/cleanup-deprecated.py

Things that hold your own files (a non-empty ~/Downloads/zen or
~/vms/kali-shared, Dionysus's old ~/.mozilla profile, home-manager's
*.hm-backup copies of your pre-harmonia dotfiles) are only removed with
--user-files. Run it with sudo: system state (/var/lib/libvirt, system
flatpaks) needs root; without it those steps are listed as skipped. The
host is read from the hostname (--host overrides it) and your user from
SUDO_USER (--user overrides it).

Idempotent: anything already gone is skipped, so it is safe to re-run.
"""

import argparse
import os
import pwd
import shutil
import socket
import subprocess
import sys
from pathlib import Path

HOSTS = ("harmonia", "cadmus", "dionysus")
DEFAULT_USERS = {"harmonia": "u", "cadmus": "u", "dionysus": "d"}

ZEN = "app.zen_browser.zen"
OPENCODE = "ai.opencode.opencode"
LACT = "io.github.ilya_zlobintsev.LACT"

LIBVIRT_DOMAINS = ("harmonia-kali", "harmonia-ubuntu")
LIBVIRT_FILTERS = (
    "harmonia-vm-kali",
    "harmonia-vm-ubuntu",
    "harmonia-open",
    "harmonia-internet-only",
    "harmonia-isolated",
)
LIBVIRT_STATE = (
    "/var/lib/libvirt",
    "/var/cache/libvirt",
    "/var/log/libvirt",
    "/var/lib/swtpm-localca",
)


class Cleanup:
    def __init__(self, host: str, user: pwd.struct_passwd, apply: bool, user_files: bool):
        self.host = host
        self.user = user
        self.home = Path(user.pw_dir)
        self.apply = apply
        self.user_files = user_files
        self.root = os.geteuid() == 0
        self.found = 0
        self.failed = 0
        self.title = ""
        self.kept = 0

    # -- reporting -------------------------------------------------------

    def section(self, title: str) -> None:
        """Start a section; its title is printed with its first line."""
        self.title = title

    def say(self, line: str) -> None:
        if self.title:
            print(f"\n==> {self.title}")
            self.title = ""
        print(line, flush=True)

    def item(self, text: str, *, root: bool = False, mine: bool = False) -> bool:
        """Report one thing to remove, and say whether to remove it now."""
        self.found += 1
        if mine and not self.user_files:
            self.kept += 1
            self.say(f"  keep    {text}  (your files: pass --user-files)")
            return False
        if root and not self.root:
            self.say(f"  skip    {text}  (needs sudo)")
            return False
        self.say(f"  {'remove' if self.apply else 'would '}  {text}")
        return self.apply

    def note(self, text: str) -> None:
        self.say(f"  note    {text}")

    # -- helpers ---------------------------------------------------------

    def run(self, *args: str, as_user: bool = False) -> bool:
        cmd = list(args)
        if as_user and self.root and self.user.pw_uid != 0:
            bus = f"unix:path=/run/user/{self.user.pw_uid}/bus"
            cmd = ["runuser", "-u", self.user.pw_name, "--", "env", f"DBUS_SESSION_BUS_ADDRESS={bus}", *cmd]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            self.failed += 1
            print(f"  failed  {' '.join(args)}: {result.stderr.strip()}", file=sys.stderr)
        return result.returncode == 0

    def output(self, *args: str, as_user: bool = False) -> str:
        """A command's stdout, or "" if it is missing or fails."""
        cmd = list(args)
        if as_user and self.root and self.user.pw_uid != 0:
            cmd = ["runuser", "-u", self.user.pw_name, "--", *cmd]
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
        except OSError:
            return ""
        return result.stdout.strip() if result.returncode == 0 else ""

    def remove(self, path: Path | str, why: str = "", *, mine: bool = False) -> None:
        """Delete a file, symlink or directory tree if it exists."""
        path = Path(path)
        if not os.path.lexists(path):
            return
        system = not path.is_relative_to(self.home)
        label = f"{path}{f'  ({why})' if why else ''}"
        if not self.item(label, root=system and not os.access(path.parent, os.W_OK), mine=mine):
            return
        try:
            if path.is_dir() and not path.is_symlink():
                shutil.rmtree(path)
            else:
                path.unlink()
        except OSError as e:
            self.failed += 1
            print(f"  failed  {path}: {e}", file=sys.stderr)

    def remove_if_empty(self, path: Path) -> None:
        """Remove an empty directory; one with files in it is your data."""
        if not path.is_dir():
            return
        if any(path.iterdir()):
            self.remove(path, "not empty", mine=True)
        else:
            self.remove(path, "empty")

    # -- flatpak ---------------------------------------------------------

    def flatpak(self, app: str, why: str) -> None:
        """Uninstall an app from the system and the user installation, and
        drop its overrides and ~/.var/app data."""
        if shutil.which("flatpak"):
            for scope in ("--system", "--user"):
                as_user = scope == "--user"
                if not self.output("flatpak", "info", scope, app, as_user=as_user):
                    continue
                if self.item(f"flatpak {scope[2:]} {app}  ({why})", root=not as_user):
                    self.run("flatpak", "uninstall", scope, "-y", "--noninteractive", app, as_user=as_user)
        self.remove(Path("/var/lib/flatpak/overrides", app), "flatpak override")
        self.remove(self.home / ".local/share/flatpak/overrides" / app, "flatpak override")
        self.remove(self.home / ".var/app" / app, f"{why}: app data")

    def unused_runtimes(self) -> None:
        """Runtimes nothing uses any more (the removed apps' ones). flatpak
        keeps runtimes that were installed on purpose, like Lutris's GL32."""
        if not shutil.which("flatpak"):
            return
        if not self.apply:
            self.note("--apply also runs `flatpak uninstall --unused` (system and user)")
            return
        for scope in ("--system", "--user"):
            if scope == "--system" and not self.root:
                continue
            self.say(f"  run     flatpak uninstall {scope} --unused")
            self.run("flatpak", "uninstall", scope, "--unused", "-y", "--noninteractive", as_user=scope == "--user")

    def mimeapps(self, desktop_ids: list[str]) -> None:
        """Drop removed apps from an unmanaged ~/.config/mimeapps.list."""
        path = self.home / ".config/mimeapps.list"
        if not path.is_file() or path.is_symlink():
            return
        lines = path.read_text().splitlines(keepends=True)
        out, changed = [], 0
        for line in lines:
            key, sep, value = line.partition("=")
            if sep and any(d in value for d in desktop_ids):
                kept = [v for v in value.strip().split(";") if v and v not in desktop_ids]
                changed += 1
                if not kept:
                    continue
                line = f"{key}={';'.join(kept)};\n"
            out.append(line)
        if changed and self.item(f"{path}: {changed} association(s) with {', '.join(desktop_ids)}"):
            path.write_text("".join(out))

    # -- the deprecations ------------------------------------------------

    def zen(self) -> None:
        self.section("Zen browser (replaced by Firefox)")
        self.flatpak(ZEN, "Zen")
        self.mimeapps([f"{ZEN}.desktop"])
        self.remove_if_empty(self.home / "Downloads/zen")

    def opencode(self) -> None:
        self.section("opencode flatpak (opencode runs in Zelus now)")
        self.flatpak(OPENCODE, "opencode")
        self.mimeapps([f"{OPENCODE}.desktop"])
        store = Path(os.environ.get("PASSWORD_STORE_DIR", self.home / ".local/share/password-store"))
        if (store / "opencode/anthropic-api-key.gpg").exists():
            self.note("pass entry opencode/anthropic-api-key is no longer used; remove it yourself with `pass rm` if you like")

    def libvirt_active(self) -> bool:
        """Whether this machine still runs libvirt (not from harmonia)."""
        return bool(self.output("systemctl", "list-unit-files", "libvirtd.service", "--no-legend"))

    def libvirt(self) -> None:
        self.section("libvirt Kali/Ubuntu VMs (replaced by the Nike microVM)")
        if self.libvirt_active():
            # Something else enabled libvirt here: only take out harmonia's VMs.
            self.note("libvirtd is installed, so only harmonia's own domains and files go")
            virsh = ["virsh", "-c", "qemu:///system"]
            for name in LIBVIRT_DOMAINS:
                if not self.output(*virsh, "domuuid", name):
                    continue
                if self.item(f"libvirt domain {name}", root=True):
                    if self.output(*virsh, "domstate", name) == "running":
                        self.run(*virsh, "destroy", name)
                    self.run(*virsh, "undefine", name, "--nvram", "--tpm")
            for name in LIBVIRT_FILTERS:
                if self.output(*virsh, "nwfilter-dumpxml", name) and self.item(f"libvirt nwfilter {name}", root=True):
                    self.run(*virsh, "nwfilter-undefine", name)
            images = Path("/var/lib/libvirt/images")
            for pattern in ("harmonia-*.qcow2", "kali-linux-*-installer-amd64.iso*", "ubuntu-*-desktop-amd64.iso*"):
                for path in sorted(images.glob(pattern)) if images.is_dir() else []:
                    self.remove(path, "harmonia VM disk / installer")
        else:
            for path in LIBVIRT_STATE:
                self.remove(path, "libvirt state: VM disks, ISOs, NVRAM, TPM, nwfilters, networks")
            if Path("/sys/class/net/virbr0").exists() and self.item("network interface virbr0 (libvirt's default network)", root=True):
                self.run("ip", "link", "delete", "virbr0")
                self.note("reboot once to clear the firewall rules libvirt left in the running kernel")
            for rel in (".config/libvirt", ".cache/libvirt", ".local/share/libvirt", ".cache/virt-manager"):
                self.remove(self.home / rel, "libvirt / virt-manager")
            if shutil.which("dconf") and self.output("dconf", "dump", "/org/virt-manager/", as_user=True):
                if self.item("dconf /org/virt-manager/ (virt-manager settings)"):
                    self.run("dconf", "reset", "-f", "/org/virt-manager/", as_user=True)
        self.remove_if_empty(self.home / "vms/kali-shared")
        vms = self.home / "vms"
        if vms.is_dir() and not any(vms.iterdir()):
            self.remove(vms, "empty")

    def proton(self) -> None:
        self.section("Proton VPN app (replaced by openfortivpn)")
        for rel in (".config/Proton", ".cache/Proton", ".local/share/Proton"):
            self.remove(self.home / rel, "Proton VPN app")

    def vagrant(self) -> None:
        self.section("Vagrant")
        self.remove(self.home / ".vagrant.d", "Vagrant boxes and plugins")

    def lact(self) -> None:
        self.section("LACT on cadmus (cadmus uses thinkfan)")
        self.flatpak(LACT, "LACT")
        self.remove("/etc/lact", "LACT daemon config")

    def dionysus_apps(self) -> None:
        self.section("Dionysus: Blender, Godot and native Firefox")
        for rel in (".config/blender", ".cache/blender", ".config/godot", ".local/share/godot", ".cache/godot"):
            self.remove(self.home / rel, "Blender/Godot settings")
        self.remove(self.home / ".mozilla", "native Firefox profile: bookmarks, history, logins", mine=True)
        self.remove(self.home / ".cache/mozilla", "native Firefox cache")

    def hm_backups(self) -> None:
        """home-manager moves a file it would overwrite to *.hm-backup
        (flake.nix). These are copies of your dotfiles from before harmonia."""
        self.section("home-manager backups (*.hm-backup)")
        found = [p for p in self.home.glob("*.hm-backup")]
        for top in (".config", ".local/share", ".local/bin", ".claude", ".ssh", ".gnupg"):
            for dirpath, dirnames, filenames in os.walk(self.home / top):
                rel = Path(dirpath).relative_to(self.home / top)
                if len(rel.parts) >= 3 or rel.parts[:1] == ("flatpak",):
                    dirnames[:] = []
                found += [Path(dirpath, n) for n in filenames + dirnames if n.endswith(".hm-backup")]
        for path in sorted(found):
            self.remove(path, "pre-harmonia copy", mine=True)

    def run_all(self) -> None:
        self.zen()
        self.opencode()
        self.libvirt()
        self.proton()
        self.vagrant()
        if self.host == "cadmus":
            self.lact()
        if self.host == "dionysus":
            self.dionysus_apps()
        self.hm_backups()
        self.section("Unused flatpak runtimes")
        self.unused_runtimes()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Remove state left behind by things harmonia no longer manages (dry run unless --apply).",
    )
    parser.add_argument("--apply", action="store_true", help="actually remove things (default: only list them)")
    parser.add_argument("--user-files", action="store_true", help="also remove things holding your own files")
    parser.add_argument("--host", choices=HOSTS, help="host config this machine runs (default: its hostname)")
    parser.add_argument("--user", help="your user (default: SUDO_USER, or the host's default)")
    args = parser.parse_args()

    host = args.host or socket.gethostname().split(".")[0]
    if host not in HOSTS:
        sys.exit(f"unknown host {host!r}; pass --host {'|'.join(HOSTS)}")
    name = args.user or os.environ.get("SUDO_USER") or (
        pwd.getpwuid(os.geteuid()).pw_name if os.geteuid() != 0 else DEFAULT_USERS[host]
    )
    try:
        user = pwd.getpwnam(name)
    except KeyError:
        sys.exit(f"no such user {name!r}; pass --user")

    cleanup = Cleanup(host, user, args.apply, args.user_files)
    mode = "removing" if args.apply else "dry run, nothing is changed"
    print(f"harmonia cleanup on {host} for {user.pw_name} ({user.pw_dir}): {mode}")
    if not cleanup.root:
        print("not root: system state is listed but left alone (run with sudo)")
    cleanup.run_all()

    print()
    if not cleanup.found:
        print("Nothing left to clean up.")
    elif not args.apply:
        extra = f" (add --user-files for the {cleanup.kept} kept)" if cleanup.kept else ""
        print(f"{cleanup.found} item(s) found. Re-run with --apply to remove them{extra}.")
    else:
        print(f"Done. {cleanup.failed} step(s) failed." if cleanup.failed else "Done.")
    sys.exit(1 if cleanup.failed else 0)


if __name__ == "__main__":
    main()
