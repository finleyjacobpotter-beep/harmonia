# Poly Pizza for Blender: search poly.pizza's free low-poly models and import
# them, from a "Poly Pizza" tab in the 3D view's sidebar. Poly Pizza has no
# Blender add-on of its own, so harmonia ships this one (home/blender-addons.nix).
#
# The API needs a free key from https://poly.pizza/settings/api, set in the
# add-on's preferences. Models are glTF binaries; each import is cached in the
# download folder and its credit line is added to the "Poly Pizza credits" text.

import json
import os
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

import bpy
import bpy.utils.previews
from bpy.props import (
    CollectionProperty,
    IntProperty,
    PointerProperty,
    StringProperty,
)

bl_info = {
    "name": "Poly Pizza",
    "author": "harmonia",
    "version": (1, 0, 0),
    "blender": (4, 2, 0),
    "location": "3D Viewport > Sidebar > Poly Pizza",
    "description": "Search and import free low-poly models from poly.pizza",
    "doc_url": "https://poly.pizza/docs/api",
    "category": "Import-Export",
}

API = "https://api.poly.pizza/v1.1"
PAGE_SIZE = 32
USER_AGENT = "harmonia-poly-pizza/1.0 (Blender)"
CREDITS = "Poly Pizza credits"

previews = None


def prefs(context):
    return context.preferences.addons[__name__].preferences


def download_dir(context):
    path = bpy.path.abspath(prefs(context).download_dir)
    os.makedirs(path, exist_ok=True)
    return path


def get(url, key=None):
    headers = {"User-Agent": USER_AGENT}
    if key:
        headers["X-Auth-Token"] = key
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as res:
        return res.read()


def fetch(url, path):
    if not os.path.exists(path):
        data = get(url)
        with open(path + ".part", "wb") as f:
            f.write(data)
        os.replace(path + ".part", path)
    return path


class PolyPizzaPreferences(bpy.types.AddonPreferences):
    bl_idname = __name__

    api_key: StringProperty(
        name="API key",
        description="Free key from poly.pizza/settings/api",
        subtype="PASSWORD",
    )
    download_dir: StringProperty(
        name="Download folder",
        description="Where imported models (and thumbnails) are kept",
        subtype="DIR_PATH",
        default=os.path.expanduser("~/Projects/Assets/Poly Pizza"),
    )

    def draw(self, context):
        self.layout.prop(self, "api_key")
        self.layout.prop(self, "download_dir")
        self.layout.operator("wm.url_open", text="Get a free API key", icon="URL").url = (
            "https://poly.pizza/settings/api"
        )


class PolyPizzaModel(bpy.types.PropertyGroup):
    model_id: StringProperty()
    title: StringProperty()
    creator: StringProperty()
    licence: StringProperty()
    attribution: StringProperty()
    download: StringProperty()
    thumbnail: StringProperty()


class PolyPizzaState(bpy.types.PropertyGroup):
    query: StringProperty(name="Search", description="What to search poly.pizza for")
    searched: StringProperty()
    page: IntProperty(default=0)
    total: IntProperty(default=0)
    results: CollectionProperty(type=PolyPizzaModel)
    index: IntProperty(default=0)


class POLYPIZZA_OT_search(bpy.types.Operator):
    bl_idname = "polypizza.search"
    bl_label = "Search Poly Pizza"
    bl_description = "Search poly.pizza for free models"

    page: IntProperty(default=0, options={"SKIP_SAVE"})

    def execute(self, context):
        state = context.window_manager.polypizza
        key = prefs(context).api_key
        query = state.query.strip() if self.page == 0 else state.searched
        if not key:
            self.report({"ERROR"}, "Set a Poly Pizza API key in the add-on's preferences")
            return {"CANCELLED"}
        if not query:
            return {"CANCELLED"}

        url = f"{API}/search/{urllib.parse.quote(query)}?" + urllib.parse.urlencode(
            {"limit": PAGE_SIZE, "page": self.page}
        )
        try:
            found = json.loads(get(url, key))
        except Exception as e:
            self.report({"ERROR"}, f"Poly Pizza search failed: {e}")
            return {"CANCELLED"}

        state.results.clear()
        state.searched, state.page, state.index = query, self.page, 0
        state.total = found.get("total", 0)
        for m in found.get("results", []):
            item = state.results.add()
            item.model_id = m.get("ID", "")
            item.title = m.get("Title", "") or item.model_id
            item.creator = (m.get("Creator") or {}).get("Username", "")
            item.licence = m.get("Licence", "")
            item.attribution = m.get("Attribution", "")
            item.download = m.get("Download", "")
            item.thumbnail = m.get("Thumbnail", "")
        load_thumbnails(context, state.results)
        return {"FINISHED"}


