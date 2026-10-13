"""The dash's display settings (the devices tile, home/eww/eww.yuck): every
display's resolution, rotation, on/off and place, and which one is primary,
drawn as a small map. Changes are a draft until Apply, which hands them all
to `eww-display apply` at once; a new resolution or rotation, or a display
turned on or off, is undone after 15 seconds unless kept.

Usage: eww-display-edit                  JSON for the dash (the draft, else sway's settings)
       eww-display-edit select NAME
       eww-display-edit power NAME       turn it on or off (one stays on)
       eww-display-edit mode NAME MODE   2560x1440@143.998Hz
       eww-display-edit rotate NAME normal|90|180|270
       eww-display-edit primary NAME
       eww-display-edit place NAME left|right|above|below OTHER
       eww-display-edit align start|center|end    how place lines up edges
       eww-display-edit apply | reset | keep | revert
"""

import json
import os
import subprocess
import sys
import time

from common import RUN_DIR, output

DRAFT = RUN_DIR / "eww-display-edit.json"
KEEP_SECONDS = 15
# Sway's output transforms, rotating clockwise, and how the dash names them.
ROTATIONS = [("normal", "Landscape"), ("90", "Portrait ↻"), ("180", "Upside down"), ("270", "Portrait ↺")]
# The map's size on the dash, in pixels.
MAP_W, MAP_H = 360, 150


def size(d: dict) -> tuple:
    """Size in sway's layout (logical pixels): the mode over the scale,
    on its side if the display is rotated."""
    if not d["mode"]:
        return 1920, 1080
    w, h = (int(v) for v in d["mode"].split("@")[0].split("x"))
    w, h = round(w / d["scale"]), round(h / d["scale"])
    return (h, w) if d["transform"] in ("90", "270") else (w, h)


def rect(d: dict) -> tuple:
    return (d["x"], d["y"], *size(d))


def overlaps(a: tuple, b: tuple) -> bool:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah


def touches(a: tuple, b: tuple) -> bool:
    """Edges meet along a stretch, so the pointer can cross from one to the other."""
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    side = (ax + aw == bx or bx + bw == ax) and ay < by + bh and by < ay + ah
    stacked = (ay + ah == by or by + bh == ay) and ax < bx + bw and bx < ax + aw
    return side or stacked


def misplaced(d: dict, others: list) -> bool:
    """d overlaps one of the others, or touches none of them."""
    if not others:
        return False
    return any(overlaps(rect(d), rect(o)) for o in others) or not any(touches(rect(d), rect(o)) for o in others)


def snap(d: dict, others: list) -> None:
    """Move d to the nearest place beside one of the others where it
    touches it and overlaps none."""
    w, h = size(d)
    best = None
    for o in others:
        ox, oy, ow, oh = rect(o)
        spots = [(x, min(max(d["y"], oy - h + 1), oy + oh - 1)) for x in (ox - w, ox + ow)]
        spots += [(min(max(d["x"], ox - w + 1), ox + ow - 1), y) for y in (oy - h, oy + oh)]
        for pos in spots:
            if any(overlaps((*pos, w, h), rect(p)) for p in others):
                continue
            distance = (pos[0] - d["x"]) ** 2 + (pos[1] - d["y"]) ** 2
            if best is None or distance < best[0]:
                best = (distance, pos)
    if best:
        d["x"], d["y"] = best[1]


def on(draft: dict) -> list:
    return [d for d in draft["displays"] if d["enabled"]]


def settle(draft: dict, fixed: str = "") -> None:
    """Move any display that overlaps another, or touches none, beside the
    rest (fixed, the one just placed, stays put); then start the layout at 0,0."""
    placed = [d for d in on(draft) if d["name"] == fixed]
    for d in sorted(on(draft), key=lambda d: (d["x"], d["y"])):
        if d["name"] == fixed:
            continue
        if misplaced(d, placed):
            snap(d, placed)
        placed.append(d)
    if on(draft):
        mx, my = min(d["x"] for d in on(draft)), min(d["y"] for d in on(draft))
        for d in on(draft):
            d["x"], d["y"] = int(d["x"] - mx), int(d["y"] - my)


