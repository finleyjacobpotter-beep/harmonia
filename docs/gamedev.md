# Game dev with opencode

On harmonia (the desktop; not Cadmus), [opencode](https://opencode.ai/) runs
natively with [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)
for making games in Godot and Blender. Every agent runs on the local model,
[Ornith 1.5 9B](https://huggingface.co/ornith-ai/Ornith-1.5-9B) served as
`ai` by the [llama.cpp server](llama-server.md), four agents at a time, for
free: the planner that interviews you and writes an ultrawork plan, the
workers that carry it out, and the finisher that checks, simplifies and
finishes the work before handing it to you. The local server is the only
provider opencode offers (`enabled_providers`), so nothing leaves the
machine. Claude Code is installed too, with the same rules, skills and MCP
servers, if you want to plan or finish there. It's all in
[`home/gamedev.nix`](../home/gamedev.nix) and [`home/gamedev/`](../home/gamedev).

opencode and Claude Code run on the host with your user's access, unlike the
ones in [Zelus](opencode.md).

## Set up once

1. **The model**: click the robot icon on the bar, then **Start**. The first
   start downloads the image and the model (~6 GB); it's ready when the icon
   turns pink. See [llama-server.md](llama-server.md) if it doesn't fit in
   VRAM; change `contextLength` and `parallel` in `home/gamedev.nix` to
   match whatever you settle on.
2. **Blender and Godot**: open them. The Blender MCP add-on is already
   enabled; in each Godot project install and enable the Godot AI 4.3.0
   plugin ([opencode.md](opencode.md#mcp-servers)). The `godot-ai` service
   already runs on harmonia.
3. Start opencode once with internet access: it downloads oh-my-openagent
   5.1.21 and uv downloads the Blender and Godot MCP servers.
4. Optionally, for Claude Code: `claude` and log in.

## Who runs on what

| Agents and categories | Model |
| --- | --- |
| Prometheus (planner), Metis and Momus (they check the plan), Sisyphus, Atlas (runs the plan), Sisyphus-Junior, Oracle, explore, librarian, multimodal-looker, `ornith`, the finisher; every category | `local/ai`: Ornith 1.5 9B on the llama.cpp server |

Hephaestus is disabled because it only runs on GPT models.

## MCP servers

opencode and Claude Code both get:

| Server | What it does |
| --- | --- |
| `blender` | drives Blender through the MCP add-on |
| `godot` | drives the Godot editor through the Godot AI plugin |
| `radare2` | [r2mcp](https://github.com/radareorg/radare2-mcp) 1.8.8, radare2's own server, built from source ([`pkgs/r2mcp.nix`](../pkgs/r2mcp.nix)): opens a binary (absolute path) and analyses, disassembles and decompiles it. Its `run_*` tools (raw r2 commands) stay off. `radare2` itself is installed too |

## The workflow

1. `cd ~/Projects/<game> && gamedev-init`: creates `.omo/design/` (PITCH,
   GDD, TECH, ART, ASSETS, DECISIONS, LESSONS) and a project `AGENTS.md`.
   Jot the idea in `PITCH.md` if you like.
2. `opencode`, then **`/gd-plan <what the milestone should achieve>`**.
   Prometheus walks you through the design in rounds: vision and
   scope, gameplay loops, world and content, art style, a reference for
   every model, technical choices, then anything still open. Each question
   comes with options and a recommendation. It fills in the design docs and
   writes `.omo/plans/<milestone>.md`: an ultrawork plan in waves of up to
   four independent tasks, each card spelling out exact names, quoted
   context and the checks to run in Godot. Metis and Momus check it until
   nothing is left to guess.
3. **`/ulw-execute`**: Atlas runs the plan on Ornith, four workers at a time.
   Tasks that fail twice are left with notes instead of stalling the rest.
   (`/gd-next` on the `ornith` agent does a single task instead.)
4. **`/gd-finish`**: the finisher reads the plan and the diff, checks
   every task against its card, runs the game, simplifies the code, fixes
   and completes what's missing, commits, and writes
   `.omo/reviews/<milestone>.md` with a playtest checklist for you.

In Claude Code, `/gd-plan` and `/gd-finish` do the same jobs with the same
instructions; plans written there run with `/ulw-execute` in opencode as
usual.

## What the agents are told

- [`home/gamedev/AGENTS.md`](../home/gamedev/AGENTS.md): global rules for
  every agent: the design docs are the source of truth, the budget, verify
  every change in the engine.
- [`home/gamedev/prompts/`](../home/gamedev/prompts): appended to
  oh-my-openagent's own prompts, plus the finisher's prompt. Prometheus
  interviews and writes for a 9B executor, Momus rejects tasks that leave
  decisions open, Atlas works through the waves, the workers follow the
  card, the finisher checks and completes.
- [`home/gamedev/skills/`](../home/gamedev/skills), in `~/.claude/skills`
  for Claude Code and opencode alike: `gamedev-plan` (the doc, task card and
  wave formats), `godot-4` (GDScript 4 and the Godot 3 habits
  small models fall into), `godot-mcp` and `blender-mcp` (how to drive the
  editors and the Blender to Godot export).
- [`home/gamedev/commands/`](../home/gamedev/commands): `/gd-plan`,
  `/gd-next`, `/gd-finish` (Claude Code gets its own `/gd-plan` and
  `/gd-finish` from the same prompts).
- [`home/gamedev/templates/`](../home/gamedev/templates): what
  `gamedev-init` copies.

All of these are read-only links into the Nix store; change them in the repo
and rebuild.

## Config files

| File | From |
| --- | --- |
| `~/.config/opencode/opencode.json` | the only provider (the local server), the `ornith` and `finisher` agents, the Blender, Godot and radare2 MCP servers |
| `~/.omo/omo.jsonc` | oh-my-openagent: models, concurrency, prompts (its `[opencode]` block) |
| `~/.claude/CLAUDE.md`, `skills/`, `commands/` | Claude Code's rules, skills and commands |
| `~/.claude.json` | Claude Code's Blender, Godot and radare2 MCP servers, merged in on every switch |

Since 5.0, oh-my-openagent reads `~/.omo/omo.jsonc`; on first start it moves
an old `~/.config/opencode/oh-my-openagent.json` aside into that format.
