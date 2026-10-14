#! /usr/bin/env nix-shell
#! nix-shell -i python3 -p python3
"""Install base NixOS for harmonia, from the NixOS minimal ISO (UEFI).

Wipes one disk, creates a GPT table with a 1 GiB ESP and a root partition
(optionally LUKS2-encrypted, unlocked at boot by passphrase, TPM, or TPM
and PIN; always ext4), installs a small base system
that matches harmonia (systemd-boot, flakes, git), and clones harmonia
into the user's ~/harmonia with this machine's hardware-configuration.nix
already in place for the host you pick: harmonia (desktop, user u), cadmus
(laptop with Wi-Fi, user u) or dionysus (a VM with the dev tools built in
and no microVMs, user d; x86_64 or aarch64, picked from this machine).

Run it as root from the live ISO (the nix-shell line above fetches Python,
which the minimal ISO doesn't ship):

    sudo ./install.py

The walkthrough in docs/install.md explains each step.
"""

import getpass
import os
import platform
import re
import shlex
import shutil
import stat
import subprocess
import sys
from pathlib import Path

# host -> (description, login name set for it in flake.nix)
HOSTS = {
    "harmonia": ("desktop", "u"),
    "cadmus": ("laptop, with Wi-Fi", "u"),
    "dionysus": ("VM, dev tools built in, no microVMs", "d"),
}
REPO = "https://github.com/finleyjacobpotter-beep/harmonia"
STATE_VERSION = "26.05"

MNT = Path("/mnt")

# How the root partition is unlocked at boot. The passphrase is always
# enrolled as well, so a TPM that changes (firmware update, Secure Boot
# turned on, a new motherboard) still leaves a way in.
UNLOCK = {
    "passphrase": "type the passphrase at every boot",
    "tpm": "the TPM unlocks it by itself; anyone who can boot this machine can too",
    "tpm-pin": "the TPM unlocks it after you type a short PIN",
}
# The TPM releases the key only while PCR 7 (the Secure Boot state) is as it
# was at enrolment. Kernel and NixOS updates don't change it, so updates
# don't need re-enrolling; docs/install.md says how to after a firmware change.
TPM_PCRS = "7"

CONFIGURATION_NIX = """\
{{ pkgs, ... }}:
{{
  imports = [ ./hardware-configuration.nix ];

  # Same boot loader as harmonia.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # The systemd initrd unlocks LUKS with any TPM2 token in its header, as
  # harmonia's hosts do (nixpkgs' default there; hosts/base.nix).
  boot.initrd.systemd.enable = true;

  networking.hostName = "{hostname}";
  networking.networkmanager.enable = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  users.users.{username} = {{
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  }};

  # Flakes are needed to build harmonia.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [ git vim ];

  system.stateVersion = "{state_version}";
}}
"""


def die(msg: str) -> None:
    sys.exit(f"error: {msg}")


def run(*cmd: str, input: str | None = None, check: bool = True) -> bool:
    """Run a command, echoing it first. Returns True if it succeeded."""
    print("+", shlex.join(cmd))
    result = subprocess.run(cmd, input=input, text=True)
    if check and result.returncode != 0:
        die(f"{cmd[0]} failed with exit code {result.returncode}")
    return result.returncode == 0


def quiet(*cmd: str) -> bool:
    """Run a command with no output, ignoring failure (cleanup, probes)."""
    return subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def ask(question: str) -> bool:
    return input(f"{question} [y/N] ").strip().lower().startswith("y")


def read_secret(what: str) -> str:
    """Read a passphrase or PIN without echo, then show it back to confirm."""
    while True:
        secret = getpass.getpass(f"{what}: ")
        if not secret:
            print(f"The {what} can't be empty.")
            continue
        print(f"You entered: {secret}")
        if ask("Is that correct?"):
            os.system("clear")  # take it off the screen
            return secret


def has_tpm2() -> bool:
    version = Path("/sys/class/tpm/tpm0/tpm_version_major")
    return version.is_file() and version.read_text().strip() == "2"


