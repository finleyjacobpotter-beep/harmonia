"""GPU load, temperature and VRAM from rocm-smi (modules/nixos/fans.nix), as
{"ok": bool, "use": %, "temp": °C, "vram": %, "vram_text": "6.1/16.0 GiB",
 "text": " 37%  52°C"} (padded to a fixed width for the bar).
With several GPUs, the one with the most VRAM is shown.
"""

import json
import math
import re
import subprocess

EMPTY = {"ok": False, "use": 0, "temp": 0, "vram": 0, "vram_text": "", "text": ""}


def rounded(x: float) -> int:
    return math.floor(x + 0.5)


def number(value: object) -> float | int | None:
    try:
        x = float(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None
    return int(x) if x.is_integer() else x


def pick(card: dict, pattern: str) -> float | int | None:
    """The first field whose name matches pattern, as a number."""
    for key, value in card.items():
        if re.search(pattern, key):
            return number(value)
    return None


def gib(n: float) -> str:
    return f"{rounded(n / 1073741824 * 10) / 10:.1f}"


def stats(data: dict) -> dict:
    cards = []
    for key, card in data.items():
        if not key.startswith("card") or not isinstance(card, dict):
            continue
        temp = pick(card, "Temperature.*edge")
        cards.append(
            {
                "use": pick(card, "^GPU use"),
                "temp": temp if temp is not None else pick(card, "^Temperature"),
                "total": pick(card, "VRAM Total Memory") or 0,
                "used": pick(card, "VRAM Total Used") or 0,
            }
        )
    if not cards:
        return EMPTY
    gpu = max(cards, key=lambda c: c["total"])
    if gpu["use"] is None:
        return EMPTY
    total, used = gpu["total"], gpu["used"]
    temp = rounded(gpu["temp"] or 0)
    return {
        "ok": True,
        "use": gpu["use"],
        "temp": temp,
        "vram": rounded(used * 100 / total) if total > 0 else 0,
        "vram_text": f"{gib(used)}/{gib(total)} GiB" if total > 0 else "",
        # Left-padded for the worst case, "100% 200°C", so the bar stays put.
        "text": f"{gpu['use']:>3}% {temp:>3}°C",
    }


def main() -> None:
    try:
        out = subprocess.run(
            ["rocm-smi", "--showuse", "--showtemp", "--showmeminfo", "vram", "--json"],
            capture_output=True,
            text=True,
        ).stdout
    except OSError:
        out = ""
    # Without an amdgpu it prints nothing and still exits 0.
    try:
        data = json.loads(out) if out.strip() else {}
    except ValueError:
        data = {}
    print(json.dumps(stats(data) if isinstance(data, dict) else EMPTY, separators=(",", ":")))


if __name__ == "__main__":
    main()
