"""WireGuard tunnels (NetworkManager connections of type wireguard, see
modules/nixos/wireguard.nix) for the bar button and its panel.

Usage: eww-wg              JSON for the bar: {"active": N, "tunnels": [...]}
       eww-wg toggle NAME  bring a NetworkManager WireGuard connection up/down
"""

import json
import math
import re
import subprocess
import sys
import time

# home/eww.nix replaces this with the store path of wg.
WG = "wg"


def output(*args: str) -> str:
    try:
        return subprocess.run(args, capture_output=True, text=True).stdout
    except OSError:
        return ""


def wg_show(what: str) -> dict:
    """wg show all endpoints|latest-handshakes, as {iface: value} (first peer)."""
    values: dict = {}
    for line in output("/run/wrappers/bin/sudo", "-n", WG, "show", "all", what).splitlines():
        fields = line.split()
        if len(fields) >= 3:
            values.setdefault(fields[0], fields[2])
    return values


def iec(n: int) -> str:
    """Bytes the way `numfmt --to=iec-i --suffix=B` prints them: 1023B, 1.5KiB, 15KiB."""
    x, unit = float(n), 0
    while x >= 1024 and unit < 6:
        x, unit = x / 1024, unit + 1
    if unit == 0:
        return f"{n}B"
    prefix = "KMGTPE"[unit - 1]
    if x < 10 and math.ceil(x * 10) / 10 < 10:
        return f"{math.ceil(x * 10) / 10:.1f}{prefix}iB"
    return f"{math.ceil(x)}{prefix}iB"


def terse(line: str) -> list[str]:
    """Split one line of `nmcli -t` output (":" separated, "\\:" escaped)."""
    return [re.sub(r"\\(.)", r"\1", f) for f in re.split(r"(?<!\\):", line)]


def tunnel(name: str, dev: str, endpoints: dict, handshakes: dict) -> dict:
    address = output("nmcli", "-g", "ipv4.addresses", "connection", "show", name).split(",")[0].strip()
    rx = tx = endpoint = handshake = ""
    if dev:
        try:
            stats = json.loads(output("ip", "-j", "-s", "link", "show", "dev", dev))[0]["stats64"]
            rx, tx = iec(stats["rx"]["bytes"]), iec(stats["tx"]["bytes"])
        except (ValueError, IndexError, KeyError):
            pass
        endpoint = endpoints.get(dev, "")
        last = handshakes.get(dev, "")
        if not last.isdigit():
            handshake = "unknown"
        elif int(last) == 0:
            handshake = "never"
        else:
            ago = int(time.time()) - int(last)
            handshake = f"{ago}s ago" if ago < 120 else f"{ago // 60}m ago"
    return {
        "name": name,
        "active": dev != "",
        "device": dev,
        "address": address,
        "endpoint": endpoint,
        "rx": rx,
        "tx": tx,
        "handshake": handshake,
    }


def listing() -> str:
    endpoints, handshakes = wg_show("endpoints"), wg_show("latest-handshakes")
    tunnels = []
    for line in output("nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show").splitlines():
        fields = terse(line)
        if len(fields) == 3 and fields[1] == "wireguard":
            tunnels.append(tunnel(fields[0], fields[2], endpoints, handshakes))
    return json.dumps(
        {"active": sum(t["active"] for t in tunnels), "tunnels": tunnels},
        separators=(",", ":"),
        ensure_ascii=False,
    )


def main(args: list[str]) -> None:
    if args[:1] == ["toggle"] and len(args) > 1:
        name = args[1]
        up = output("nmcli", "-g", "GENERAL.STATE", "connection", "show", "--active", name).strip()
        subprocess.run(["nmcli", "connection", "down" if up else "up", "id", name], stdout=subprocess.DEVNULL)
        subprocess.run(["eww", "update", f"wg={listing()}"])
    else:
        print(listing())


if __name__ == "__main__":
    main(sys.argv[1:])