def ask_unlock() -> str:
    """Passphrase, TPM or TPM and PIN; only the passphrase without a TPM2."""
    if not has_tpm2():
        print("No TPM2 found (or it is off in the firmware); the passphrase unlocks it.")
        return "passphrase"
    print("How should the root partition be unlocked at boot?")
    for i, (mode, what) in enumerate(UNLOCK.items(), 1):
        print(f"  {i}) {mode}: {what}")
    choice = input("Unlock [1]: ").strip() or "1"
    if choice not in {str(i) for i in range(1, len(UNLOCK) + 1)}:
        die(f"{choice!r} is not 1 to {len(UNLOCK)}")
    mode = list(UNLOCK)[int(choice) - 1]
    if mode != "passphrase":
        print("The passphrase you set next stays as the fallback; keep it somewhere safe.")
    return mode


def partitions(disk: str) -> tuple[str, str]:
    # NVMe and MMC partitions get a "p" before the number.
    prefix = f"{disk}p" if disk[-1].isdigit() else disk
    return f"{prefix}1", f"{prefix}2"


def preflight() -> None:
    if os.geteuid() != 0:
        die(f"run as root (sudo {sys.argv[0]})")
    if not Path("/sys/firmware/efi/efivars").is_dir():
        die("not booted in UEFI mode; turn off CSM/legacy boot in the firmware")
    if not quiet("ping", "-c", "1", "-W", "5", "nixos.org"):
        die("no network; connect with nmtui first")


def ask_settings() -> dict:
    subprocess.run(["lsblk", "-d", "-e", "7", "-o", "NAME,SIZE,MODEL,TYPE"])
    print()
    disk = input("Disk to install on (e.g. /dev/nvme0n1, /dev/sda): ").strip()
    if not (Path(disk).exists() and stat.S_ISBLK(os.stat(disk).st_mode)):
        die(f"{disk} is not a block device")

    print("Hosts: " + ", ".join(f"{h} ({what})" for h, (what, _) in HOSTS.items()))
    host = input("Host to install: ").strip()
    if host not in HOSTS:
        die(f"{host!r} is not one of {', '.join(HOSTS)}")

    luks = ask("Use LUKS encryption for the root partition?")
    unlock = ask_unlock() if luks else None
    swap = input("Swap file size in GiB (0 for none): ").strip()
    if not re.fullmatch(r"[0-9]+", swap):
        die("swap size must be a whole number")

    esp, root = partitions(disk)
    return {
        "host": host,
        "flake": flake_output(host),
        "user": HOSTS[host][1],
        "disk": disk,
        "esp": esp,
        "root": root,
        "luks": luks,
        "unlock": unlock,
        "passphrase": read_secret("LUKS passphrase") if luks else None,
        "pin": read_secret("TPM PIN") if unlock == "tpm-pin" else None,
        "swap_gib": int(swap),
    }


def flake_output(host: str) -> str:
    """Dionysus has one flake output per architecture; pick this machine's."""
    if host != "dionysus":
        return host
    machine = platform.machine()
    if machine == "x86_64":
        return "dionysus"
    if machine == "aarch64":
        return "dionysus-aarch64"
    die(f"dionysus is built for x86_64 and aarch64, not {machine}")


def confirm(s: dict) -> None:
    print(f"\nAbout to ERASE {s['disk']} and install:")
    print(f"  {s['esp']}  1 GiB ESP (vfat, label boot) at /boot")
    print(f"  {s['root']} rest of the disk, ext4 (label nixos){' inside LUKS2' if s['luks'] else ''}")
    if s["luks"]:
        print(f"  unlocked by {s['unlock']}" + ("" if s["unlock"] == "passphrase" else " (passphrase as fallback)"))
    if s["swap_gib"]:
        print(f"  {s['swap_gib']} GiB swap file at /swap/swapfile")
    print(f"  host {s['host']} (flake .#{s['flake']}), user {s['user']}")
    if input("Type ERASE to continue: ") != "ERASE":
        die("aborted")


