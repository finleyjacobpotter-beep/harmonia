---
name: gamedev-plan
description: Formats for game design docs and task cards in .omo/design and .omo/plans, written so a small local model can carry out each task alone. Use when planning, reviewing or splitting game dev work.
---

# Planning a game for a small local model

The plan is executed by Ornith 1.5 9B, a local model with a large context
but limited judgement. It follows precise instructions well and fills gaps
badly. Every decision belongs in the docs or the task card, never in the
worker's head.

## Design docs (`.omo/design/`)

`gamedev-init` creates them from templates; keep their headings.

- **GDD.md**: the core loop in one paragraph, then each mechanic with its
  numbers (speeds in m/s or px/s, damage, timers in seconds, ranges), the
  controls table (action name, keys, gamepad), win/lose conditions and the
  level list. Numbers live here and nowhere else; code reads them from the
  `res://data/` resources TECH.md names.
- **TECH.md**: Godot version and renderer (Forward+, Mobile or
  Compatibility), 2D or 3D, the folder layout, the main scene, every
  autoload with its responsibility and public API, the input map, collision
  layers and masks by number and name, groups, signals that cross scenes
  (name, arguments, emitter, listeners), the save format and the coding
  conventions (typed GDScript, naming).
- **ART.md**: the look in a few sentences plus reference adjectives, the
  palette as hex codes, scale (1 Blender unit = 1 m = 1 Godot unit),
  triangle and texture budgets per asset type, naming, and the Blender to
  Godot export rules from the `blender-mcp` skill.
- **ASSETS.md**: one row per asset: id, `res://` path, its reference (a
  Poly Haven or Poly Pizza asset with URL, or a description with real
  dimensions, parts and colours), made in Blender or sourced, license,
  animations, status.
- **DECISIONS.md**: `YYYY-MM-DD: decision. Why.` one per line.
- **LESSONS.md**: `- pitfall: what to do instead` one per line.

## Plans (`.omo/plans/<milestone>.md`)

A milestone is a set of tasks that ends in something you can play.
Start the file with the milestone goal, what is in and out of scope, and
the docs every task relies on. Then the tasks, grouped into waves (below), each as
a checkbox followed by its card:

```markdown
- [ ] T07 Player can jump (category: quick)

  **Why**: GDD §Movement: the player jumps over 1 m gaps.
  **Files**: res://player/player.gd (edit), res://data/player_stats.tres (edit)
  **Depends on**: T05
  **Context** (quoted from the docs, so the worker needn't look):
  - Input action `jump`: Space, gamepad A (TECH §Input map).
  - `jump_velocity` 4.5 m/s, gravity from project settings (GDD §Movement).
  - Player is a CharacterBody3D; movement in `_physics_process` (TECH §Player).
  **Steps**:
  1. Add `@export var jump_velocity: float = 4.5` to player_stats.gd ...
  2. In `_physics_process`, when `is_on_floor()` and
     `Input.is_action_just_pressed("jump")`, set `velocity.y = stats.jump_velocity`.
  3. ...
  **Checks** (run them; the task is done when all pass):
  - `script_create`/`script_patch` diagnostics show no errors.
  - Run res://levels/test_level.tscn, send the `jump` action with
    `game_manage` `input_action`, read the game log: no new errors, and
    `player.global_position.y` rises above 0.8 within 0.5 s.
  - Screenshot of the game shows the player mid-jump.
  **Don't**: change walking speed or the camera.
```

Rules for cards:

- One scene or one script per task where possible; about 150 changed
  lines at most. Split bigger work.
- Exact names everywhere: files (`res://...`), nodes and their types,
  properties, signals with arguments, input actions, groups, layers.
- Godot 4 APIs only, named exactly (CharacterBody3D, `@export`,
  `signal.connect(callable)`); when an API is unusual, give the call.
- Quote the doc lines the task needs under **Context**.
- Every task ends in checks the worker runs itself through the `godot`
  server: script diagnostics, a run with `project_run` plus `logs_read`,
  scripted input with `game_manage`, `editor_screenshot` for visuals, or a
  `test_run` suite when the project has tests.
- Blender tasks name the object, its dimensions in metres, triangle budget,
  material colours as hex, and the exact export path under the project.
- Categories only steer the worker's prompt; every one runs on the local
  model. `quick` or `unspecified-low` for routine work, `deep-low` for a
  multi-file feature, `deep-high` for a hard one, `visual-engineering` for
  UI and HUD, `artistry` for Blender models and materials, `writing` for
  docs. There is no stronger model to fall back on: split hard tasks.

## Waves

`/ulw-execute` runs up to four workers at once. Group the tasks under
`## Wave 1`, `## Wave 2`, ... headings: every task in a wave depends only
on earlier waves, and no two tasks in a wave touch the same file, scene or
.blend. Put shared foundations (project settings, input map, autoloads,
data resources) in the first wave, one task each.

The last wave is a single task for the finisher: list what the developer
should playtest and anything you expect to need a human eye.

## Before handing over

Re-read each card as the worker would, with nothing but the card,
`AGENTS.md` and `.omo/design/`. If you'd have to guess anything, the card
isn't finished.
