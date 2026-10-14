"""System health and NixOS for the dash's system tile (home/eww/eww.yuck):
failed systemd units (the system's and yours), errors in the journal over
the last hour, the running NixOS generation and whether a reboot is needed
to use it all, how old the flake's pins are (from flake.lock at build time,
home/eww.nix), and the Nix store's disk and garbage collection.

Then who can reach this machine: every listening port, whether the NixOS
firewall lets it through (the allowed ports come from the config, by
home/eww.nix), who is logged in and from where, and failed sudo and SSH
logins over the last day. Without root, ss names only your own programs.

Usage: eww-system               JSON for the tile
       eww-system restart UNIT  restart one of your own (user) units
       eww-system gc            collect the store's garbage in the background
"""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

from common import RUN_DIR, config, output, read
from procs import size

GC = RUN_DIR / "eww-system-gc.json"
OLD_DAYS = 60  # a pin older than this is flagged


def ago(seconds: float) -> str:
    for unit, length in (("d", 86400), ("h", 3600), ("min", 60)):
        if seconds >= length:
            return f"{int(seconds // length)} {unit}"
    return "now"


def failed() -> list:
    units = []
    for scope in ("system", "user"):
        flag = ["--user"] if scope == "user" else []
        out = output("systemctl", *flag, "--failed", "--plain", "--no-legend", "--no-pager")
        units += [{"unit": line.split()[0], "scope": scope} for line in out.splitlines() if line.split()]
    return units


def errors() -> tuple:
    """How many error (or worse) messages the journal has from the last
    hour, and the latest few."""
    out = output("journalctl", "-p", "err", "--since", "-1h", "--no-pager", "-o", "json", "-n", "500")
    entries = []
    for line in out.splitlines():
        try:
            e = json.loads(line)
        except ValueError:
            continue
        message = e.get("MESSAGE")
        if isinstance(message, list):  # not valid UTF-8: bytes
            message = bytes(message).decode(errors="replace")
        when = int(e.get("__REALTIME_TIMESTAMP", "0")) / 1e6
        entries.append(
            {
                "time": time.strftime("%H:%M", time.localtime(when)),
                "who": e.get("SYSLOG_IDENTIFIER") or e.get("_COMM") or "",
                "message": " ".join(str(message or "").split()),
            }
        )
    return len(entries), entries[-6:][::-1]


def generation() -> dict:
    link = Path("/nix/var/nix/profiles/system")
    name = os.readlink(link) if link.is_symlink() else ""
    try:
        built = ago(time.time() - (link.parent / name).lstat().st_mtime) if name else ""
    except OSError:
        built = ""
    # A new kernel, initrd or kernel modules only take effect after a reboot.
    reboot = any(
        os.path.realpath(f"/run/booted-system/{p}") != os.path.realpath(f"/run/current-system/{p}")
        for p in ("kernel", "initrd", "kernel-modules")
    )
    return {
        "number": name.removeprefix("system-").removesuffix("-link"),
        "built": built,
        "version": read(Path("/run/current-system/nixos-version")),
        "kernel": os.uname().release,
        "reboot": reboot,
    }


def pins() -> list:
    now = time.time()
    rows = []
    for p in sorted(config().get("pins", []), key=lambda p: p["modified"]):
        age = now - p["modified"]
        rows.append({"name": p["name"], "age": ago(age), "old": age > OLD_DAYS * 86400})
    return rows


def allowed(proto: str, port: int) -> list:
    """Where the firewall lets port through: "everywhere", or the interfaces
    that open it (networking.firewall, given by home/eww.nix)."""
    fw = config().get("firewall", {})
    where = []
    for scope, rules in [("everywhere", fw.get("all", {}))] + sorted(fw.get("interfaces", {}).items()):
        ports = rules.get(proto, [])
        ranges = rules.get(f"{proto}Ranges", [])
        if port in ports or any(r["from"] <= port <= r["to"] for r in ranges):
            where.append(scope)
    # A trusted interface (a microVM's tap, say) lets every port through;
    # NixOS always trusts lo, which only this machine reaches anyway.
    return where + [i for i in fw.get("trusted", []) if i not in where and i != "lo"]


