"""The display settings window: every display's layout, resolution and on/off,
and which one is primary (has the bar), in one place. Nothing changes until
Apply, which hands everything to `eww-display apply` at once; a new
resolution, or a display turned on or off, is undone after 15 seconds
unless kept.

Usage: display-settings             open the window
       display-settings --toggle    close it if it is open, else open it (the bar button)
"""

import json
import subprocess
import sys

import gi

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

APP_ID = "harmonia.display-settings"
# Replaced with the Miami Wind palette at build time (home/eww.nix).
COLORS = {"bg": "#181825", "surface": "#313244", "fg": "#cdd6f4", "muted": "#7f849c", "pink": "#f472b6", "cyan": "#22d3ee"}
KEEP_SECONDS = 15
SNAP_PX = 24  # how close (on screen) an edge must be to line up with another


def run(*args: str) -> str:
    try:
        return subprocess.run(args, capture_output=True, text=True).stdout
    except OSError:
        return ""


def rgb(name: str) -> tuple:
    h = COLORS[name].lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def mode_size(mode_id: str) -> tuple:
    """2560x1440@143.998Hz -> (2560, 1440)"""
    w, h = mode_id.split("@")[0].split("x")
    return int(w), int(h)


class Display:
    def __init__(self, entry: dict, sway: dict):
        self.name = entry["name"]
        self.number = entry["number"]
        self.title = entry["title"]
        self.modes = entry["modes"]
        self.enabled = bool(sway.get("active"))
        self.mode = entry["current_id"] or (self.modes[0]["id"] if self.modes else "")
        self.scale = sway.get("scale") or 1.0
        if self.scale <= 0:
            self.scale = 1.0
        self.rotated = sway.get("transform") in ("90", "270", "flipped-90", "flipped-270")
        rect = sway.get("rect") or {}
        self.x, self.y = rect.get("x", 0), rect.get("y", 0)

    @property
    def size(self) -> tuple:
        """Size in sway's layout (logical pixels): the mode divided by the
        scale, turned on its side if the display is rotated."""
        if not self.mode:
            return 1920, 1080
        w, h = mode_size(self.mode)
        w, h = round(w / self.scale), round(h / self.scale)
        return (h, w) if self.rotated else (w, h)

    def setting(self) -> dict:
        if not self.enabled:
            return {"enabled": False}
        return {"enabled": True, "mode": self.mode, "x": int(self.x), "y": int(self.y)}


def load() -> tuple:
    """The displays as sway has them now, and the primary one."""
    try:
        listing = json.loads(run("eww-display") or "{}")
        sway = {o["name"]: o for o in json.loads(run("swaymsg", "-r", "-t", "get_outputs") or "[]")}
    except ValueError:
        return [], ""
    displays = [Display(e, sway.get(e["name"], {})) for e in listing.get("outputs", [])]
    return displays, listing.get("primary", "")


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


def rect(d: Display) -> tuple:
    return (d.x, d.y, *d.size)


def misplaced(d: Display, others: list) -> bool:
    """d overlaps one of the others, or touches none of them."""
    if not others:
        return False
    overlap = any(overlaps(rect(d), rect(o)) for o in others)
    return overlap or not any(touches(rect(d), rect(o)) for o in others)


def snap(d: Display, others: list, threshold: float) -> None:
    """Move d to the nearest place beside one of the others where it touches
    it and overlaps none, lining its edges up with theirs when they are close."""
    if not others:
        d.x, d.y = 0, 0
        return
    w, h = d.size
    best = None
    for o in others:
        ox, oy, ow, oh = rect(o)
        # Beside o (left, right): x is fixed, y slides along o's side.
        for x in (ox - w, ox + ow):
            k = min(h, oh) // 4  # keep a good stretch of shared edge
            y = min(max(d.y, oy - h + k), oy + oh - k)
            for edge in (oy, oy + oh - h):
                if abs(y - edge) <= threshold:
                    y = edge
            best = closer(d, others, (x, y), best)
        # Above or below o: y is fixed, x slides along o's top or bottom.
        for y in (oy - h, oy + oh):
            k = min(w, ow) // 4
            x = min(max(d.x, ox - w + k), ox + ow - k)
            for edge in (ox, ox + ow - w):
                if abs(x - edge) <= threshold:
                    x = edge
            best = closer(d, others, (x, y), best)
    if best:
        d.x, d.y = best[1]


def closer(d: Display, others: list, pos: tuple, best):
    w, h = d.size
    if any(overlaps((*pos, w, h), rect(o)) for o in others):
        return best
    distance = (pos[0] - d.x) ** 2 + (pos[1] - d.y) ** 2
    return (distance, pos) if best is None or distance < best[0] else best


