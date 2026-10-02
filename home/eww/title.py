"""The focused window's title, again whenever focus or titles change."""

import json
import subprocess
from typing import Iterator


def objects(value: object) -> Iterator[dict]:
    """Every object in the tree, parents before children (like jq's `..`)."""
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from objects(child)
    elif isinstance(value, list):
        for child in value:
            yield from objects(child)


def emit() -> None:
    out = subprocess.run(["swaymsg", "-r", "-t", "get_tree"], capture_output=True, text=True).stdout
    try:
        tree = json.loads(out)
    except ValueError:
        tree = {}
    focused = next((node for node in objects(tree) if node.get("focused") is True), {})
    print((focused.get("name") or "")[:80], flush=True)


def main() -> None:
    emit()
    with subprocess.Popen(
        ["swaymsg", "-r", "-t", "subscribe", "-m", '["window", "workspace"]'], stdout=subprocess.PIPE, text=True
    ) as events:
        for _ in events.stdout or []:
            emit()


if __name__ == "__main__":
    main()