def listening() -> list:
    """One row per protocol and port, the IPv4 and IPv6 sockets together."""
    rows: dict = {}
    for line in output("ss", "-tulnpH").splitlines():
        f = line.split()
        if len(f) < 5:
            continue
        proto, local = f[0], f[4]
        addr, _, port = local.rpartition(":")
        addr = addr.strip("[]").split("%")[0]
        if not port.isdigit():
            continue
        local_only = addr.startswith("127.") or addr == "::1"
        program = re.search(r'users:\(\("([^"]+)"', line)
        key = (proto, int(port))
        row = rows.setdefault(key, {"proto": proto, "port": int(port), "program": "", "local": True, "addresses": []})
        row["local"] = row["local"] and local_only
        row["program"] = row["program"] or (program.group(1) if program else "")
        if addr not in row["addresses"]:
            row["addresses"].append(addr)
    fw = config().get("firewall", {})
    out = []
    for (proto, port), row in sorted(rows.items(), key=lambda item: (item[1]["local"], item[0][1])):
        where = allowed(proto, port)
        if row["local"]:
            reach = "this machine only"
        elif not fw.get("enable", True):
            reach = "open (no firewall)"
        elif where:
            reach = "open " + ("to everyone" if "everywhere" in where else "on " + ", ".join(where))
        else:
            reach = "blocked by the firewall"
        out.append({**row, "reach": reach, "exposed": reach.startswith("open"), "addresses": ", ".join(row["addresses"])})
    return out


def logins() -> list:
    """Each login session (not systemd's own user manager): who, where, how."""
    found = []
    for line in output("loginctl", "list-sessions", "--no-legend").splitlines():
        f = line.split()
        if len(f) < 6 or f[5] != "user":
            continue
        props = dict(
            p.split("=", 1) for p in output("loginctl", "show-session", f[0], "-p", "Remote", "-p", "RemoteHost", "-p", "Service", "-p", "TTY", "-p", "Type").splitlines() if "=" in p
        )
        remote = props.get("Remote") == "yes"
        found.append(
            {
                "user": f[2],
                "where": f"from {props.get('RemoteHost') or 'remote'}" if remote else (props.get("TTY") or f[3]),
                "how": props.get("Service", ""),
                "remote": remote,
            }
        )
    return found


def failed_logins() -> tuple:
    """Failed sudo and SSH logins over the last day: how many, and the latest."""
    out = output("journalctl", "--since", "-24h", "--no-pager", "-o", "json", "-t", "sudo", "-t", "sshd", "-t", "sshd-session")
    hits = []
    for line in out.splitlines():
        try:
            e = json.loads(line)
        except ValueError:
            continue
        message = str(e.get("MESSAGE") or "")
        if re.search(r"incorrect password|authentication failure|Failed password|Invalid user|Failed publickey", message):
            when = int(e.get("__REALTIME_TIMESTAMP", "0")) / 1e6
            hits.append({"time": time.strftime("%a %H:%M", time.localtime(when)), "who": e.get("SYSLOG_IDENTIFIER", ""), "message": " ".join(message.split())})
    return len(hits), hits[-4:][::-1]


def store() -> dict:
    st = os.statvfs("/nix/store")
    total, free = st.f_blocks * st.f_frsize, st.f_bavail * st.f_frsize
    try:
        gc = json.loads(GC.read_text())
    except (OSError, ValueError):
        gc = {}
    if gc.get("running"):
        status = "collecting garbage…"
    elif gc.get("done"):
        status = f"{gc.get('result', 'collected')} {ago(time.time() - gc['done'])} ago"
    else:
        status = ""
    return {"free": size(free), "pct": round((total - free) / total * 100) if total else 0, "gc": status, "running": bool(gc.get("running"))}


def collect() -> None:
    """nix-store --gc through the daemon: it only deletes what no profile or
    running program uses (old generations stay until removed as root)."""
    GC.write_text(json.dumps({"running": True}))
    out = subprocess.run(["nix-store", "--gc"], capture_output=True, text=True)
    # Its last line: "1234 store paths deleted, 5678.90 MiB freed".
    last = (out.stdout + out.stderr).strip().splitlines()[-1:] or ["done"]
    GC.write_text(json.dumps({"done": time.time(), "result": last[0].replace("store paths deleted", "paths deleted")}))
    output("eww", "update", f"system={state()}")


def state() -> str:
    count, recent = errors()
    bad, bad_recent = failed_logins()
    ports = listening()
    return json.dumps(
        {
            "ports": ports,
            "exposed": sum(p["exposed"] for p in ports),
            "logins": logins(),
            "failed_logins": bad,
            "failed_recent": bad_recent,
            "failed": failed(),
            "errors": count,
            "recent": recent,
            "generation": generation(),
            "pins": pins(),
            "store": store(),
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )


def main(args: list[str]) -> None:
    command, rest = (args[0], args[1:]) if args else ("", [])
    if command == "restart" and rest:
        output("systemctl", "--user", "restart", rest[0])
    elif command == "gc":
        subprocess.Popen(["eww-system", "gc-run"], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.2)
    elif command == "gc-run":
        collect()
        return
    else:
        print(state())
        return
    output("eww", "update", f"system={state()}")


if __name__ == "__main__":
    main(sys.argv[1:])
