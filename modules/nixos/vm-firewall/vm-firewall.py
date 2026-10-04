"""Switch a microVM's firewall mode (modules/nixos/vm-firewall.nix).

Usage: vm-firewall                 {"nike": "permissive", ...} as JSON
       vm-firewall set VM MODE     load /etc/vm-firewall/VM/MODE.nft (root)
       vm-firewall apply           load every VM's saved (or default) mode
"""

import json
import os
import subprocess
import sys

ETC = "/etc/vm-firewall"
STATE = "/var/lib/vm-firewall"


def config() -> dict:
    with open(f"{ETC}/config.json") as f:
        return json.load(f)


def current(cfg: dict) -> dict[str, str]:
    modes = {}
    for vm, v in cfg.items():
        names = [m["name"] for m in v["modes"]]
        try:
            with open(f"{STATE}/{vm}") as f:
                mode = f.read().strip()
        except OSError:
            mode = ""
        modes[vm] = mode if mode in names else v["default"]
    return modes


def load(vm: str, mode: str) -> None:
    subprocess.run(["nft", "-f", f"{ETC}/{vm}/{mode}.nft"], check=True)


def main() -> None:
    cfg = config()
    args = sys.argv[1:]
    if not args:
        print(json.dumps(current(cfg)))
    elif args[0] == "apply" and len(args) == 1:
        for vm, mode in current(cfg).items():
            load(vm, mode)
    elif args[0] == "set" and len(args) == 3:
        vm, mode = args[1], args[2]
        if vm not in cfg or mode not in [m["name"] for m in cfg[vm]["modes"]]:
            sys.exit(f"vm-firewall: no mode {mode!r} for {vm!r}")
        load(vm, mode)
        os.makedirs(STATE, exist_ok=True)
        tmp = f"{STATE}/{vm}.tmp"
        with open(tmp, "w") as f:
            f.write(mode + "\n")
        os.chmod(tmp, 0o644)
        os.replace(tmp, f"{STATE}/{vm}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