def from_sway() -> dict:
    """The displays as sway has them now."""
    try:
        listing = json.loads(output("eww-display") or "{}")
        sway = {o["name"]: o for o in json.loads(output("swaymsg", "-r", "-t", "get_outputs") or "[]")}
    except ValueError:
        listing, sway = {}, {}
    displays = []
    for e in listing.get("outputs", []):
        s = sway.get(e["name"], {})
        r = s.get("rect") or {}
        displays.append(
            {
                "name": e["name"],
                "number": e["number"],
                "title": e["title"],
                "gpu": e.get("gpu", ""),
                "modes": e["modes"],
                "enabled": bool(s.get("active")),
                "mode": e["current_id"] or (e["modes"][0]["id"] if e["modes"] else ""),
                "scale": s.get("scale") if (s.get("scale") or 0) > 0 else 1.0,
                "transform": e.get("transform") or "normal",
                "x": r.get("x", 0),
                "y": r.get("y", 0),
            }
        )
    primary = listing.get("primary", "")
    return {"displays": displays, "primary": primary, "selected": primary, "align": "start", "dirty": False}


def load() -> dict:
    """The draft, or sway's settings while there is none (so the dash follows
    changes made elsewhere); the selection and confirmation carry over."""
    try:
        draft = json.loads(DRAFT.read_text())
    except (OSError, ValueError):
        draft = {}
    if draft.get("dirty"):
        return draft
    fresh = from_sway()
    names = {d["name"] for d in fresh["displays"]}
    fresh["selected"] = draft.get("selected") if draft.get("selected") in names else fresh["primary"]
    fresh["align"] = draft.get("align", "start")
    for k in ("confirm", "before"):
        if k in draft:
            fresh[k] = draft[k]
    return fresh


def setting(d: dict) -> dict:
    if not d["enabled"]:
        return {"enabled": False}
    return {"enabled": True, "mode": d["mode"], "transform": d["transform"], "x": int(d["x"]), "y": int(d["y"])}


def view(draft: dict) -> str:
    """What the dash shows: each display's form and its box on the map. The
    boxes sit in a row, so each one's left margin is measured from the end of
    the one before it (and may be negative)."""
    shown = on(draft)
    if shown:
        x0, y0 = min(d["x"] for d in shown), min(d["y"] for d in shown)
        x1 = max(d["x"] + size(d)[0] for d in shown)
        y1 = max(d["y"] + size(d)[1] for d in shown)
        scale = min((MAP_W - 8) / max(x1 - x0, 1), (MAP_H - 8) / max(y1 - y0, 1))
        ox, oy = (MAP_W - (x1 - x0) * scale) / 2, (MAP_H - (y1 - y0) * scale) / 2
    boxes, end = [], 0
    for d in sorted(shown, key=lambda d: d["x"]):
        w, h = size(d)
        left = round(ox + (d["x"] - x0) * scale)
        bw, bh = max(round(w * scale) - 4, 8), max(round(h * scale) - 4, 8)
        boxes.append(
            {
                "name": d["name"],
                "number": d["number"],
                "ml": left - end,
                "mt": round(oy + (d["y"] - y0) * scale),
                "w": bw,
                "h": bh,
                "selected": d["name"] == draft["selected"],
                "primary": d["name"] == draft["primary"],
            }
        )
        end = left + bw
    sel = next((d for d in draft["displays"] if d["name"] == draft["selected"]), None)
    others = [o["name"] for o in shown if sel and o["name"] != sel["name"]]
    form = {}
    if sel:
        w, h = size(sel)
        form = {
            "name": sel["name"],
            "title": sel["title"],
            "gpu": sel["gpu"],
            "enabled": sel["enabled"],
            "primary": sel["name"] == draft["primary"],
            "mode": sel["mode"],
            "mode_label": next((m["label"] for m in sel["modes"] if m["id"] == sel["mode"]), sel["mode"]),
            "transform": sel["transform"],
            "where": f"{w}x{h} at {sel['x']},{sel['y']}",
            "modes": [{**m, "current": m["id"] == sel["mode"]} for m in sel["modes"]],
            "rotations": [{"id": t, "label": label, "current": t == sel["transform"]} for t, label in ROTATIONS],
            "others": others,
        }
    left = max(0, int(draft.get("confirm", 0) - time.time())) if draft.get("confirm") else 0
    return json.dumps(
        {
            "boxes": boxes,
            "map_w": MAP_W,
            "map_h": MAP_H,
            "selected": draft["selected"],
            "align": draft.get("align", "start"),
            "dirty": draft.get("dirty", False),
            "confirm": left,
            "names": [{"name": d["name"], "number": d["number"], "selected": d["name"] == draft["selected"]} for d in draft["displays"]],
            "form": form,
        },
        separators=(",", ":"),
        ensure_ascii=False,
    )


def save(draft: dict) -> None:
    DRAFT.write_text(json.dumps(draft))
    output("eww", "update", f"display_edit={view(draft)}")


