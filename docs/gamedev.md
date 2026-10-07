# Game dev with opencode

On harmonia (the desktop; not Cadmus), [opencode](https://opencode.ai/) runs
natively with [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)
for making games in Godot and Blender. Claude does two jobs only: it
interviews you and writes an ultrawork plan, and at the end it checks,
simplifies and finishes the work before handing it to you. Everything in
between runs on the local model
[Ornith 1.5 9B](https://huggingface.co/ornith-ai/Ornith-1.5-9B) in LM Studio,
four agents at a time, for free. The Claude agents fall back to Ornith, so
work carries on when the credits run out. Claude Code is installed too,
with the same rules, skills and MCP servers. It's all in
[`home/gamedev.nix`](../home/gamedev.nix) and [`home/gamedev/`](../home/gamedev).

opencode and Claude Code run on the host with your user's access, unlike the
ones in [Zelus](opencode.md), which stay as they were.

## Set up once

1. **LM Studio** (`Super+o l`): download `bartowski/Ornith-1.5-9B-GGUF` at
   **Q6_K** (7.7 GB). Load it with:
   - context length **262144** (Ornith's maximum), GPU offload max, flash
     attention on;
   - **Max concurrent predictions 4**: the four agents share that context,
     so opencode gives each a quarter (65536) and compacts before they could
     overflow it;
   - if it doesn't fit in the 9070's 16 GB, quantise the KV cache to Q8_0
     first, then lower the context; change `contextLength` and `parallel`
     in `home/gamedev.nix` to match whatever you settle on;
   - in the hardware settings, only the RX 9070 (Vulkan): splitting onto the
     5600 XT only slows it down;
   - top_k 20 and min_p 0 in the model's defaults (Ornith's coding settings;
     opencode sends temperature 0.6 and top_p 0.95 itself).

   Start the server (*Developer* tab). The API identifier must be
   `ornith-1.5-9b` (`curl localhost:1234/v1/models`); if it differs, change
   `ornithId`. LM Studio's bundled vision adapter (mmproj) lets Ornith read
   screenshots.
2. **Claude**: run `opencode`, then `/connect` → *Anthropic* → API key; for
   Claude Code, `claude` and log in. Set a spend limit in the Anthropic
   Console too: that is the only hard cap.
3. **Blender and Godot**: open them. The Blender MCP add-on is already
   enabled; in each Godot project install and enable the Godot AI 4.3.0
   plugin ([opencode.md](opencode.md#mcp-servers)). The `godot-ai` service
   already runs on harmonia.
4. Start opencode once with internet access: it downloads oh-my-openagent
   5.1.21 and uv downloads the MCP servers.

## Who runs on what

| Agents and categories | Model | Cost |
| --- | --- | --- |
| Prometheus (planner), the finisher | Claude Opus 5.5 | $4 / $20 per million tokens in / out |
| Metis and Momus (they check the plan) | Claude Sonnet 5.5 | $2 / $10 |
| Sisyphus, Atlas (runs the plan), Sisyphus-Junior, Oracle, explore, librarian, multimodal-looker, `ornith`; every category | Ornith 1.5 9B, local | free |

The Claude agents fall back to Ornith (Opus via Sonnet) on rate limits,
overload, a missing key and "credit balance too low", and stay on it for
that session. Hephaestus is disabled because it only runs on GPT models.

## The workflow

1. `cd ~/Projects/<game> && gamedev-init`: creates `.omo/design/` (PITCH,
   GDD, TECH, ART, ASSETS, DECISIONS, LESSONS) and a project `AGENTS.md`.
   Jot the idea in `PITCH.md` if you like.
2. `opencode`, then **`/gd-plan <what the milestone should achieve>`**.
   Prometheus (Opus) walks you through the design in rounds: vision and
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
4. **`/gd-finish`**: the finisher (Opus) reads the plan and the diff, checks
   every task against its card, runs the game, simplifies the code, fixes
   and completes what's missing, commits, and writes
   `.omo/reviews/<milestone>.md` with a playtest checklist for you.

In Claude Code, `/gd-plan` and `/gd-finish` do the same jobs with the same
instructions; plans written there run with `/ulw-execute` in opencode as
usual. opencode shows each session's cost in the sidebar, and
`opencode stats` totals it.

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
| `~/.config/opencode/opencode.json` | providers (LM Studio, Claude with prices), the `ornith` and `finisher` agents, the Blender and Godot MCP servers |
| `~/.omo/omo.jsonc` | oh-my-openagent: models, fallbacks, concurrency, prompts (its `[opencode]` block) |
| `~/.claude/CLAUDE.md`, `skills/`, `commands/` | Claude Code's rules, skills and commands |
| `~/.claude.json` | Claude Code's Blender and Godot MCP servers, merged in on every switch |

Since 5.0, oh-my-openagent reads `~/.omo/omo.jsonc`; on first start it moves
an old `~/.config/opencode/oh-my-openagent.json` aside into that format.
