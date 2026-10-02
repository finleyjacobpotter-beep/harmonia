"""secrets-backup [DIR]  (packaged as a command by home/secrets.nix)

Bundle the pass store, a Bitwarden export and your gpg keys (secret keys
included) into DIR/secrets-backup-<UTC timestamp>.tar.gz.gpg (DIR defaults
to $HOME), encrypted with a passphrase (AES-256) rather than a gpg key, so
the backup can still be opened after the keys themselves are lost.

Anything locked, logged out or not set up yet is skipped with a warning.
Plaintext only ever exists inside a private temporary directory, which is
removed on exit, and the tarball is streamed straight into gpg.
"""

import datetime as dt
import json
import os
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path


def warn(message: str) -> None:
    print(f"secrets-backup: {message}", file=sys.stderr)


def ok(*args: str, stdout: Path | None = None, quiet: bool = False) -> bool:
    """Run a command (its output into stdout if given) and say whether it worked."""
    try:
        if stdout is not None:
            with stdout.open("wb") as out:
                return subprocess.run(args, stdout=out).returncode == 0
        null = subprocess.DEVNULL
        return subprocess.run(args, stdout=null, stderr=null if quiet else None).returncode == 0
    except OSError as e:
        warn(f"{args[0]}: {e.strerror}")
        return False


def export_gpg(tmp: Path) -> bool:
    """Public and secret keys plus ownertrust. Secret keys stay protected by
    their own passphrase inside the export (gpg asks for it)."""
    keys = subprocess.run(["gpg", "--list-secret-keys", "--with-colons"], capture_output=True, text=True)
    if not keys.stdout.strip():
        warn("gpg: no secret keys, skipping")
        return False
    d = tmp / "gpg"
    d.mkdir()
    exports = [
        (["--armor", "--export"], "public-keys.asc"),
        (["--armor", "--export-secret-keys"], "secret-keys.asc"),
        (["--export-ownertrust"], "ownertrust.txt"),
    ]
    if all(ok("gpg", *flags, stdout=d / name) for flags, name in exports):
        return True
    warn("gpg: export failed, skipping")
    shutil.rmtree(d)
    return False


def copy_pass(tmp: Path) -> bool:
    """The store is already gpg-encrypted: copy it as is (with its git history)."""
    store = Path(os.environ.get("PASSWORD_STORE_DIR", Path.home() / ".password-store"))
    if not (store / ".gpg-id").is_file():
        warn(f"pass: no store at {store} (run 'pass init'), skipping")
        return False
    try:
        shutil.copytree(store, tmp / "pass", symlinks=True)
        return True
    except OSError:
        warn("pass: copy failed, skipping")
        shutil.rmtree(tmp / "pass", ignore_errors=True)
        return False


def export_bitwarden(tmp: Path) -> bool:
    """Needs an unlocked session (export BW_SESSION=$(bw unlock --raw))."""
    try:
        status = json.loads(subprocess.run(["bw", "status"], capture_output=True, text=True).stdout).get("status")
    except (OSError, ValueError, AttributeError):
        status = None
    if status != "unlocked":
        warn("bitwarden: vault is not unlocked (bw login / bw unlock), skipping")
        return False
    if not ok("bw", "sync", quiet=True):
        warn("bitwarden: sync failed, exporting the local copy")
    # bw asks for the master password again before exporting.
    out = tmp / "bitwarden.json"
    if ok("bw", "export", "--format", "json", "--output", str(out)):
        return True
    warn("bitwarden: export failed, skipping")
    out.unlink(missing_ok=True)
    return False


def encrypt(tmp: Path, out: Path) -> bool:
    """Stream a gzipped tarball of tmp into gpg. gpg asks for the backup
    passphrase twice through pinentry."""
    partial = out.with_name(out.name + ".partial")
    gpg = subprocess.Popen(
        [
            "gpg", "--yes", "--no-symkey-cache", "--symmetric", "--cipher-algo", "AES256",
            "--s2k-mode", "3", "--s2k-digest-algo", "SHA512", "--s2k-count", "65011712",
            "--output", str(partial),
        ],
        stdin=subprocess.PIPE,
    )
    assert gpg.stdin is not None
    try:
        with tarfile.open(fileobj=gpg.stdin, mode="w|gz") as tar:
            tar.add(tmp, arcname=".")
        gpg.stdin.close()
    except (OSError, tarfile.TarError):
        gpg.kill()
    if gpg.wait() == 0:
        partial.replace(out)
        return True
    partial.unlink(missing_ok=True)
    return False


def main(args: list[str]) -> int:
    os.umask(0o077)
    out_dir = Path(args[0]) if args else Path.home()
    if not out_dir.is_dir():
        warn(f"no such directory: {out_dir}")
        return 1

    tmp = Path(tempfile.mkdtemp())
    try:
        included = [
            name
            for name, step in (("gpg", export_gpg), ("pass", copy_pass), ("bitwarden", export_bitwarden))
            if step(tmp)
        ]
        if not included:
            warn("nothing to back up")
            return 1
        stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        out = out_dir / f"secrets-backup-{stamp}.tar.gz.gpg"
        if not encrypt(tmp, out):
            warn("encryption failed")
            return 1
        print(f"secrets-backup: wrote {out} ({' '.join(included)})")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def interrupted(signum: int, frame: object) -> None:
    sys.exit(130)


if __name__ == "__main__":
    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, interrupted)
    sys.exit(main(sys.argv[1:]))