def load_thumbnails(context, results):
    folder = os.path.join(download_dir(context), ".thumbnails")
    os.makedirs(folder, exist_ok=True)
    wanted = {}
    for r in results:
        if r.thumbnail and r.model_id not in previews:
            ext = os.path.splitext(urllib.parse.urlparse(r.thumbnail).path)[1]
            wanted[r.model_id] = (r.thumbnail, os.path.join(folder, r.model_id + ext))

    def one(item):
        try:
            return item[0], fetch(*item[1])
        except Exception:
            return item[0], None

    with ThreadPoolExecutor(8) as pool:
        for model_id, path in pool.map(one, wanted.items()):
            if path:
                previews.load(model_id, path, "IMAGE")


class POLYPIZZA_OT_import(bpy.types.Operator):
    bl_idname = "polypizza.import_model"
    bl_label = "Import"
    bl_description = "Download the selected model and import it at the 3D cursor"
    bl_options = {"REGISTER", "UNDO"}

    @classmethod
    def poll(cls, context):
        state = context.window_manager.polypizza
        return 0 <= state.index < len(state.results)

    def execute(self, context):
        model = context.window_manager.polypizza.results[context.window_manager.polypizza.index]
        path = os.path.join(download_dir(context), f"{model.model_id}.glb")
        try:
            fetch(model.download, path)
        except Exception as e:
            self.report({"ERROR"}, f"Download failed: {e}")
            return {"CANCELLED"}

        if context.mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.import_scene.gltf(filepath=path)
        imported = context.selected_objects
        for obj in imported:
            obj["poly_pizza_id"] = model.model_id
            obj["poly_pizza_attribution"] = model.attribution
        roots = [o for o in imported if o.parent not in imported]
        if len(roots) == 1:
            roots[0].name = model.title
        for obj in roots:
            obj.location = context.scene.cursor.location

        credits = bpy.data.texts.get(CREDITS) or bpy.data.texts.new(CREDITS)
        line = model.attribution or f"{model.title} by {model.creator} ({model.licence})"
        if line not in credits.as_string():
            credits.write(line + "\n")
        self.report({"INFO"}, f"Imported {model.title} ({model.licence})")
        return {"FINISHED"}


class POLYPIZZA_UL_results(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname):
        preview = previews.get(item.model_id)
        layout.label(text=item.title, icon_value=preview.icon_id if preview else 0)


class POLYPIZZA_PT_panel(bpy.types.Panel):
    bl_label = "Poly Pizza"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Poly Pizza"

    def draw(self, context):
        layout = self.layout
        state = context.window_manager.polypizza

        if not prefs(context).api_key:
            layout.label(text="Needs a free API key", icon="ERROR")
            layout.operator("wm.url_open", text="Get one", icon="URL").url = "https://poly.pizza/settings/api"
            layout.operator("preferences.addon_show", text="Set it", icon="PREFERENCES").module = __name__
            return

        row = layout.row(align=True)
        row.prop(state, "query", text="", icon="VIEWZOOM")
        row.operator("polypizza.search", text="", icon="FORWARD").page = 0
        if not state.results:
            return

        layout.template_list("POLYPIZZA_UL_results", "", state, "results", state, "index", rows=6)
        pages = max(1, -(-state.total // PAGE_SIZE))
        row = layout.row(align=True)
        prev = row.row(align=True)
        prev.enabled = state.page > 0
        prev.operator("polypizza.search", text="", icon="TRIA_LEFT").page = state.page - 1
        row.label(text=f"Page {state.page + 1} of {pages}")
        nxt = row.row(align=True)
        nxt.enabled = state.page + 1 < pages
        nxt.operator("polypizza.search", text="", icon="TRIA_RIGHT").page = state.page + 1

        if 0 <= state.index < len(state.results):
            model = state.results[state.index]
            preview = previews.get(model.model_id)
            box = layout.box()
            if preview:
                box.template_icon(icon_value=preview.icon_id, scale=8)
            box.label(text=model.title)
            box.label(text=f"by {model.creator}", icon="USER")
            box.label(text=model.licence, icon="INFO")
            box.operator("polypizza.import_model", icon="IMPORT")


classes = (
    PolyPizzaPreferences,
    PolyPizzaModel,
    PolyPizzaState,
    POLYPIZZA_OT_search,
    POLYPIZZA_OT_import,
    POLYPIZZA_UL_results,
    POLYPIZZA_PT_panel,
)


def register():
    global previews
    previews = bpy.utils.previews.new()
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.WindowManager.polypizza = PointerProperty(type=PolyPizzaState)


def unregister():
    global previews
    del bpy.types.WindowManager.polypizza
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
    bpy.utils.previews.remove(previews)
    previews = None
