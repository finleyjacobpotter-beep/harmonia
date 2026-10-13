"""Every AMD GPU's load, temperatures, VRAM, power, fan and clocks from
rocm-smi (modules/nixos/fans.nix), for the bar's GPU module and its panel.

Usage: eww-gpu              the JSON below
       eww-gpu main BUS     put the GPU at PCI address BUS on the bar
                            ("auto" = the one with the most VRAM)

{"ok": bool, "auto": bool, "text": " 37%  52°C", "use": %, "temp": °C,
 "vram": %, "vram_text": "6.1/16 GiB", "name": "…",   (the main GPU)
 "gpus": [{"bus": "0000:03:00.0", "name": …, "use": %, "vram": %, …}]}

The bar shows the main GPU's numbers and a pair of small meters (load and
VRAM) for every GPU. rocm-smi's card numbers needn't match /sys/class/drm's,
so GPUs are matched to their DRM card (and its displays) by PCI address.
"""

import json
import math
import re
import subprocess
import sys
from pathlib import Path

from common import STATE_DIR, config, output, read

STATE = STATE_DIR / "gpu-main"
PCI = Path("/sys/bus/pci/devices")
DRM = Path("/sys/class/drm")
# hwdata's pci.ids (home/eww.nix).
PCI_IDS = config().get("pciIds", "/usr/share/hwdata/pci.ids")

EMPTY = {"ok": False, "auto": True, "use": 0, "temp": 0, "vram": 0, "vram_text": "", "name": "", "text": "", "gpus": []}


def rounded(x: float) -> int:
    return math.floor(x + 0.5)


def number(value: object) -> float | int | None:
    """A number from rocm-smi's strings, "(1650Mhz)" included."""
    if isinstance(value, str):
        m = re.search(r"-?\d+(\.\d+)?", value)
        value = m.group(0) if m else None
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
    """GiB to one decimal, printed like jq: 6.1, 16."""
    x = rounded(n / 1073741824 * 10) / 10
    return str(int(x)) if x.is_integer() else str(x)


def pci_name(vendor: str, device: str, sub_vendor: str, sub_device: str) -> tuple[str, str]:
    """(marketing name, chip) from pci.ids: the board's own entry if it has
    one, else the chip's bracketed names, "Navi 48 [Radeon RX 9070/…]"."""
    chip_line, board = "", ""
    try:
        with open(PCI_IDS, encoding="utf-8", errors="replace") as f:
            in_vendor = in_device = False
            for line in f:
                if line.startswith("#") or not line.strip():
                    continue
                if line[0] != "\t":
                    if in_vendor:
                        break
                    in_vendor = line[:4] == vendor
                elif in_vendor and line[1] != "\t":
                    if in_device:
                        break
                    in_device = line[1:5] == device
                    if in_device:
                        chip_line = line[5:].strip()
                elif in_device and line[2:11] == f"{sub_vendor} {sub_device}":
                    board = line[11:].strip()
    except OSError:
        pass
    m = re.match(r"(.*?)\s*\[(.*)\]$", chip_line)
    chip, family = (m.group(1), m.group(2)) if m else (chip_line, chip_line)
    return board or family or f"{vendor}:{device}", chip


def gpu_name(bus: str) -> tuple[str, str]:
    """(name, chip) of the GPU at PCI address bus, from its sysfs IDs."""
    dev = PCI / bus

    def hex4(field: str) -> str:
        return read(dev / field).removeprefix("0x")

    return pci_name(hex4("vendor"), hex4("device"), hex4("subsystem_vendor"), hex4("subsystem_device"))


def output_gpu(output: str) -> str:
    """The GPU a display (sway's output name, "DP-1") is plugged into, as
    "Radeon RX 9070/… (03:00.0)"; connector names are unique across cards
    (card1-DP-1). Used by display.py for the display settings window."""
    for conn in DRM.glob(f"card[0-9]*-{output}"):
        bus = (DRM / conn.name.split("-", 1)[0] / "device").resolve().name
        return f"{gpu_name(bus)[0]} ({bus.removeprefix('0000:')})"
    return ""


