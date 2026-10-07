---
name: blender-mcp
description: How to model, texture and export game assets through the blender MCP server and get them into Godot. Load before the first blender tool call or any task that makes or imports a 3D asset.
---

# The `blender` MCP server

The server talks to the MCP for Blender add-on in the open Blender on this
machine (it's installed and enabled; Blender must just be open). Blender
runs in a Flatpak sandbox that only sees `~/Projects`: read and write files
only under it.

## Every session

1. Inspect first: the scene-info and object-info tools tell you what's
   there. Take a viewport screenshot when shape or look matters.
2. Save the .blend before running code (`bpy.ops.wm.save_mainfile()`), so
   a bad script can be undone by reopening.
3. Prefer small `execute_blender_code` calls, one step each, and check the
   result after each. Print what you need back (`print(obj.dimensions)`).

## Modelling for Godot

- Units: metres. 1 Blender unit = 1 Godot unit. Check `obj.dimensions`
  against the task.
- Origin at the base centre of props and characters (so they stand on the
  floor), at the pivot for doors and wheels.
- Apply transforms before export (`bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)`).
- Stay under the triangle budget in ART.md; check with the mesh's polygon
  count after triangulation.
- Materials: Principled BSDF only (it maps to Godot's StandardMaterial3D);
  colours from ART.md's palette (hex to linear RGB for Blender).
- Names become node names in Godot. Godot import hints as name suffixes:
  `-col` (mesh plus trimesh collision), `-convcol` (convex collision),
  `-colonly` (collision only), `-noimp` (skip), `-loop` on animation names.
- One asset per .blend under `~/Projects/<game>/art/`, exported to the
  project's `assets/models/` folder.

## Export

glTF binary, from the asset's collection or selection:

```python
bpy.ops.export_scene.gltf(
    filepath="/home/<user>/Projects/<game>/assets/models/crate.glb",
    export_format="GLB", use_selection=True, export_apply=True,
)
```

Then in Godot: `filesystem_manage` `scan` (or `reimport`) and check the
import in the editor. Add the asset to `ASSETS.md`.

## Ready-made assets

Poly Haven (models, textures, HDRIs; CC0) and Poly Pizza (low-poly models;
each model's own licence, often CC-BY: credit it in ASSETS.md) are
available through Blender add-ons and the server's asset tools. Downloads
land in `~/Projects/Assets`. Prefer one that fits ART.md over modelling from
scratch.
