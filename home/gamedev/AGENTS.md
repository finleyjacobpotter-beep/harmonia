# Game dev on harmonia

You are working on a game in `~/Projects/<game>` with Godot 4 (4.7 or newer)
and Blender, both open on this machine and reachable through the `godot` and
`blender` MCP servers. `~/Projects` is the folder the editors work in, so
every file they open or write must live under it.

## Who does what

The planner (Prometheus, with Metis and Momus checking) writes the design
docs and an ultrawork plan, and the finisher reviews, simplifies and
completes the work before the developer sees it. Everything in between runs
on the local model, Ornith 1.5 9B (served as `ai` on this machine), up to
four agents at once; in opencode the planner and finisher do too. The plan
is all the guidance the workers get: follow it exactly.

Besides Godot and Blender, the `radare2` MCP server analyses binaries
(open a file with an absolute path first).

## The design docs are the source of truth

Each game keeps its design in `.omo/design/` and its work plans in
`.omo/plans/`:

| File | Holds |
| --- | --- |
| `PITCH.md` | the idea, in the developer's words |
| `GDD.md` | game design: loop, mechanics, controls, levels, numbers |
| `TECH.md` | Godot version, folders, scene tree, autoloads, input map, conventions |
| `ART.md` | look, palette, poly and texture budgets, the Blender to Godot pipeline |
| `ASSETS.md` | every asset: path, source, license, status |
| `DECISIONS.md` | decisions with their reasons, newest last |
| `LESSONS.md` | mistakes found and how to avoid them |
| `../reviews/` | the finisher's report for each milestone |

Read the docs that touch your task before you change anything. When the
code and the docs disagree, the docs win unless the developer says
otherwise; record any change of plan in `DECISIONS.md`. When you hit a
mistake worth not repeating (a wrong API, a crash and its fix), add one
line to `LESSONS.md`.

## Working rules

- Godot 4 only. Many examples online are Godot 3; load the `godot-4` skill
  before writing GDScript and check any API you're unsure of with the
  `godot` server's class lookup.
- Use the `godot` and `blender` MCP servers for scenes, nodes, materials and
  models; plain files for scripts and docs are fine too. Load the
  `godot-mcp` or `blender-mcp` skill before your first call.
- Verify every change in the engine: run the scene, read the logs for new
  errors, and take a screenshot when the change is visual. A task isn't done
  until it runs without new errors.
- Small steps: one task, one commit, with the task's id in the message.
