# Game dev with opencode

On harmonia (the desktop; not Cadmus), [opencode](https://opencode.ai/) runs
natively with [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)
for making games in Godot and Blender. Claude plans, reviews and gets you
unstuck; the local model [Ornith 1.5 9B](https://huggingface.co/ornith-ai/Ornith-1.5-9B)
in LM Studio does the implementing, for free. Every Claude agent falls back
to Ornith, so work carries on when the credits run out. It's all in
[`home/gamedev.nix`](../home/gamedev.nix) and [`home/gamedev/`](../home/gamedev).

This opencode runs on the host with your user's access, unlike the one in
[Zelus](opencode.md), which stays as it was.

## Set up once

1. **LM Studio** (`Super+o l`): download `bartowski/Ornith-1.5-9B-GGUF` at
   **Q6_K** (7.7 GB). In its load settings set the context length to
   **131072**, GPU offload to max and flash attention on; in the hardware
   settings use only the RX 9070 (Vulkan), since splitting a 9B model onto
   the 5600 XT only slows it down. Ornith's card recommends top_k 20 and
   min_p 0 for coding: set those in the model's defaults (opencode sends
   temperature 0.6 and top_p 0.95 itself). Start the server (*Developer*
   tab). The model's API identifier must be `ornith-1.5-9b` (check with
   `curl localhost:1234/v1/models`); if it differs, change `ornithId` in
   `home/gamedev.nix`. If 131072 doesn't fit in VRAM, use a smaller context
   and change `contextLength` there to match. LM Studio's bundled vision
   adapter (mmproj) lets Ornith read screenshots.
2. **Claude**: run `opencode`, then `/connect` → *Anthropic* → API key. Set
   a spend limit in the Anthropic Console too: that is the only hard cap.
3. **Blender and Godot**: open them. The Blender MCP add-on is already
   enabled; in each Godot project install and enable the Godot AI 4.3.0
   plugin ([opencode.md](opencode.md#mcp-servers)). The `godot-ai` service
   already runs on harmonia.
4. Start opencode once with internet access: it downloads oh-my-openagent
   5.1.21 and uv downloads the MCP servers.

## Who runs on what

| Agents and categories | Model | Cost |
| --- | --- | --- |
| Prometheus (planner), Oracle (debugging advisor); `ultrabrain` | Claude Opus 5.5 | $4 / $20 per million tokens in / out |
| Sisyphus (default agent), Atlas (plan runner), Metis, Momus (plan checks); `unspecified-high` | Claude Sonnet 5.5 | $2 / $10 |
| `ornith` (free primary agent), Sisyphus-Junior, explore, librarian, multimodal-looker; `quick`, `unspecified-low`, `deep-low`, `deep-high`, `visual-engineering`, `artistry`, `writing` | Ornith 1.5 9B, local | free |

Opus falls back to Sonnet and then Ornith, Sonnet to Ornith. The fallback
(`runtime_fallback`) kicks in on rate limits, overload, a missing key and
"credit balance too low", and stays on the fallback for that session.
Hephaestus is disabled because it only runs on GPT models. LM Studio gets one
request at a time, so background agents queue rather than fight over VRAM.

## The workflow

The point is to spend Claude once, on plans detailed enough that the local
model can work through them alone for as long as it takes.

1. `cd ~/Projects/<game> && gamedev-init`: creates `.omo/design/` (PITCH,
   GDD, TECH, ART, ASSETS, DECISIONS, LESSONS) and a project `AGENTS.md`.
   Write `PITCH.md` yourself.
2. `opencode`, then `/gd-plan <what the milestone should achieve>`.
   Prometheus (Opus) interviews you, fills in the design docs and writes
   `.omo/plans/<milestone>.md`: tasks small enough for a 9B model, each
   with exact names, quoted context and checks it runs itself in Godot.
3. Do the work, either:
   - `/gd-next` on the `ornith` agent: one task at a time, free; or
   - `/ulw-execute` (Atlas, Sonnet): runs the whole plan, handing each task
     to the local categories, so Claude only spends on coordination.
4. If the local model is stuck, `/gd-unstick <task and error>` asks Oracle
   (Opus) for the fix as steps the local model can follow, plus a line for
   `LESSONS.md`.

`Tab` switches agents; switch to `ornith` for any session that shouldn't
spend credits. opencode shows each session's cost in the sidebar, and
`opencode stats` totals it.

## What the agents are told

- [`home/gamedev/AGENTS.md`](../home/gamedev/AGENTS.md): global rules for
  every agent: the design docs are the source of truth, the budget, verify
  every change in the engine.
- [`home/gamedev/prompts/`](../home/gamedev/prompts): appended to
  oh-my-openagent's own prompts. Prometheus writes for a 9B executor, Momus
  rejects tasks that leave decisions open, the orchestrators delegate the
  doing, the workers follow the card.
- [`home/gamedev/skills/`](../home/gamedev/skills): `gamedev-plan` (the
  doc and task card formats), `godot-4` (GDScript 4 and the Godot 3 habits
  small models fall into), `godot-mcp` and `blender-mcp` (how to drive the
  editors and the Blender to Godot export).
- [`home/gamedev/commands/`](../home/gamedev/commands): `/gd-plan`,
  `/gd-next`, `/gd-unstick`.
- [`home/gamedev/templates/`](../home/gamedev/templates): what
  `gamedev-init` copies.

All of these are read-only links into the Nix store; change them in the repo
and rebuild.

## Config files

| File | From |
| --- | --- |
| `~/.config/opencode/opencode.json` | providers (LM Studio, Claude with prices), the `ornith` agent, the Blender and Godot MCP servers |
| `~/.omo/omo.jsonc` | oh-my-openagent: models, fallbacks, concurrency, prompts (its `[opencode]` block) |

Since 5.0, oh-my-openagent reads `~/.omo/omo.jsonc`; on first start it moves
an old `~/.config/opencode/oh-my-openagent.json` aside into that format.
