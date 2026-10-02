"""The sway workspace list as JSON, again on every workspace or output event."""

import json
import subprocess


def emit() -> None:
    out = subprocess.run(["swaymsg", "-r", "-t", "get_workspaces"], capture_output=True, text=True).stdout
    try:
        workspaces = json.loads(out)
    except ValueError:
        workspaces = []
    workspaces.sort(key=lambda w: w.get("num") if w.get("num") is not None else -1)
    rows = [{"name": w.get("name"), "focused": w.get("focused"), "urgent": w.get("urgent")} for w in workspaces]
    print(json.dumps(rows, separators=(",", ":"), ensure_ascii=False), flush=True)


def main() -> None:
    emit()
    with subprocess.Popen(
        ["swaymsg", "-r", "-t", "subscribe", "-m", '["workspace", "output"]'], stdout=subprocess.PIPE, text=True
    ) as events:
        for _ in events.stdout or []:
            emit()


if __name__ == "__main__":
    main()
