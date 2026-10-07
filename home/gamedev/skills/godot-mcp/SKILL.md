---
name: godot-mcp
description: How to drive the open Godot editor through the godot MCP server (godot-ai): inspecting scenes, editing nodes and scripts, running the game, reading errors, sending input and taking screenshots. Load before the first godot tool call.
---

# The `godot` MCP server

The server is godot-ai, talking to the Godot AI plugin in the open editor
on this machine. The editor must be open with the project loaded and the
plugin enabled (Project → Project Settings → Plugins). Tool names below are
godot-ai's; the list opencode shows is authoritative if they differ.

## Start every session

1. `editor_state`: editor version, project, open scene, play state. If it
   fails, ask the developer to open the project in Godot; don't continue.
2. `scene_get_hierarchy` on the scene you'll touch (use `depth` and
   `limit`; it's paginated).

## Editing

- Nodes: `node_create`, `node_set_property`, `node_find`,
  `node_get_properties`, and `node_manage` (`delete`, `rename`, `move`,
  `reparent`, `duplicate`, `add_to_group`).
- Several related edits: `batch_execute`, which rolls back on the first
  error.
- Scripts: `script_create`, `script_attach`, `script_patch` (anchor-based
  edits) and `script_manage` `read`. Every write returns `diagnostics`:
  fix parse errors before doing anything else.
- Save with `scene_save` after editing a scene.
- Also: `signal_manage` (`connect`), `input_map_manage` (`ensure_action`,
  `ensure_binding`), `autoload_manage`, `material_manage`,
  `animation_create` / `animation_manage`, `camera_manage`,
  `particle_manage`, `ui_manage`, `theme_manage`, `tilemap_manage`,
  `resource_manage`, `filesystem_manage` (`scan` and `reimport` after
  adding files from outside, such as a Blender export).
- Look up an engine class: `api_manage` `get_class`.

## Verifying

1. `project_run` (the whole game, or a test scene). Its `game_status` is
   `live` when running; `break` means a parse or load error stopped it.
2. `logs_read` for the game and editor logs; anything new since your change
   is yours to fix. The response also counts new errors and warnings.
3. Drive the game: `game_manage` `input_action` for one action,
   `input_sequence` for frame-timed steps, `get_scene_tree` and
   `get_node_info` to read live state.
4. `editor_screenshot` of the game framebuffer or a viewport for anything
   visual, and look at it.
5. `project_manage` `stop` when done.
6. If the project has test suites, `test_run` and `test_manage`
   `results_get`.

## Don't

- Don't edit `.tscn` files as text while the scene is open in the editor;
  use the tools, or close the scene first.
- Don't leave the game running between tasks.
- Don't use `editor_manage` `quit` or `game_eval` unless the task says so.
