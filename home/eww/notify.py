"""Notifications for the dash's notifications tile (home/eww/eww.yuck):
mako's current ones, how many are in its history, and focus, which is
mako's do-not-disturb mode (home/sway.nix makes it hide every popup).

Usage: eww-notify               JSON: {"focus": false, "count": N, "urgent": N,
                                 "history": N, "list": [...]}
       eww-notify focus         turn focus on or off
       eww-notify clear         dismiss every notification
       eww-notify clear-calm    dismiss all but the critical ones
       eww-notify dismiss ID
       eww-notify restore       bring back the last dismissed one
"""

import json
import sys

from common import output

FOCUS = "do-not-disturb"


def notifications(kind: str = "list") -> list:
    try:
        return json.loads(output("makoctl", kind, "-j") or "[]")
    except ValueError:
        return []


def state() -> str:
    shown = notifications()
    return json.dumps(
        {
            "focus": FOCUS in output("makoctl", "mode").split(),
            "count": len(shown),
            "urgent": sum(1 for n in shown if n.get("urgency") == "critical"),
            "history": len(notifications("history")),
            "list": [
                {
                    "id": n.get("id"),
                    "app": n.get("app_name") or "",
                    "summary": n.get("summary") or "",
                    "body": " ".join((n.get("body") or "").split()),
                    "urgency": n.get("urgency") or "normal",
                }
                for n in shown
            ],
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )


def main(args: list[str]) -> None:
    command, rest = (args[0], args[1:]) if args else ("", [])
    if command == "focus":
        output("makoctl", "mode", "-t", FOCUS)
    elif command == "clear":
        output("makoctl", "dismiss", "--all")
    elif command == "clear-calm":
        for n in notifications():
            if n.get("urgency") != "critical":
                output("makoctl", "dismiss", "-n", str(n.get("id")))
    elif command == "dismiss" and rest:
        output("makoctl", "dismiss", "-n", rest[0])
    elif command == "restore":
        output("makoctl", "restore")
    else:
        print(state())
        return
    output("eww", "update", f"notify={state()}")


if __name__ == "__main__":
    main(sys.argv[1:])
