"""Memory details for the dash's memory tile (home/eww/eww.yuck), from
/proc/meminfo: what programs use, the page cache, shared memory, what is
free and available, swap (and zswap's pool), memory waiting to be written
to disk, and the processes with the most resident memory (procs.py).

"Used" is what free(1) calls used: total minus free, buffers and cache.
"""

import json
from pathlib import Path

from common import read
from procs import size, snapshot, top_mem


def meminfo() -> dict:
    """/proc/meminfo in bytes."""
    info = {}
    for line in read(Path("/proc/meminfo")).splitlines():
        key, _, value = line.partition(":")
        parts = value.split()
        if parts and parts[0].isdigit():
            info[key] = int(parts[0]) * 1024
    return info


def part(value: int, total: int) -> dict:
    return {"text": size(value), "pct": round(value / total * 100) if total else 0}


def main() -> None:
    m = meminfo()
    total = m.get("MemTotal", 0)
    cache = m.get("Buffers", 0) + m.get("Cached", 0) + m.get("SReclaimable", 0)
    used = max(total - m.get("MemFree", 0) - cache, 0)
    swap_total = m.get("SwapTotal", 0)
    swap_used = swap_total - m.get("SwapFree", 0)
    print(
        json.dumps(
            {
                "total": size(total),
                "used": part(used, total),
                "cache": part(cache, total),
                "shared": part(m.get("Shmem", 0), total),
                "free": part(m.get("MemFree", 0), total),
                "available": part(m.get("MemAvailable", 0), total),
                "swap": {**part(swap_used, swap_total), "total": size(swap_total), "on": swap_total > 0},
                "zswap": size(m.get("Zswap", 0)),
                "dirty": size(m.get("Dirty", 0) + m.get("Writeback", 0)),
                "top": top_mem(snapshot(), total),
            },
            ensure_ascii=False,
            separators=(",", ":"),
        )
    )


if __name__ == "__main__":
    main()
