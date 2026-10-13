"""The busiest processes, for the dash's CPU and memory tiles (cpu.py,
mem.py): each process's CPU since the last call, measured from /proc like
top does, and its resident memory.
"""

import json
import os
import time
from pathlib import Path

from common import RUN_DIR

SAMPLE = RUN_DIR / "eww-procs.json"
TICKS = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")


def snapshot() -> dict:
    """{pid: (name, cpu ticks so far, resident bytes)} for every process."""
    procs = {}
    for stat in Path("/proc").glob("[0-9]*/stat"):
        try:
            text = stat.read_text()
        except OSError:
            continue
        # The name is in parentheses and may hold spaces, so split after it.
        name = text[text.find("(") + 1:text.rfind(")")]
        fields = text[text.rfind(")") + 2:].split()
        try:
            procs[stat.parent.name] = (name, int(fields[11]) + int(fields[12]), int(fields[21]) * PAGE)
        except (IndexError, ValueError):
            continue
    return procs


def size(n: float) -> str:
    for unit in ("B", "KiB", "MiB"):
        if n < 1024:
            return f"{n:.0f} {unit}"
        n /= 1024
    return f"{n:.1f} GiB"


def top_cpu(procs: dict, count: int = 8) -> list:
    """The processes that used the most CPU since the previous call, in
    percent of one thread (so 250% is two and a half threads)."""
    now = time.monotonic()
    try:
        before = json.loads(SAMPLE.read_text())
    except (OSError, ValueError):
        before = {}
    SAMPLE.write_text(json.dumps({"time": now, "ticks": {pid: p[1] for pid, p in procs.items()}}))
    elapsed = now - before.get("time", now)
    if elapsed <= 0:
        return []
    old = before.get("ticks", {})
    used = [(p[1] - old[pid], pid, p[0]) for pid, p in procs.items() if pid in old and p[1] > old[pid]]
    rows = []
    for ticks, pid, name in sorted(used, reverse=True)[:count]:
        pct = ticks / TICKS / elapsed * 100
        rows.append({"pid": pid, "name": name, "pct": min(round(pct), 100), "text": f"{pct:.1f}%"})
    return rows


def top_mem(procs: dict, total: int, count: int = 8) -> list:
    """The processes with the most resident memory, against total bytes."""
    rows = []
    for pid, (name, _, rss) in sorted(procs.items(), key=lambda item: -item[1][2])[:count]:
        rows.append({"pid": pid, "name": name, "pct": round(rss / total * 100) if total else 0, "text": size(rss)})
    return rows