class Window(Gtk.ApplicationWindow):
    def __init__(self, app: Gtk.Application):
        super().__init__(application=app, title="Displays")
        self.set_default_size(640, 0)
        self.set_border_width(16)
        self.connect("key-press-event", self.on_key)

        self.displays, self.primary = load()
        self.selected = self.primary or (self.displays[0].name if self.displays else "")
        self.drag = None
        self.view = (1.0, 0.0, 0.0)  # scale and offset of the layout on the canvas

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.add(box)

        self.canvas = Gtk.DrawingArea()
        self.canvas.set_size_request(600, 280)
        self.canvas.add_events(
            Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK | Gdk.EventMask.POINTER_MOTION_MASK)
        self.canvas.connect("draw", self.on_draw)
        self.canvas.connect("button-press-event", self.on_press)
        self.canvas.connect("motion-notify-event", self.on_motion)
        self.canvas.connect("button-release-event", self.on_release)
        box.pack_start(self.canvas, True, True, 0)

        hint = Gtk.Label(label="Drag the displays to arrange them; click one to change it below.", xalign=0)
        hint.get_style_context().add_class("dim-label")
        box.pack_start(hint, False, False, 0)

        grid = Gtk.Grid(column_spacing=16, row_spacing=10)
        box.pack_start(grid, False, False, 0)

        self.heading = Gtk.Label(xalign=0)
        grid.attach(self.heading, 0, 0, 2, 1)

        grid.attach(Gtk.Label(label="On", xalign=0), 0, 1, 1, 1)
        self.enabled = Gtk.Switch(halign=Gtk.Align.START)
        self.enabled.connect("notify::active", self.on_enabled)
        grid.attach(self.enabled, 1, 1, 1, 1)

        grid.attach(Gtk.Label(label="Resolution", xalign=0), 0, 2, 1, 1)
        self.resolution = Gtk.ComboBoxText(hexpand=True)
        self.resolution.connect("changed", self.on_resolution)
        grid.attach(self.resolution, 1, 2, 1, 1)

        grid.attach(Gtk.Label(label="Primary", xalign=0), 0, 3, 1, 1)
        self.make_primary = Gtk.CheckButton(label="Has the bar and its panels")
        self.make_primary.connect("toggled", self.on_primary)
        grid.attach(self.make_primary, 1, 3, 1, 1)

        grid.attach(Gtk.Label(label="Position", xalign=0), 0, 4, 1, 1)
        self.position = Gtk.Label(xalign=0)
        self.position.get_style_context().add_class("dim-label")
        grid.attach(self.position, 1, 4, 1, 1)

        buttons = Gtk.Box(spacing=8, halign=Gtk.Align.END)
        reset = Gtk.Button(label="Reset")
        reset.set_tooltip_text("Forget the changes not yet applied")
        reset.connect("clicked", lambda _b: self.reload())
        close = Gtk.Button(label="Close")
        close.connect("clicked", lambda _b: self.close())
        apply = Gtk.Button(label="Apply")
        apply.get_style_context().add_class("suggested-action")
        apply.connect("clicked", self.on_apply)
        for b in (reset, close, apply):
            buttons.pack_start(b, False, False, 0)
        box.pack_start(buttons, False, False, 0)

        self.updating = False
        self.watch_outputs()
        self.show_selected()

    def on_key(self, _window, event) -> bool:
        if event.keyval == Gdk.KEY_Escape:
            self.close()
            return True
        return False

    # The displays as sway has them

    def reload(self) -> None:
        self.displays, self.primary = load()
        if self.selected not in [d.name for d in self.displays]:
            self.selected = self.primary or (self.displays[0].name if self.displays else "")
        self.show_selected()
        self.canvas.queue_draw()
        return False

    def watch_outputs(self) -> None:
        """Reload when a display is plugged in or out (or after Apply)."""
        try:
            self.events = subprocess.Popen(
                ["swaymsg", "-r", "-t", "subscribe", "-m", '["output"]'],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        except OSError:
            return
        self.reload_pending = None

        def on_event(source, condition):
            if condition & GLib.IO_HUP or not self.events.stdout.readline():
                return False
            if self.reload_pending:
                GLib.source_remove(self.reload_pending)
            self.reload_pending = GLib.timeout_add(300, self.on_reload_timer)
            return True

        GLib.io_add_watch(self.events.stdout, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP, on_event)
        self.connect("destroy", lambda _w: self.events.terminate())

    def on_reload_timer(self):
        self.reload_pending = None
        return self.reload()

    def find(self, name: str):
        return next((d for d in self.displays if d.name == name), None)

    def on(self) -> list:
        return [d for d in self.displays if d.enabled]

    # The form below the canvas, for the selected display

    def show_selected(self) -> None:
        d = self.find(self.selected)
        self.updating = True
        self.resolution.remove_all()
        if d:
            title = f" · {d.title}" if d.title else ""
            self.heading.set_markup(f"<b>Display {d.number}</b>  {GLib.markup_escape_text(d.name + title)}")
            self.enabled.set_active(d.enabled)
            # The primary display stays on: something has to hold the bar.
            self.enabled.set_sensitive(d.name != self.primary)
            for m in d.modes or [{"id": d.mode, "label": d.mode}]:
                self.resolution.append(m["id"], m["label"])
            self.resolution.set_active_id(d.mode)
            self.resolution.set_sensitive(d.enabled)
            self.make_primary.set_active(d.name == self.primary)
            self.make_primary.set_sensitive(d.enabled and d.name != self.primary)
            self.position.set_text(f"{int(d.x)}, {int(d.y)}" if d.enabled else "off")
        else:
            self.heading.set_text("No displays found")
        self.updating = False

    def on_enabled(self, switch, _param) -> None:
        d = self.find(self.selected)
        if self.updating or not d or d.enabled == switch.get_active():
            return
        d.enabled = switch.get_active()
        if d.enabled:
            # Back on: to the right of the others, along their top.
            others = [o for o in self.on() if o is not d]
            d.x = max((o.x + o.size[0] for o in others), default=0)
            d.y = min((o.y for o in others), default=0)
        self.settle()
        self.changed()

    def on_resolution(self, combo) -> None:
        d = self.find(self.selected)
        mode = combo.get_active_id()
        if self.updating or not d or not mode or mode == d.mode:
            return
        (ow, oh), d.mode = d.size, mode
        dw, dh = d.size[0] - ow, d.size[1] - oh
        # Keep the arrangement: displays right of or below this one move with
        # its new edge.
        for o in self.on():
            if o is d:
                continue
            if o.x >= d.x + ow:
                o.x += dw
            if o.y >= d.y + oh:
                o.y += dh
        self.settle()
        self.changed()

    def on_primary(self, check) -> None:
        if self.updating or not check.get_active():
            return
        self.primary = self.selected
        self.changed()

    def changed(self) -> None:
        self.show_selected()
        self.canvas.queue_draw()

    # Layout

    def settle(self) -> None:
        """Move any display that overlaps another, or touches none, beside the
        rest; then shift everything so the layout starts at 0,0."""
        placed = []
        for d in sorted(self.on(), key=lambda d: (d.x, d.y)):
            if misplaced(d, placed):
                snap(d, placed, 0)
            placed.append(d)
        self.normalize()

    def normalize(self) -> None:
        on = self.on()
        if not on:
            return
        mx, my = min(d.x for d in on), min(d.y for d in on)
        for d in on:
            d.x, d.y = int(d.x - mx), int(d.y - my)

    def fit(self, width: int, height: int) -> tuple:
        """Scale and offset that fit the whole layout on the canvas."""
        on = self.on()
        if not on:
            return 1.0, 0.0, 0.0
        x0 = min(d.x for d in on)
        y0 = min(d.y for d in on)
        x1 = max(d.x + d.size[0] for d in on)
        y1 = max(d.y + d.size[1] for d in on)
        pad = 24
        scale = min((width - 2 * pad) / max(x1 - x0, 1), (height - 2 * pad) / max(y1 - y0, 1))
        return scale, (width - (x1 - x0) * scale) / 2 - x0 * scale, (height - (y1 - y0) * scale) / 2 - y0 * scale

    def on_draw(self, widget, cr) -> None:
        width, height = widget.get_allocated_width(), widget.get_allocated_height()
        cr.set_source_rgb(*rgb("bg"))
        cr.paint()
        if not self.drag:
            self.view = self.fit(width, height)
        scale, ox, oy = self.view
        for d in sorted(self.on(), key=lambda d: d.name == self.selected):
            w, h = d.size
            x, y = ox + d.x * scale, oy + d.y * scale
            cr.rectangle(x + 2, y + 2, w * scale - 4, h * scale - 4)
            cr.set_source_rgb(*rgb("surface"))
            cr.fill_preserve()
            cr.set_line_width(3 if d.name == self.selected else 1)
            cr.set_source_rgb(*rgb("cyan" if d.name == self.selected else "muted"))
            cr.stroke()

            cr.set_source_rgb(*rgb("pink" if d.name == self.primary else "fg"))
            cr.select_font_face("monospace")
            cr.set_font_size(max(min(h * scale / 3, 40), 12))
            label = str(d.number) + (" ★" if d.name == self.primary else "")
            ext = cr.text_extents(label)
            cr.move_to(x + (w * scale - ext.width) / 2 - ext.x_bearing, y + h * scale / 2 - 4)
            cr.show_text(label)
            cr.set_font_size(11)
            cr.set_source_rgba(*rgb("fg"), 0.7)
            for i, line in enumerate((d.name, d.mode.split("@")[0])):
                ext = cr.text_extents(line)
                cr.move_to(x + (w * scale - ext.width) / 2 - ext.x_bearing, y + h * scale / 2 + 16 + 14 * i)
                cr.show_text(line)

    def hit(self, px: float, py: float):
        scale, ox, oy = self.view
        for d in sorted(self.on(), key=lambda d: d.name != self.selected):
            w, h = d.size
            if ox + d.x * scale <= px <= ox + (d.x + w) * scale and oy + d.y * scale <= py <= oy + (d.y + h) * scale:
                return d
        return None

    def on_press(self, _widget, event) -> None:
        d = self.hit(event.x, event.y)
        if not d:
            return
        self.selected = d.name
        self.drag = (d, event.x, event.y, d.x, d.y)
        self.changed()

    def on_motion(self, _widget, event) -> None:
        if not self.drag:
            return
        d, px, py, x, y = self.drag
        scale = self.view[0]
        d.x, d.y = x + (event.x - px) / scale, y + (event.y - py) / scale
        self.canvas.queue_draw()

    def on_release(self, _widget, _event) -> None:
        if not self.drag:
            return
        d, _px, _py, x, y = self.drag
        self.drag = None
        others = [o for o in self.on() if o is not d]
        snap(d, others, SNAP_PX / self.view[0])
        if misplaced(d, others):
            # Nowhere to put it: back where it was.
            d.x, d.y = x, y
        d.x, d.y = round(d.x), round(d.y)
        self.normalize()
        self.changed()

    # Apply, and undo it unless kept

    def on_apply(self, _button) -> None:
        before_displays, before_primary = load()
        before = {"primary": before_primary, "outputs": {d.name: d.setting() for d in before_displays}}
        wanted = {"primary": self.primary, "outputs": {d.name: d.setting() for d in self.displays}}
        risky = any(
            d.enabled != b.enabled or (d.enabled and d.mode != b.mode)
            for d in self.displays for b in before_displays if b.name == d.name)
        run("eww-display", "apply", json.dumps(wanted))
        if risky:
            self.confirm(before)

    def confirm(self, before: dict) -> None:
        dialog = Gtk.MessageDialog(
            transient_for=self, modal=True, message_type=Gtk.MessageType.QUESTION,
            text="Keep these display settings?")
        dialog.add_buttons("Revert", Gtk.ResponseType.REJECT, "Keep", Gtk.ResponseType.ACCEPT)
        dialog.set_default_response(Gtk.ResponseType.REJECT)
        left = [KEEP_SECONDS]

        def tick():
            left[0] -= 1
            if left[0] <= 0:
                dialog.response(Gtk.ResponseType.REJECT)
                return False
            dialog.format_secondary_text(f"Reverting in {left[0]} seconds.")
            return True

        dialog.format_secondary_text(f"Reverting in {KEEP_SECONDS} seconds.")
        timer = GLib.timeout_add_seconds(1, tick)
        response = dialog.run()
        if left[0] > 0:
            GLib.source_remove(timer)
        dialog.destroy()
        if response != Gtk.ResponseType.ACCEPT:
            run("eww-display", "apply", json.dumps(before))
        self.reload()


def close_open_window() -> bool:
    try:
        return json.loads(run("swaymsg", "-r", f'[app_id="{APP_ID}"] kill'))[0]["success"]
    except (ValueError, IndexError, KeyError, TypeError):
        return False


def main(args: list) -> None:
    if "--toggle" in args and close_open_window():
        return
    # Sway's app_id for the window (home/sway.nix floats it), and what
    # --toggle looks for.
    GLib.set_prgname(APP_ID)
    app = Gtk.Application(application_id=APP_ID)

    def activate(app):
        # A second launch brings the open window forward instead.
        if app.get_windows():
            app.get_windows()[0].present()
        else:
            Window(app).show_all()

    app.connect("activate", activate)
    app.run([sys.argv[0]])


if __name__ == "__main__":
    main(sys.argv[1:])
