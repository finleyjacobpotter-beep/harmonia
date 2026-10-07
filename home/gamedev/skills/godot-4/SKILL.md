---
name: godot-4
description: Godot 4 GDScript reference and the Godot 3 habits to avoid. Load before writing or reviewing any GDScript, scene or project setting.
---

# Godot 4 GDScript

The editor here is Godot 4.7 or newer. Much code online (and in your
training) is Godot 3, which no longer parses or behaves differently. When
unsure of a class, check it with the `godot` server (`api_manage`
`get_class`) instead of guessing.

## Godot 3 → Godot 4

| Godot 3 (wrong here) | Godot 4 |
| --- | --- |
| `export var speed = 5` | `@export var speed: float = 5.0` |
| `onready var x = $X` | `@onready var x: Node3D = $X` |
| `tool` | `@tool` (first line) |
| `export(int, 0, 10) var n` | `@export_range(0, 10) var n: int` |
| `var x setget set_x, get_x` | `var x: int: set = set_x, get = get_x`, or `set(value):` blocks |
| `yield(get_tree().create_timer(1), "timeout")` | `await get_tree().create_timer(1.0).timeout` |
| `connect("body_entered", self, "_on_body_entered")` | `body_entered.connect(_on_body_entered)` |
| `emit_signal("hit", 3)` | `hit.emit(3)` |
| `scene.instance()` | `scene.instantiate()` |
| `KinematicBody`, `KinematicBody2D` | `CharacterBody3D`, `CharacterBody2D` |
| `move_and_slide(velocity, Vector3.UP)` | set the `velocity` property, then `move_and_slide()` (no arguments) |
| `Spatial`, `translation` | `Node3D`, `position` |
| `Position3D`, `Position2D` | `Marker3D`, `Marker2D` |
| `Particles`, `Particles2D` | `GPUParticles3D`, `GPUParticles2D` |
| `VisibilityNotifier` | `VisibleOnScreenNotifier3D` |
| `RigidBody.mode = MODE_STATIC` | `freeze = true` (+ `freeze_mode`) |
| `TileMap` with layers | `TileMapLayer`, one node per layer |
| `Tween` node, `interpolate_property` | `var t := create_tween()`, `t.tween_property(node, "position", target, 0.5)` |
| `get_tree().change_scene("res://x.tscn")` | `get_tree().change_scene_to_file("res://x.tscn")` |
| `File`, `Directory` | `FileAccess.open(path, FileAccess.READ)`, `DirAccess` |
| `JSON.parse(text).result` | `JSON.parse_string(text)` |
| `str2var`, `var2str`, `deg2rad`, `rad2deg` | `str_to_var`, `var_to_str`, `deg_to_rad`, `rad_to_deg` |
| `rand_range`, `stepify` | `randf_range`, `snapped` |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` |
| `array.empty()`, `PoolStringArray` | `array.is_empty()`, `PackedStringArray` |
| `BUTTON_LEFT` | `MOUSE_BUTTON_LEFT` |
| `get_node("../X")` everywhere | `%UniqueName` for nodes marked unique in the scene |

## Conventions

- Typed GDScript everywhere: typed variables, parameters and return values;
  `:=` for inferred types.
- `class_name` for reusable scripts; file names `snake_case.gd`, classes
  `PascalCase`, signals past tense (`died`, `item_picked_up`).
- Movement and physics in `_physics_process(delta)`; input actions from the
  input map (`Input.is_action_just_pressed("jump")`,
  `Input.get_vector("move_left", "move_right", "move_forward", "move_back")`),
  never raw key codes.
- Gravity: `ProjectSettings.get_setting("physics/3d/default_gravity")`.
- Tunable numbers in a `Resource` (`class_name PlayerStats extends Resource`
  with `@export` fields, saved as `.tres` under `res://data/`), not literals.
- Cross-scene communication through signals or an autoload event bus named
  in TECH.md; no `get_parent().get_parent()` chains.
- Scenes own their children; instance scenes with
  `preload("res://...tscn").instantiate()` and `add_child()`.
- Commit `.uid` files and `.import` files; never commit `.godot/`.

## Common errors

- `Invalid call. Nonexistent function 'move_and_slide' with arguments` or
  `Too many arguments`: Godot 3 call, see the table.
- `Identifier "x" not declared in the current scope` after `onready`: use
  `@onready`.
- `Node not found` at startup: the path changed in the scene, or the node
  is accessed before `_ready()`. Prefer `%UniqueName` or `@onready`.
- A scene's root node type must match the `extends` of its script.