def partition_and_mount(s: dict) -> None:
    quiet("swapoff", "-a")
    quiet("umount", "-R", str(MNT))
    quiet("cryptsetup", "close", "cryptroot")

    run("wipefs", "-af", s["disk"])
    run("parted", "-s", s["disk"], "--",
        "mklabel", "gpt",
        "mkpart", "ESP", "fat32", "1MiB", "1GiB",
        "set", "1", "esp", "on",
        "mkpart", "root", "1GiB", "100%")
    run("udevadm", "settle")

    run("mkfs.fat", "-F", "32", "-n", "boot", s["esp"])

    root_fs = s["root"]
    if s["luks"]:
        # --key-file=- reads the passphrase from stdin up to EOF; no trailing
        # newline is sent, so it matches what you type at the boot prompt.
        run("cryptsetup", "luksFormat", "--type", "luks2", "--batch-mode",
            "--key-file=-", s["root"], input=s["passphrase"])
        run("cryptsetup", "open", "--key-file=-", s["root"], "cryptroot",
            input=s["passphrase"])
        if s["unlock"] != "passphrase":
            enroll_tpm(s)
        s["passphrase"] = s["pin"] = None
        root_fs = "/dev/mapper/cryptroot"

    run("mkfs.ext4", "-F", "-L", "nixos", root_fs)
    run("mount", root_fs, str(MNT))
    (MNT / "boot").mkdir(parents=True, exist_ok=True)
    run("mount", "-o", "umask=077", s["esp"], str(MNT / "boot"))

    if s["swap_gib"]:
        swapfile = MNT / "swap/swapfile"
        swapfile.parent.mkdir(parents=True, exist_ok=True)
        run("dd", "if=/dev/zero", f"of={swapfile}", "bs=1M",
            f"count={s['swap_gib'] * 1024}", "status=progress")
        swapfile.chmod(0o600)
        run("mkswap", str(swapfile))
        run("swapon", str(swapfile))


def enroll_tpm(s: dict) -> None:
    """Add a TPM2 key slot beside the passphrase. systemd-cryptenroll reads
    the passphrase that unlocks the partition from $PASSWORD and the new PIN
    from $NEWPIN, so neither shows up in the process list."""
    env = dict(os.environ, PASSWORD=s["passphrase"])
    cmd = ["systemd-cryptenroll", "--tpm2-device=auto", f"--tpm2-pcrs={TPM_PCRS}"]
    if s["unlock"] == "tpm-pin":
        cmd.append("--tpm2-with-pin=yes")
        env["NEWPIN"] = s["pin"]
    cmd.append(s["root"])
    print("+", shlex.join(cmd))
    if subprocess.run(cmd, env=env).returncode != 0:
        # The disk is already encrypted with the passphrase; carry on with it.
        print("warning: couldn't enroll the TPM; the passphrase unlocks it. Enroll later as"
              " docs/install.md says.", file=sys.stderr)


def install(s: dict) -> None:
    run("nixos-generate-config", "--root", str(MNT))
    (MNT / "etc/nixos/configuration.nix").write_text(
        CONFIGURATION_NIX.format(hostname=s["host"], username=s["user"], state_version=STATE_VERSION)
    )

    print("\nInstalling. nixos-install asks for the root password at the end.")
    run("nixos-install")

    print(f"\nSet the password for {s['user']} (you log in to {s['host']} with it):")
    while not run("nixos-enter", "--root", str(MNT), "-c", f"passwd {s['user']}", check=False):
        pass


def clone_harmonia(s: dict) -> bool:
    dest = MNT / "home" / s["user"] / "harmonia"
    if shutil.which("git"):
        cloned = run("git", "clone", REPO, str(dest), check=False)
    else:
        cloned = run("nix-shell", "-p", "git", "--run", shlex.join(["git", "clone", REPO, str(dest)]), check=False)
    if not cloned:
        print(f"warning: couldn't clone {REPO}; clone it after rebooting (see docs/install.md step 10)",
              file=sys.stderr)
        return False

    shutil.copy(MNT / "etc/nixos/hardware-configuration.nix",
                dest / "hosts" / s["host"] / "hardware-configuration.nix")
    run("nixos-enter", "--root", str(MNT), "-c", f"chown -R {s['user']}:users /home/{s['user']}/harmonia")
    return True


def main() -> None:
    preflight()
    settings = ask_settings()
    confirm(settings)
    partition_and_mount(settings)
    install(settings)
    cloned = clone_harmonia(settings)

    quiet("swapoff", "-a")
    run("umount", "-R", str(MNT))
    if settings["luks"]:
        run("cryptsetup", "close", "cryptroot")

    print(f"\nBase NixOS is installed. Remove the USB stick and reboot, then log in as {settings['user']} and run:")
    if not cloned:
        print(f"  git clone {REPO} ~/harmonia && cp /etc/nixos/hardware-configuration.nix ~/harmonia/hosts/{settings['host']}/")
    print(f"  cd ~/harmonia && sudo nixos-rebuild switch --flake .#{settings['flake']}")


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, EOFError):
        sys.exit("\naborted")
