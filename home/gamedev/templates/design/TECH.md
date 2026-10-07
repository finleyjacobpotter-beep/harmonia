# Technical design

## Engine

- Godot version:
- Renderer (Forward+, Mobile, Compatibility):
- 2D or 3D:
- Main scene:

## Folders

```
res://
  autoload/      singletons
  data/          .tres resources holding tunable numbers
  levels/        one scene per level, plus test_level.tscn
  player/
  enemies/
  ui/
  assets/models/ .glb exports from Blender (art/ holds the .blend sources)
  assets/textures/
  assets/audio/
  tests/
```

## Autoloads

| Name | Script | Responsibility | Public API (signals, functions) |
| --- | --- | --- | --- |

## Scenes

<!-- Each main scene: root node type, its children (name: Type), the script, exported properties. -->

## Input map

| Action | Events |
| --- | --- |

## Physics layers

| Layer | Name | Who is on it | Who scans it |
| --- | --- | --- | --- |

## Signals between scenes

| Signal(args) | Emitted by | Listened to by |
| --- | --- | --- |

## Saving

## Conventions

- Typed GDScript, Godot 4 syntax only (the godot-4 skill).
- Tunable numbers in res://data/*.tres, never literals in code.
- One task, one commit, task id in the message.
