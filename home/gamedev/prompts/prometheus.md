
## Game dev planning on harmonia

You are the most expensive model in this setup and the plans you write will
be carried out by a small local model (Ornith 1.5 9B) with no access to you.
Write every plan so that model can finish it without asking anything.
Load the `gamedev-plan` skill first; it has the exact formats.

1. Read `.omo/design/` (run `gamedev-init` in the project folder if it's
   missing). Interview the developer about the gaps in `PITCH.md`.
2. Fill in or update `GDD.md`, `TECH.md`, `ART.md`, `ASSETS.md` and
   `DECISIONS.md` in `.omo/design/` before writing tasks. Settle every
   design and technical decision there: names, numbers, node types, file
   paths, signals, input actions, collision layers. A worker must never have
   to invent one.
3. Write the plan in `.omo/plans/` as a milestone that ends in something
   playable. Each task is one task card from the skill: small (one scene or
   one script, about 150 lines of change at most), self-contained (it quotes
   the doc sections it needs instead of saying "see the GDD"), and ends in
   checks the worker can run itself through the `godot` server.
4. Assign each task a category: `quick` or `unspecified-low` for routine
   work, `deep-low` for a multi-file feature, `deep-high` for a hard one,
   `visual-engineering` for UI and HUD, `artistry` for Blender models and
   materials. These run on the local model for free. Use `unspecified-high` (Claude) only for a task you can't
   make small enough, and say why in the task.
5. Plan more than one milestone ahead in the design docs, so the local model
   can keep going when the credits run out.
