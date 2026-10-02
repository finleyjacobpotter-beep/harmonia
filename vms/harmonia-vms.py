"""The harmonia libvirt VMs (modules/nixos/vms.nix). One script, packaged as
three commands (COMMAND below):

  harmonia-vms                     (re)define the network filters, disks and
                                   domains, and refresh the Kali share; run by
                                   the harmonia-vms service on boot
  harmonia-vm-fetch [VM...]        download and check the installer ISOs
                                   (default: all VMs); run with sudo
  harmonia-vm-firewall [VM POLICY] show each VM's network policy, or switch a
                                   running VM to another one at once

Everything specific to this build (VM names, ISOs, the libvirt XML in
/nix/store) comes from the JSON file CONFIG_FILE names.
"""

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

# modules/nixos/vms.nix replaces these with the command name and the store
# path of the config.
COMMAND = "harmonia-vms"
CONFIG_FILE = "harmonia-vms.json"

os.environ["LIBVIRT_DEFAULT_URI"] = "qemu:///system"


def die(message: str) -> None:
    print(message, file=sys.stderr)
    sys.exit(1)


def virsh(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    result = subprocess.run(["virsh", *args], capture_output=True, text=True)
    if check and result.returncode != 0:
        die(f"{COMMAND}: virsh {' '.join(args)}: {result.stderr.strip()}")
    return result


def define_with_uuid(define: str, xml: str, anchor: str, uuid: str) -> None:
    """Our XML has no <uuid>, so libvirt makes up a new one on every define
    and then refuses it for an existing name ("already exists with uuid ...").
    Put the existing object's uuid in after anchor, so redefining updates it
    in place."""
    text = Path(xml).read_text()
    if uuid:
        text = re.sub(anchor, lambda m: m.group(0) + uuid, text, count=1)
    with tempfile.NamedTemporaryFile("w", suffix=".xml") as tmp:
        tmp.write(text)
        tmp.flush()
        virsh(define, tmp.name)


def define_filter(name: str, xml: str) -> None:
    current = virsh("nwfilter-dumpxml", name, check=False)
    match = re.search(r"<uuid>[^<]*</uuid>", current.stdout) if current.returncode == 0 else None
    define_with_uuid("nwfilter-define", xml, r"<filter [^>]*>", match.group(0) if match else "")


def define_domain(name: str, xml: str) -> None:
    current = virsh("domuuid", name, check=False)
    uuid = current.stdout.strip() if current.returncode == 0 else ""
    define_with_uuid("define", xml, r"<name>[^<]*</name>", f"<uuid>{uuid}</uuid>" if uuid else "")


def copy_bundle(bundle: str, share: str, owner: str) -> None:
    """Put the guest's install bundle into its read-write share, owned by you."""
    dest = Path(share, "harmonia")
    Path(share).mkdir(parents=True, exist_ok=True)
    shutil.rmtree(dest, ignore_errors=True)
    shutil.copytree(bundle, dest)
    for root, dirs, files in os.walk(dest):
        for path in [root] + [os.path.join(root, f) for f in files]:
            os.chmod(path, os.stat(path).st_mode | 0o200)
            shutil.chown(path, owner, "users")


def define_all(config: dict) -> None:
    """(Re)define the domains and create any missing disks. Redefining a
    domain updates it in place; a running VM picks it up on next boot."""
    images = Path(config["imageDir"])
    images.mkdir(parents=True, exist_ok=True)
    if virsh("net-info", "default", check=False).returncode == 0:
        virsh("net-autostart", "default")
        virsh("net-start", "default", check=False)
    for policy in config["policies"]:
        define_filter(f"harmonia-{policy['name']}", policy["xml"])
    for name, vm in config["vms"].items():
        define_filter(f"harmonia-vm-{name}", vm["filters"][vm["policy"]])
        disk = images / f"harmonia-{name}.qcow2"
        if not disk.exists():
            subprocess.run(["qemu-img", "create", "-f", "qcow2", str(disk), vm["disk"]], check=True)
        define_domain(f"harmonia-{name}", vm["domain"])
        if vm["bundle"]:
            copy_bundle(vm["bundle"], vm["share"], config["username"])


def get(url: str) -> urllib.request.addinfourl:
    try:
        return urllib.request.urlopen(url)
    except OSError as e:
        die(f"{COMMAND}: {url}: {getattr(e, 'reason', e)}")
        raise


def download(url: str, dest: Path) -> str:
    """Download url to dest with a progress line, and return its sha256."""
    digest = hashlib.sha256()
    with get(url) as response, dest.open("wb") as out:
        total = int(response.headers.get("Content-Length") or 0)
        done = 0
        while chunk := response.read(1 << 20):
            out.write(chunk)
            digest.update(chunk)
            done += len(chunk)
            if total:
                print(f"\r  {done * 100 // total:3d}%  {done >> 20} / {total >> 20} MiB", end="", file=sys.stderr)
    if total:
        print(file=sys.stderr)
    return digest.hexdigest()


def fetch(config: dict, names: list[str]) -> None:
    for vm in names or list(config["vms"]):
        if vm not in config["vms"]:
            die(f"unknown VM: {vm} (expected: {' '.join(config['vms'])})")
        iso = config["vms"][vm]["iso"]
        dest = Path(config["imageDir"], iso["name"])
        if dest.exists():
            print(f"{iso['name']}: already downloaded")
            continue
        expected = iso["sha256"]
        if not expected:
            with get(iso["sums"]) as response:
                sums = response.read().decode()
            listed = [f[0] for f in map(str.split, sums.splitlines()) if len(f) >= 2 and f[1] in (iso["name"], "*" + iso["name"])]
            expected = "\n".join(listed)
            print(f"{iso['name']}: no pinned checksum, using {iso['sums']}: {expected}", flush=True)
        dest.parent.mkdir(parents=True, exist_ok=True)
        partial = dest.with_name(dest.name + ".part")
        actual = download(iso["url"], partial)
        # Reported like `sha256sum -c`; a bad download is left as .part.
        if actual != expected:
            print(f"{partial}: FAILED")
            die("sha256sum: WARNING: 1 computed checksum did NOT match")
        print(f"{partial}: OK")
        partial.rename(dest)


def firewall(config: dict, args: list[str]) -> None:
    """Takes effect on a running VM at once. The policy in modules/nixos/vms.nix
    comes back on the next boot or rebuild."""
    policies = [p["name"] for p in config["policies"]]
    if len(args) == 2:
        vm, policy = args
        if vm not in config["vms"] or policy not in policies:
            die(f"unknown VM or policy (VMs: {' '.join(config['vms'])}; policies: {' '.join(policies)})")
        define_filter(f"harmonia-vm-{vm}", config["vms"][vm]["filters"][policy])
    elif args:
        die("usage: harmonia-vm-firewall [VM POLICY]")
    for vm in config["vms"]:
        xml = virsh("nwfilter-dumpxml", f"harmonia-vm-{vm}", check=False).stdout
        match = re.search(r"filter=[\"']harmonia-([a-z-]+)[\"']", xml)
        print(f"{vm}: {match.group(1) if match else 'not defined'}")


def main(args: list[str]) -> None:
    config = json.loads(Path(CONFIG_FILE).read_text())
    if COMMAND == "harmonia-vm-fetch":
        fetch(config, args)
    elif COMMAND == "harmonia-vm-firewall":
        firewall(config, args)
    else:
        define_all(config)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except KeyboardInterrupt:
        sys.exit(130)
