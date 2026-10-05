"""VPNs on this host for the bar's network button and its panel: WireGuard,
OpenVPN and Proton VPN connections in NetworkManager (modules/nixos/vpn.nix),
plus any OpenVPN tunnel started outside it (`sudo openvpn --config …`).

Usage: eww-vpn              JSON for the bar, below
       eww-vpn toggle NAME  bring a NetworkManager VPN connection up/down

{"up": {"wireguard": bool, "openvpn": bool, "proton": bool, "other": bool},
 "active": N, "proton_app": bool,
 "connections": [{"name", "kind", "label", "active", "managed", "device",
                  "address", "endpoint", "rx", "tx", "handshake"}]}

Proton VPN's app makes NetworkManager connections named "ProtonVPN …" on
the proton0 (WireGuard) or a tun (OpenVPN) device; those count as Proton,
whichever protocol they use. Its kill switch connections (pvpn-*) are not
tunnels and are left out.
"""

import json
import math
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

# home/eww.nix replaces this with the store path of wg.
WG = "wg"

SYS = Path("/sys/class/net")
IFF_TUN = 0x0001
KINDS = ("wireguard", "openvpn", "proton", "other")
LABELS = {"wireguard": "WireGuard", "openvpn": "OpenVPN", "proton": "Proton VPN", "other": "VPN"}


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


def get(name: str, what: str) -> str:
    """A field of `nmcli connection show NAME`, unescaped (-g writes "\\:")."""
    return re.sub(r"\\(.)", r"\1", output("nmcli", "-g", what, "connection", "show", "id", name).strip())


def field(name: str, what: str) -> str:
    """The same, first value only."""
    return get(name, what).split(" | ")[0].split(",")[0].strip()


def counters(dev: str) -> tuple[str, str]:
    try:
        rx = int((SYS / dev / "statistics/rx_bytes").read_text())
        tx = int((SYS / dev / "statistics/tx_bytes").read_text())
        return iec(rx), iec(tx)
    except (OSError, ValueError):
        return "", ""


def tun_devices() -> list[str]:
    """Layer 3 tun devices (OpenVPN's); taps such as the microVMs' are skipped."""
    devs = []
    for d in sorted(SYS.iterdir()):
        try:
            flags = int((d / "tun_flags").read_text().strip(), 16)
        except (OSError, ValueError):
            continue
        if flags & IFF_TUN:
            devs.append(d.name)
    return devs


def is_proton(name: str, dev: str) -> bool:
    return name.lower().startswith("protonvpn") or dev.startswith("proton")


def connection(name: str, nmtype: str, active: bool, handshakes: dict, endpoints: dict) -> dict | None:
    if name.startswith("pvpn-"):
        return None
    if nmtype == "wireguard":
        kind = "wireguard"
        dev = field(name, "GENERAL.IP-IFACE") if active else ""
        dev = dev or (field(name, "connection.interface-name") if active else "")
    else:
        service = field(name, "vpn.service-type")
        kind = "openvpn" if service.endswith(".openvpn") else "other"
        dev = field(name, "GENERAL.IP-IFACE") if active else ""
    if is_proton(name, dev):
        kind = "proton"

    address = endpoint = handshake = ""
    rx = tx = ""
    if active:
        address = field(name, "IP4.ADDRESS").split("/")[0]
        if dev:
            rx, tx = counters(dev)
        if dev in endpoints:
            endpoint = endpoints[dev]
            last = handshakes.get(dev, "")
            if not last.isdigit():
                handshake = "unknown"
            elif int(last) == 0:
                handshake = "never"
            else:
                ago = int(time.time()) - int(last)
                handshake = f"{ago}s ago" if ago < 120 else f"{ago // 60}m ago"
        elif nmtype == "vpn":
            remote = re.search(r"(?:^|,\s*)remote\s*=\s*([^,]+)", get(name, "vpn.data"))
            endpoint = remote.group(1).strip() if remote else ""
    else:
        address = field(name, "ipv4.addresses").split("/")[0]
    return {
        "name": name,
        "kind": kind,
        "label": LABELS[kind],
        "active": active,
        "managed": True,
        "device": dev,
        "address": address,
        "endpoint": endpoint,
        "rx": rx,
        "tx": tx,
        "handshake": handshake,
    }


def unmanaged(dev: str) -> dict:
    """An OpenVPN tunnel NetworkManager doesn't know about."""
    address = ""
    try:
        info = json.loads(output("ip", "-j", "-4", "addr", "show", "dev", dev))
        address = next((a.get("local", "") for a in info[0].get("addr_info", [])), "")
    except (ValueError, IndexError, AttributeError):
        pass
    rx, tx = counters(dev)
    kind = "proton" if dev.startswith("proton") else "openvpn"
    return {
        "name": dev, "kind": kind, "label": LABELS[kind], "active": True, "managed": False,
        "device": dev, "address": address, "endpoint": "", "rx": rx, "tx": tx, "handshake": "",
    }


def listing() -> str:
    endpoints, handshakes = wg_show("endpoints"), wg_show("latest-handshakes")
    conns = []
    for line in output("nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show").splitlines():
        fields = terse(line)
        if len(fields) == 3 and fields[1] in ("wireguard", "vpn"):
            c = connection(fields[0], fields[1], fields[2] == "yes", handshakes, endpoints)
            if c:
                conns.append(c)
    owned = {c["device"] for c in conns if c["device"]}
    conns += [unmanaged(d) for d in tun_devices() if d not in owned]
    # Up first, then by kind and name, so the panel lists what's on at the top.
    conns.sort(key=lambda c: (not c["active"], KINDS.index(c["kind"]), c["name"].lower()))
    return json.dumps(
        {
            "up": {k: any(c["active"] and c["kind"] == k for c in conns) for k in KINDS},
            "active": sum(c["active"] for c in conns),
            "proton_app": shutil.which("protonvpn-app") is not None,
            "connections": conns,
        },
        separators=(",", ":"),
        ensure_ascii=False,
    )


def toggle(name: str) -> None:
    up = output("nmcli", "-g", "GENERAL.STATE", "connection", "show", "--active", "id", name).strip()
    if up:
        subprocess.run(["nmcli", "connection", "down", "id", name], stdout=subprocess.DEVNULL)
        return
    # There's no NetworkManager secret agent on the desktop, so a connection
    # that wants a password (most OpenVPN ones) fails here; ask for it in a
    # terminal instead.
    done = subprocess.run(["nmcli", "connection", "up", "id", name], capture_output=True)
    if done.returncode != 0:
        subprocess.Popen(
            ["alacritty", "--class", "vpn-connect", "-e", "nmcli", "--ask", "connection", "up", "id", name],
            start_new_session=True,
        )


def main(args: list[str]) -> None:
    if args[:1] == ["toggle"] and len(args) > 1:
        toggle(args[1])
        subprocess.run(["eww", "update", f"vpn={listing()}"])
    else:
        print(listing())


if __name__ == "__main__":
    main(sys.argv[1:])
