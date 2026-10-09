# Game dev

On harmonia (the desktop; not Cadmus), [omo](omo.md) and Claude Code can
drive Godot and Blender over MCP, and analyse binaries with radare2. Neither
gets game dev rules globally: each game carries its own context, which
`gamedev-init` starts for you. It's all in
[`home/gamedev.nix`](../home/gamedev.nix) and [`home/gamedev/`](../home/gamedev).

## Set up once

1. **The model**: omo runs everything on the local model. Click the robot
   icon on the bar, then **Start**. The first start
   downloads the image and the model (~6 GB); it's ready when the icon
   turns pink ([llama-server.md](llama-server.md)).
2. **Blender and Godot**: open them. The Blender MCP add-on is already
   enabled; in each Godot project install and enable the Godot AI 4.3.0
   plugin ([omo.md](omo.md#mcp-servers)). The `godot-ai` service already
   runs on harmonia.
3. The first time an agent starts the Blender and Godot MCP servers, uv
   downloads them, so it needs the internet once.

## MCP servers

omo and Claude Code both get:

| Server | What it does |
| --- | --- |
| `blender` | drives Blender through the MCP add-on |
| `godot` | drives the Godot editor through the Godot AI plugin |
| `radare2` | [r2mcp](https://github.com/radareorg/radare2-mcp) 1.8.8, radare2's own server, built from source ([`pkgs/r2mcp.nix`](../pkgs/r2mcp.nix)): opens a binary (absolute path) and analyses, disassembles and decompiles it. Its `run_*` tools (raw r2 commands) stay off. `radare2` itself is installed too |

## A game's context

`cd ~/Projects/<game> && gamedev-init` creates `.agents/design/` (PITCH,
GDD, TECH, ART, ASSETS, DECISIONS, LESSONS) from
[`home/gamedev/templates/`](../home/gamedev/templates), the instructions in
`.agents/AGENTS.md` pointing at them, and a `CLAUDE.md` that imports them
for Claude Code (`@.agents/AGENTS.md`), never overwriting. Edit them however
you like: they're the project's. omo reads only `.agents/`
([omo.md](omo.md#instructions-come-from-agents)).

## What the agents are told

Only what they ask for. The skills in
[`home/gamedev/skills/`](../home/gamedev/skills), in `~/.claude/skills` for
Claude Code and omo alike, load when a task needs them: `godot-4` (GDScript
4 and the Godot 3 habits to avoid), `godot-mcp` and `blender-mcp` (how to
drive the editors and the Blender to Godot export). The skills are
read-only links into the Nix store; change them in the repo and rebuild.