def sysfs(bus: str) -> dict:
    """What sysfs adds for the GPU at bus: its name, power cap and the
    displays plugged into it."""
    dev = PCI / bus
    name, chip = gpu_name(bus)
    cap = number(next((read(p) for p in dev.glob("hwmon/hwmon*/power1_cap")), ""))
    displays = []
    for card in DRM.glob("card[0-9]*"):
        if "-" in card.name or (card / "device").resolve().name != bus:
            continue
        for conn in sorted(DRM.glob(f"{card.name}-*")):
            if read(conn / "status") == "connected":
                displays.append(conn.name.split("-", 1)[1])
    return {"name": name, "chip": chip, "cap": rounded(cap / 1e6) if cap else 0, "displays": displays}


def card_stats(card: dict) -> dict | None:
    use = pick(card, "^GPU use")
    bus = card.get("PCI Bus", "")
    if use is None or not bus:
        return None
    total = pick(card, "VRAM Total Memory") or 0
    used = pick(card, "VRAM Total Used") or 0
    edge = pick(card, "Temperature.*edge")
    temp = rounded(edge if edge is not None else (pick(card, "^Temperature") or 0))
    extra = sysfs(bus)
    power = rounded(pick(card, "Graphics Package Power") or pick(card, "Socket Graphics Package Power") or 0)

    def mhz(key: str) -> str:
        n = pick(card, f"^{key} clock speed")
        return f"{n} MHz" if n is not None else "—"

    fan, rpm = pick(card, r"^Fan speed \(%"), pick(card, "^Fan RPM")
    pcie = re.search(r"\((.*)\)", card.get("pcie clock level", ""))
    return {
        "bus": bus,
        "short": bus.removeprefix("0000:"),
        "name": extra["name"],
        "chip": extra["chip"],
        "use": use,
        "temp": temp,
        "hotspot": rounded(pick(card, "Temperature.*junction") or 0),
        "mem_temp": rounded(pick(card, "Temperature.*memory") or 0),
        "vram": rounded(used * 100 / total) if total > 0 else 0,
        "vram_total": total,
        "vram_text": f"{gib(used)}/{gib(total)} GiB" if total > 0 else "—",
        "mem_busy": pick(card, "Memory Read/Write Activity") or 0,
        "power_text": f"{power} W" + (f" of {extra['cap']} W" if extra["cap"] else ""),
        "fan_text": f"{fan}% · {rpm} RPM" if rpm is not None else "—",
        "sclk": mhz("sclk"),
        "mclk": mhz("mclk"),
        "pcie": pcie.group(1) if pcie else "—",
        "displays": ", ".join(extra["displays"]) or "none",
    }


def stats(data: dict, choice: str) -> dict:
    gpus = [g for g in (card_stats(c) for k, c in data.items() if k.startswith("card") and isinstance(c, dict)) if g]
    if not gpus:
        return EMPTY
    gpus.sort(key=lambda g: g["bus"])
    auto = choice == "auto" or not any(g["bus"] == choice for g in gpus)
    main = max(gpus, key=lambda g: g["vram_total"]) if auto else next(g for g in gpus if g["bus"] == choice)
    for g in gpus:
        g["main"] = g is main
        del g["vram_total"]
    return {
        "ok": True,
        "auto": auto,
        "use": main["use"],
        "temp": main["temp"],
        "vram": main["vram"],
        "vram_text": main["vram_text"],
        "name": main["name"],
        # Left-padded for the worst case, "100% 200°C", so the bar stays put.
        "text": f"{main['use']:>3}% {main['temp']:>3}°C",
        "gpus": gpus,
    }


def listing() -> str:
    out = output("rocm-smi", "--showuse", "--showtemp", "--showmeminfo", "vram", "--showmemuse", "--showpower", "--showclocks", "--showfan", "--showbus", "--json")
    # Without an amdgpu it prints nothing and still exits 0.
    try:
        data = json.loads(out) if out.strip() else {}
    except ValueError:
        data = {}
    result = stats(data, read(STATE, "auto") or "auto") if isinstance(data, dict) else EMPTY
    return json.dumps(result, separators=(",", ":"), ensure_ascii=False)


def main(args: list[str]) -> None:
    if args[:1] == ["main"] and len(args) > 1:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        STATE.write_text(args[1] + "\n")
        subprocess.run(["eww", "update", f"gpu={listing()}"])
    else:
        print(listing())


if __name__ == "__main__":
    main(sys.argv[1:])
