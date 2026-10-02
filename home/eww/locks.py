"""Caps Lock / Num Lock state from the keyboard LEDs (world-readable), as
{"caps": bool, "num": bool}. Any keyboard with the LED lit counts.
"""

import json
from pathlib import Path


def lit(led: str) -> bool:
    for brightness in Path("/sys/class/leds").glob(f"*::{led}/brightness"):
        try:
            if brightness.read_text().strip() != "0":
                return True
        except OSError:
            continue
    return False


if __name__ == "__main__":
    print(json.dumps({"caps": lit("capslock"), "num": lit("numlock")}, separators=(",", ":")))
