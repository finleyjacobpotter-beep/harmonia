"""Per-VM utilization for the bar's VM panel, from `virsh domstats` on
qemu:///system: CPU, memory, disk and network for every running libvirt
domain, and the state of the stopped ones.

CPU and the rates are the change since the previous call, which is kept in
$XDG_RUNTIME_DIR/eww-vms.json; the first call samples twice.

{"running": n, "vms": [{"name", "state", "running": bool,
  "cpu": pct, "cpu_text", "vcpus",
  "mem": pct, "mem_text", "mem_source": "guest" | "host",
  "disk_text", "net_text"}]}
"""

import json
import os
import subprocess
import time

STATE_FILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "eww-vms.json")
STALE = 10  # seconds: an older previous sample is resampled instead

STATES = {
    "0": "no state",
    "1": "running",
    "2": "blocked",
    "3": "paused",
    "4": "shutting down",
    "5": "off",
    "6": "crashed",
    "7": "suspended",
}


def domstats() -> dict[str, dict[str, str]]:
    """{domain: {stat: value}} for every defined domain."""
    try:
        result = subprocess.run(
            ["virsh", "-c", "qemu:///system", "domstats", "--state", "--cpu-total",
             "--balloon", "--vcpu", "--block", "--interface"],
            capture_output=True,
            text=True,
        )
    except OSError:
        return {}
    domains: dict[str, dict[str, str]] = {}
    stats: dict[str, str] = {}
    for line in result.stdout.splitlines():
        line = line.strip()
        if line.startswith("Domain: "):
            stats = domains.setdefault(line[len("Domain: "):].strip("'"), {})
        elif "=" in line:
            key, _, value = line.partition("=")
            stats[key] = value
    return domains


def num(stats: dict[str, str], key: str) -> int:
    try:
        return int(stats.get(key, ""))
    except ValueError:
        return 0


def total(stats: dict[str, str], kind: str, field: str) -> int:
    """Sum of block.N.<field> or net.N.<field> over every disk or interface."""
    return sum(num(stats, f"{kind}.{i}.{field}") for i in range(num(stats, f"{kind}.count")))


def sample() -> dict:
    counters = {}
    for name, stats in domstats().items():
        counters[name] = {
            "state": stats.get("state.state", "0"),
            "cpu": num(stats, "cpu.time"),  # ns
            "vcpus": num(stats, "vcpu.current"),
            "rd": total(stats, "block", "rd.bytes"),
            "wr": total(stats, "block", "wr.bytes"),
            "rx": total(stats, "net", "rx.bytes"),
            "tx": total(stats, "net", "tx.bytes"),
            # KiB. available/unused come from the guest's balloon driver.
            "mem_current": num(stats, "balloon.current"),
            "mem_available": num(stats, "balloon.available"),
            "mem_unused": num(stats, "balloon.unused"),
            "mem_rss": num(stats, "balloon.rss"),
        }
    return {"time": time.time(), "domains": counters}


def load_previous() -> dict | None:
    try:
        with open(STATE_FILE) as f:
            previous = json.load(f)
    except (OSError, ValueError):
        return None
    if not isinstance(previous, dict) or time.time() - previous.get("time", 0) > STALE:
        return None
    return previous


def save(current: dict) -> None:
    try:
        tmp = STATE_FILE + ".tmp"
        with open(tmp, "w") as f:
            json.dump(current, f)
        os.replace(tmp, STATE_FILE)
    except OSError:
        pass


def size(n: float) -> str:
    """Bytes as "512 B", "1.5 KiB", "3.2 GiB"."""
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unit == "GiB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return ""


def rate(now: dict, before: dict | None, key: str, seconds: float) -> str:
    if before is None or seconds <= 0:
        return "…"
    return size(max(0, now[key] - before[key]) / seconds) + "/s"


def describe(name: str, now: dict, before: dict | None, seconds: float) -> dict:
    running = now["state"] == "1"
    vm = {
        "name": name,
        "state": STATES.get(now["state"], "unknown"),
        "running": running,
        "cpu": 0,
        "cpu_text": "",
        "vcpus": now["vcpus"],
        "mem": 0,
        "mem_text": "",
        "mem_source": "",
        "disk_text": "",
        "net_text": "",
    }
    if not running and now["state"] != "3":
        return vm
    if before is not None and seconds > 0 and now["vcpus"] > 0:
        # Share of all its vCPUs, so 100% means every vCPU is busy.
        cpu = (now["cpu"] - before["cpu"]) / (seconds * 1e9 * now["vcpus"]) * 100
        cpu = round(min(100.0, max(0.0, cpu)))
        cpu_text = f"{cpu}% of {now['vcpus']} vCPU"
    else:
        cpu, cpu_text = 0, f"… of {now['vcpus']} vCPU"
    if now["mem_available"] > 0:
        used, of, source = now["mem_available"] - now["mem_unused"], now["mem_available"], "guest"
    else:
        used, of, source = now["mem_rss"], now["mem_current"], "host"
    mem = round(min(100.0, used / of * 100)) if of > 0 else 0
    vm.update(
        cpu=cpu,
        cpu_text=cpu_text,
        mem=mem,
        mem_text=f"{size(used * 1024)} of {size(of * 1024)}",
        mem_source=source,
        disk_text=f"read {rate(now, before, 'rd', seconds)}  write {rate(now, before, 'wr', seconds)}",
        net_text=f"↓ {rate(now, before, 'rx', seconds)}  ↑ {rate(now, before, 'tx', seconds)}",
    )
    return vm


def main() -> None:
    previous = load_previous()
    if previous is None:
        previous = sample()
        time.sleep(0.5)
    current = sample()
    save(current)
    seconds = current["time"] - previous["time"]
    vms = [
        describe(name, now, previous["domains"].get(name), seconds)
        for name, now in sorted(current["domains"].items())
    ]
    # Running ones first, then by name.
    vms.sort(key=lambda vm: (not vm["running"], vm["name"]))
    print(
        json.dumps(
            {"running": sum(vm["running"] for vm in vms), "vms": vms},
            separators=(",", ":"),
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
