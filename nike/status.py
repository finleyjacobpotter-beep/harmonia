"""Nike's VPN and utilization, written as JSON every 2 seconds to the status
share, where the host's bar reads it (home/eww/nike.py).

{"time": epoch seconds,
 "cpu": pct, "cpu_text", "mem": pct, "mem_text", "disk": pct, "disk_text",
 "load": "0.10 0.05 0.01", "uptime_text": "3h 12m",
 "vpn": {"up": bool, "dev": "tun0", "address": "10.8.0.2",
         "remote": "203.0.113.5:1194", "outbound": "tun0", "via_vpn": bool,
         "summary": "...", "rx_text", "tx_text"}}

The VPN is any tun/tap device (OpenVPN's tun0). "outbound" is the
interface the route to the internet leaves through right now, so via_vpn is
false both with no tunnel and with a tunnel that doesn't carry the default
route (no redirect-gateway).
"""

import json
import os
import subprocess
import sys
import time

INTERVAL = 2
PROBE = "1.1.1.1"  # any internet address: only the route to it is looked up


def cmd_json(*args: str) -> list:
    try:
        result = subprocess.run(args, capture_output=True, text=True)
        return json.loads(result.stdout or "[]")
    except (OSError, ValueError):
        return []


def cpu_times() -> tuple[int, int]:
    """(busy, total) jiffies over all CPUs."""
    with open("/proc/stat") as f:
        fields = [int(x) for x in f.readline().split()[1:]]
    idle = fields[3] + fields[4]  # idle + iowait
    return sum(fields) - idle, sum(fields)


def meminfo() -> dict[str, int]:
    info = {}
    with open("/proc/meminfo") as f:
        for line in f:
            key, _, value = line.partition(":")
            info[key] = int(value.split()[0]) * 1024
    return info


def size(n: float) -> str:
    for unit in ["B", "KiB", "MiB", "GiB", "TiB"]:
        if n < 1024 or unit == "TiB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return ""


def rate(bytes_per_second: float) -> str:
    """Bits per second, like the host's network module."""
    v, units = bytes_per_second * 8, ["bps", "kbps", "Mbps", "Gbps"]
    i = 0
    while v >= 999.95 and i < len(units) - 1:
        v, i = v / 1000, i + 1
    return f"{min(v, 999.9):.1f} {units[i]}"


def duration(seconds: float) -> str:
    m = int(seconds) // 60
    d, h, m = m // 1440, m // 60 % 24, m % 60
    return f"{d}d {h}h" if d else f"{h}h {m}m" if h else f"{m}m"


def tunnels() -> list[str]:
    """tun/tap devices (they have tun_flags), the VPN's interfaces."""
    try:
        names = sorted(os.listdir("/sys/class/net"))
    except OSError:
        return []
    return [n for n in names if os.path.exists(f"/sys/class/net/{n}/tun_flags")]


def counters(dev: str) -> tuple[int, int]:
    def read(what: str) -> int:
        try:
            with open(f"/sys/class/net/{dev}/statistics/{what}_bytes") as f:
                return int(f.read())
        except (OSError, ValueError):
            return 0

    return read("rx"), read("tx")


def outbound() -> str:
    routes = cmd_json("ip", "-j", "route", "get", PROBE)
    return routes[0].get("dev", "") if routes else ""


def address(dev: str) -> str:
    for link in cmd_json("ip", "-j", "-4", "addr", "show", "dev", dev):
        for a in link.get("addr_info", []):
            return a.get("local", "")
    return ""


def remote(tun_devs: list[str]) -> str:
    """The VPN server: OpenVPN's connected socket if it has one, else the
    host route OpenVPN adds to the server outside the tunnel."""
    try:
        out = subprocess.run(["ss", "-Htunp"], capture_output=True, text=True).stdout
    except OSError:
        out = ""
    for line in out.splitlines():
        if '"openvpn"' in line:
            cols = line.split()
            if len(cols) >= 6 and not cols[5].endswith(":*"):
                return cols[5]
    for r in cmd_json("ip", "-j", "-4", "route", "show"):
        dst = r.get("dst", "")
        if dst not in ("", "default") and "/" not in dst and r.get("gateway") and r.get("dev") not in tun_devs:
            return dst
    return ""


def main() -> None:
    path = sys.argv[1]
    prev_cpu = cpu_times()
    prev_net: dict[str, tuple[int, int]] = {}
    prev_time = time.monotonic()
    time.sleep(INTERVAL)

    while True:
        now = time.monotonic()
        elapsed = max(now - prev_time, 0.001)

        busy, total = cpu_times()
        cpu = 100 * (busy - prev_cpu[0]) / max(total - prev_cpu[1], 1)
        prev_cpu = (busy, total)

        mem = meminfo()
        mem_total = mem.get("MemTotal", 0)
        mem_used = mem_total - mem.get("MemAvailable", 0)

        st = os.statvfs("/home")
        disk_total = st.f_blocks * st.f_frsize
        disk_used = disk_total - st.f_bavail * st.f_frsize

        with open("/proc/loadavg") as f:
            load = " ".join(f.read().split()[:3])
        with open("/proc/uptime") as f:
            uptime = float(f.read().split()[0])

        tun_devs = tunnels()
        out = outbound()
        via_vpn = out in tun_devs
        dev = out if via_vpn else (tun_devs[0] if tun_devs else "")
        vpn = {"up": bool(dev), "dev": dev, "address": "", "remote": "",
               "outbound": out or "none", "via_vpn": via_vpn, "summary": "",
               "rx_text": "", "tx_text": ""}
        if dev:
            vpn["address"] = address(dev)
            vpn["remote"] = remote(tun_devs)
            rx, tx = counters(dev)
            old = prev_net.get(dev)
            if old:
                vpn["rx_text"] = rate(max(rx - old[0], 0) / elapsed)
                vpn["tx_text"] = rate(max(tx - old[1], 0) / elapsed)
            else:
                vpn["rx_text"] = vpn["tx_text"] = "…"
            prev_net = {dev: (rx, tx)}
            where = f"{dev} {vpn['address']}".strip()
            if vpn["remote"]:
                where += f" → {vpn['remote']}"
            vpn["summary"] = where if via_vpn else f"{where} is up, but traffic leaves through {out or 'nothing'}"
        else:
            prev_net = {}
            vpn["summary"] = f"No VPN: traffic leaves through {out}" if out else "No route to the internet"

        status = {
            "time": time.time(),
            "cpu": round(cpu),
            "cpu_text": f"{cpu:.0f}% of {os.cpu_count()} vCPUs",
            "mem": round(100 * mem_used / max(mem_total, 1)),
            "mem_text": f"{size(mem_used)} / {size(mem_total)}",
            "disk": round(100 * disk_used / max(disk_total, 1)),
            "disk_text": f"{size(disk_used)} / {size(disk_total)}",
            "load": load,
            "uptime_text": duration(uptime),
            "vpn": vpn,
        }
        tmp = path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(status, f, separators=(",", ":"), ensure_ascii=False)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)

        prev_time = now
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
