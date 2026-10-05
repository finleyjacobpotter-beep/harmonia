"""VPNs on this host for the bar's network button and its panel (see
modules/nixos/vpn.nix): WireGuard and OpenVPN connections in NetworkManager,
openfortivpn configs in /etc/openfortivpn (run as openfortivpn@NAME), and
any OpenVPN or openfortivpn tunnel started by hand (`sudo openvpn …`).

Usage: eww-vpn                   JSON for the bar, below
       eww-vpn toggle KIND NAME  bring a connection up/down

{"up": {"wireguard": bool, "openvpn": bool, "forti": bool, "other": bool},
 "active": N,
 "connections": [{"name", "kind", "label", "active", "managed", "device",
                  "address", "endpoint", "rx", "tx", "handshake"}]}
"""

import json
import math
import re
import subprocess
import sys
import time
from pathlib import Path

# home/eww.nix replaces this with the store path of wg.
WG = "wg"

SYS = Path("/sys/class/net")
FORTI = Path("/etc/openfortivpn")
IFF_TUN = 0x0001
KINDS = ("wireguard", "openvpn", "forti", "other")
LABELS = {"wireguard": "WireGuard", "openvpn": "OpenVPN", "forti": "openfortivpn", "other": "VPN"}


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


def ppp_devices() -> list[str]:
    """Point-to-point devices: openfortivpn's (through pppd)."""
    return [d.name for d in sorted(SYS.iterdir()) if d.name.startswith("ppp")]


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


def connection(name: str, nmtype: str, active: bool, handshakes: dict, endpoints: dict) -> dict:
    if nmtype == "wireguard":
        kind = "wireguard"
        dev = field(name, "GENERAL.IP-IFACE") if active else ""
        dev = dev or (field(name, "connection.interface-name") if active else "")
    else:
        service = field(name, "vpn.service-type")
        kind = "openvpn" if service.endswith(".openvpn") else "other"
        dev = field(name, "GENERAL.IP-IFACE") if active else ""

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


def ipv4(dev: str) -> str:
    try:
        info = json.loads(output("ip", "-j", "-4", "addr", "show", "dev", dev))
        return next((a.get("local", "") for a in info[0].get("addr_info", [])), "")
    except (ValueError, IndexError, AttributeError):
        return ""


def forti(name: str, active: bool, dev: str) -> dict:
    """An openfortivpn config, /etc/openfortivpn/NAME.conf, and its
    openfortivpn@NAME service. The server is shown if the config is readable
    (it is root's when it holds a password)."""
    endpoint = ""
    try:
        conf = dict(
            (k.strip(), v.strip())
            for k, _, v in (line.partition("=") for line in (FORTI / f"{name}.conf").read_text().splitlines())
            if not k.strip().startswith("#")
        )
        endpoint = conf.get("host", "") + (f":{conf['port']}" if conf.get("port") else "")
    except OSError:
        pass
    rx, tx = counters(dev) if dev else ("", "")
    return {
        "name": name, "kind": "forti", "label": LABELS["forti"], "active": active, "managed": True,
        "device": dev, "address": ipv4(dev) if dev else "", "endpoint": endpoint if active else "",
        "rx": rx, "tx": tx, "handshake": "",
    }


def unmanaged(dev: str) -> dict:
    """A tunnel started by hand: OpenVPN's tun, or openfortivpn's ppp."""
    rx, tx = counters(dev)
    kind = "forti" if dev.startswith("ppp") else "openvpn"
    return {
        "name": dev, "kind": kind, "label": LABELS[kind], "active": True, "managed": False,
        "device": dev, "address": ipv4(dev), "endpoint": "", "rx": rx, "tx": tx, "handshake": "",
    }


def listing() -> str:
    endpoints, handshakes = wg_show("endpoints"), wg_show("latest-handshakes")
    conns = []
    for line in output("nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show").splitlines():
        fields = terse(line)
        if len(fields) == 3 and fields[1] in ("wireguard", "vpn"):
            conns.append(connection(fields[0], fields[1], fields[2] == "yes", handshakes, endpoints))
    # openfortivpn@NAME services get the ppp devices in order; there's
    # rarely more than one.
    names = sorted(p.stem for p in FORTI.glob("*.conf")) if FORTI.is_dir() else []
    states = output("systemctl", "is-active", *[f"openfortivpn@{n}" for n in names]).split() if names else []
    ppp = ppp_devices()
    for name, state in zip(names, states):
        active = state == "active"
        conns.append(forti(name, active, ppp.pop(0) if active and ppp else ""))
    owned = {c["device"] for c in conns if c["device"]}
    conns += [unmanaged(d) for d in tun_devices() + ppp if d not in owned]
    # Up first, then by kind and name, so the panel lists what's on at the top.
    conns.sort(key=lambda c: (not c["active"], KINDS.index(c["kind"]), c["name"].lower()))
    return json.dumps(
        {
            "up": {k: any(c["active"] and c["kind"] == k for c in conns) for k in KINDS},
            "active": sum(c["active"] for c in conns),
            "connections": conns,
        },
        separators=(",", ":"),
        ensure_ascii=False,
    )


def toggle(kind: str, name: str) -> None:
    if kind == "forti":
        # Allowed without a password for wheel (polkit, modules/nixos/vpn.nix).
        unit = f"openfortivpn@{name}"
        up = output("systemctl", "is-active", unit).strip() == "active"
        subprocess.run(["systemctl", "stop" if up else "start", "--no-block", unit], stdout=subprocess.DEVNULL)
        return
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
    if args[:1] == ["toggle"] and len(args) > 2:
        toggle(args[1], args[2])
        subprocess.run(["eww", "update", f"vpn={listing()}"])
    else:
        print(listing())


if __name__ == "__main__":
    main(sys.argv[1:])
