"""Running podman containers, for the dash's containers tile: your
own (rootless) and the system's (root, from virtualisation.oci-containers),
the latter through the read-only sudo rule in modules/nixos/podman.nix.

Usage: eww-pods   {"count": N, "text": "03", "stopped": N, "containers": [...]}

Each container: its name, pod, image and IDs, state, ports, mounts, and
CPU, memory, network and disk I/O from `podman stats`.
"""

import json

from common import config, output

# The exact podman the sudo rule allows (home/eww.nix).
ROOT_PODMAN = config().get("podman", "podman")


def podman_json(*args: str, root: bool = False) -> list:
    cmd = ["sudo", "-n", ROOT_PODMAN, *args] if root else ["podman", *args]
    try:
        data = json.loads(output(*cmd) or "[]")
    except ValueError:
        return []
    return data if isinstance(data, list) else []


def ports(c: dict) -> str:
    out = []
    for p in c.get("Ports") or []:
        host = f"{p.get('host_ip') or '0.0.0.0'}:{p.get('host_port')}"
        out.append(f"{host} → {p.get('container_port')}/{p.get('protocol', 'tcp')}")
    return ", ".join(out) or "none"


def mounts(c: dict, inspected: dict) -> list[str]:
    """source → destination (ro) from inspect, else ps's destinations."""
    info = inspected.get(c.get("Id", ""))
    if info:
        return [
            f"{m.get('Source') or m.get('Name', '')} → {m.get('Destination', '')}{'' if m.get('RW', True) else ' (ro)'}"
            for m in info.get("Mounts") or []
        ]
    return list(c.get("Mounts") or [])


def containers(root: bool) -> tuple[list, int]:
    """(running containers, how many are stopped)."""
    ps = [c for c in podman_json("ps", "-a", "--format", "json", root=root) if not c.get("IsInfra")]
    running = [c for c in ps if c.get("State") == "running"]
    if not running:
        return [], len(ps)
    stats = {s.get("id", ""): s for s in podman_json("stats", "--no-stream", "--format", "json", root=root)}
    # Inspect shows mount sources, but also environment variables, so root's
    # containers aren't inspected (the sudo rule allows ps and stats only).
    inspected = {}
    if not root:
        inspected = {i.get("Id", ""): i for i in podman_json("inspect", "--format", "json", *(c["Id"] for c in running))}
    out = []
    for c in running:
        cid = c.get("Id", "")
        s = stats.get(cid[:12], {})
        out.append(
            {
                "name": (c.get("Names") or [cid[:12]])[0],
                "pod": c.get("PodName") or "",
                "owner": "system" if root else "user",
                "image": c.get("Image", ""),
                "image_id": c.get("ImageID", "")[:12],
                "id": cid[:12],
                "status": c.get("Status", "") or "running",
                "restarts": c.get("Restarts", 0),
                "ports": ports(c),
                "mounts": mounts(c, inspected) or ["none"],
                "cpu": s.get("cpu_percent", "—"),
                "mem": s.get("mem_usage", "—"),
                "mem_pct": s.get("mem_percent", "—"),
                "net": s.get("net_io", "—"),
                "block": s.get("block_io", "—"),
                "pids": s.get("pids", "—"),
            }
        )
    return out, len(ps) - len(running)


def main() -> None:
    mine, mine_stopped = containers(root=False)
    system, system_stopped = containers(root=True)
    running = sorted(mine + system, key=lambda c: (c["pod"], c["name"]))
    print(
        json.dumps(
            {
                "count": len(running),
                # Two digits, so the dash tile's number keeps its width.
                "text": f"{min(len(running), 99):02d}",
                "stopped": mine_stopped + system_stopped,
                "containers": running,
            },
            separators=(",", ":"),
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
