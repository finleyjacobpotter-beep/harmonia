#! /usr/bin/env nix-shell
#! nix-shell -i python3 -p python3
"""Unlock an installed machine's encrypted root with the TPM and a PIN,
keeping the passphrase as the fallback.

Finds the LUKS partition behind cryptroot (the name scripts/install.py and
docs/install.md give it), checks for a TPM2 and a passphrase key slot, has
you type the passphrase once to prove it opens the disk, then replaces any
TPM key slot with one that needs the TPM and a PIN. The passphrase slot is
never touched. Nothing secret passes through this script: cryptsetup and
systemd-cryptenroll ask for the passphrase and PIN themselves.

    sudo ./scripts/tpm-pin.py

The TPM releases the key only while PCR 7 (the Secure Boot state) is as it
is now; docs/install.md has what changes it and how to enroll again. The
systemd initrd (on in harmonia's hosts, hosts/base.nix) uses the TPM key
slot without any more configuration.
"""

import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

MAPPER = "cryptroot"
# The same PCR as scripts/install.py's TPM_PCRS.
TPM_PCRS = "7"


def die(msg: str) -> None:
    sys.exit(f"error: {msg}")


def run(*cmd: str) -> None:
    print("+", shlex.join(cmd))
    result = subprocess.run(cmd)
    if result.returncode != 0:
        die(f"{cmd[0]} failed with exit code {result.returncode}")


def capture(*cmd: str) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        die(f"{shlex.join(cmd)} failed: {result.stderr.strip()}")
    return result.stdout


def luks_device() -> str:
    """The partition cryptroot is opened from."""
    status = capture("cryptsetup", "status", MAPPER)
    match = re.search(r"^\s*device:\s*(\S+)", status, re.MULTILINE)
    if not match:
        die(f"{MAPPER} is not an open LUKS device")
    return match.group(1)


def slots(device: str) -> list[tuple[str, str]]:
    """(slot, type) for each key slot, as systemd-cryptenroll lists them."""
    found = []
    for line in capture("systemd-cryptenroll", device).splitlines()[1:]:
        fields = line.split()
        if len(fields) >= 2:
            found.append((fields[0], fields[1]))
    return found


def ask(question: str) -> bool:
    return input(f"{question} [y/N] ").strip().lower().startswith("y")


def main() -> None:
    if os.geteuid() != 0:
        die(f"run as root (sudo {sys.argv[0]})")
    version = Path("/sys/class/tpm/tpm0/tpm_version_major")
    if not (version.is_file() and version.read_text().strip() == "2"):
        die("no TPM2 found; turn it on in the firmware (fTPM, PTT or Security Device Support)")

    device = luks_device()
    before = slots(device)
    print(f"{MAPPER} is opened from {device}. Key slots now:")
    for slot, kind in before:
        print(f"  {slot}  {kind}")
    if not any(kind == "password" for _, kind in before):
        die("no passphrase slot to fall back on; add one first (cryptsetup luksAddKey)")

    print("\nFirst, type the passphrase to show it still opens the disk; it stays the fallback.")
    while subprocess.run(["cryptsetup", "open", "--test-passphrase", device]).returncode != 0:
        if not ask("That didn't open it. Try again?"):
            die("aborted; nothing was changed")

    replacing = any(kind == "tpm2" for _, kind in before)
    print(f"\nNext: {'replace the TPM key slot with' if replacing else 'add'} one that needs the TPM and a PIN.")
    print("systemd-cryptenroll asks for the passphrase again, then the new PIN twice.")
    if not ask("Continue?"):
        die("aborted; nothing was changed")
    run("systemd-cryptenroll", "--wipe-slot=tpm2", "--tpm2-device=auto",
        f"--tpm2-pcrs={TPM_PCRS}", "--tpm2-with-pin=yes", device)

    after = slots(device)
    print("\nKey slots now:")
    for slot, kind in after:
        print(f"  {slot}  {kind}")
    if not any(kind == "tpm2" for _, kind in after) or not any(kind == "password" for _, kind in after):
        die("expected a passphrase slot and a TPM slot; check the list above")
    print("\nDone. At the next boot, type the PIN. If the TPM refuses (PCR 7 changed), you are"
          " asked for the passphrase instead; then run this again to enroll anew.")


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, EOFError):
        sys.exit("\naborted")