def place(draft: dict, name: str, side: str, other: str) -> None:
    d = next(x for x in draft["displays"] if x["name"] == name)
    o = next(x for x in draft["displays"] if x["name"] == other)
    (ox, oy, ow, oh), (w, h) = rect(o), size(d)
    # How the shared edge lines up: start (top or left), centre or end.
    shift = {"start": 0, "center": 0.5, "end": 1}[draft.get("align", "start")]
    if side in ("left", "right"):
        d["x"] = ox - w if side == "left" else ox + ow
        d["y"] = round(oy + (oh - h) * shift)
    else:
        d["y"] = oy - h if side == "above" else oy + oh
        d["x"] = round(ox + (ow - w) * shift)
    settle(draft, fixed=name)


def resized(draft: dict, d: dict, old: tuple) -> None:
    """d's size changed: displays right of or below it move with its new edge."""
    (ow, oh), (w, h) = old, size(d)
    for o in on(draft):
        if o is not d:
            if o["x"] >= d["x"] + ow:
                o["x"] += w - ow
            if o["y"] >= d["y"] + oh:
                o["y"] += h - oh
    settle(draft)


def apply(draft: dict) -> None:
    before = from_sway()
    risky = any(
        d["enabled"] != b["enabled"] or (d["enabled"] and (d["mode"] != b["mode"] or d["transform"] != b["transform"]))
        for d in draft["displays"]
        for b in before["displays"]
        if b["name"] == d["name"]
    )
    wanted = {"primary": draft["primary"], "outputs": {d["name"]: setting(d) for d in draft["displays"]}}
    output("eww-display", "apply", json.dumps(wanted))
    selected = draft["selected"]
    DRAFT.unlink(missing_ok=True)
    draft = load() | {"selected": selected}
    if risky:
        # Undone in KEEP_SECONDS unless kept, in case the picture is gone.
        draft["confirm"] = time.time() + KEEP_SECONDS
        draft["before"] = {"primary": before["primary"], "outputs": {d["name"]: setting(d) for d in before["displays"]}}
        subprocess.Popen(["eww-display-edit", "countdown"], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    save(draft)


def countdown() -> None:
    while True:
        time.sleep(1)
        draft = load()
        if not draft.get("confirm"):
            return
        if time.time() >= draft["confirm"]:
            revert(draft)
            return
        output("eww", "update", f"display_edit={view(draft)}")


def revert(draft: dict) -> None:
    before = draft.pop("before", None)
    draft.pop("confirm", None)
    DRAFT.write_text(json.dumps(draft))
    if before:
        output("eww-display", "apply", json.dumps(before))
    save(load())


def main(args: list[str]) -> None:
    command, rest = (args[0], args[1:]) if args else ("", [])
    draft = load()
    names = {d["name"]: d for d in draft["displays"]}
    if command == "countdown":
        countdown()
        return
    if command == "keep":
        draft.pop("confirm", None)
        draft.pop("before", None)
        save(draft)
        return
    if command == "revert":
        revert(draft)
        return
    if command == "reset":
        DRAFT.unlink(missing_ok=True)
        save(load())
        return
    if command == "apply":
        apply(draft)
        return
    if command == "select" and rest and rest[0] in names:
        draft["selected"] = rest[0]
        save(draft)
        return
    if command == "align" and rest and rest[0] in ("start", "center", "end"):
        draft["align"] = rest[0]
        save(draft)
        return
    d = names.get(rest[0]) if rest else None
    if not d:
        print(view(draft))
        return
    old = size(d)
    if command == "power":
        # The primary display, and the last one on, stay on.
        if d["enabled"] and (d["name"] == draft["primary"] or len(on(draft)) == 1):
            return
        d["enabled"] = not d["enabled"]
        if d["enabled"]:
            d["x"] = max((o["x"] + size(o)[0] for o in on(draft) if o is not d), default=0)
        settle(draft)
    elif command == "mode" and len(rest) == 2:
        d["mode"] = rest[1]
        resized(draft, d, old)
    elif command == "rotate" and len(rest) == 2:
        d["transform"] = rest[1]
        resized(draft, d, old)
    elif command == "primary" and d["enabled"]:
        draft["primary"] = d["name"]
    elif command == "place" and len(rest) == 3 and rest[2] in names and rest[1] in ("left", "right", "above", "below"):
        place(draft, d["name"], rest[1], rest[2])
    else:
        print(view(draft))
        return
    draft["dirty"] = True
    save(draft)


if __name__ == "__main__":
    os.umask(0o077)
    main(sys.argv[1:])
