# omo and Claude Code

[OmO](https://omo.dev) (`omo`, oh-my-openagent's native agent) and
[Claude Code](https://github.com/anthropics/claude-code) run natively on
harmonia, configured by [`home/gamedev.nix`](../home/gamedev.nix). They're
harmonia only: cadmus, Dionysus and Nike have no AI agents. omo runs
everything on the local model; otherwise both are on their own defaults,
with no global rules or system prompts from this repo: a project's
instructions live in its own `.agents/AGENTS.md` ([below](#instructions-come-from-agents);
[gamedev.md](gamedev.md) has templates for games).

```sh
omo         # start the local model from the bar first
claude      # /login the first time
```

Both run on the host with your user's access.

## omo

omo is the release binary, pinned in [`pkgs/omo.nix`](../pkgs/omo.nix)
(5.1.29) and patched for NixOS. It replaces opencode with the
oh-my-openagent plugin, which is gone. To update, bump the version and the
hashes there (from the release's `SHA256SUMS`) and rebuild; `omo update`
would install a second copy in `~/.local/bin`. The wrapper turns off its
anonymous telemetry (`OMO_SEND_ANONYMOUS_TELEMETRY=0`) and its version
check (`PI_SKIP_VERSION_CHECK=1`). Its license, the Sustainable Use License,
is why harmonia adds `omo` to `harmonia.allowedUnfree`.

Every model omo uses is `local/ai`, Ornith 1.5 9B on the
[local model server](llama-server.md): the main session, every builtin
agent (explore, librarian, the plan consultant and reviewer, the gate,
code and QA reviewers) and every task category, each with a one-model
chain, so nothing falls back to another provider. Start the server from
the bar before you start omo. It serves four requests at once; omo runs at
most four local tasks at a time and queues the rest.

omo keeps its state in `~/.omo`. On every switch the repo merges its
settings into the files there; what it sets wins, and whatever else you add
with `/mcp`, `/settings` or by hand stays:

| File | What the repo puts in it |
| --- | --- |
| `~/.omo/agent/models.json` | the `local` provider: the [local model server](llama-server.md), `local/ai` (Ornith 1.5 9B) at `http://127.0.0.1:1235/v1` |
| `~/.omo/agent/mcp.json` | the Blender, Godot and radare2 MCP servers (below) |
| `~/.omo/agent/settings.json` | `~/.claude/skills` as a skill path; `local/ai` as the startup model |
| `~/.omo/omo.jsonc` | `local/ai` for the agents, the categories and headless sessions (`model_profile`), four local tasks at a time, telemetry and computer use off |

`omo.jsonc` is merged with jq, so keep it plain JSON: if you add comments,
the switch leaves the file alone and warns. `/model` still switches the
current session to another model if you `/login` somewhere, but the next
session and every agent are back on `local/ai`.

Computer use is off: its desktop engine is a separate binary omo unpacks
unpatched, so it can't start on NixOS.

## Instructions come from .agents/

omo reads a project's instructions from `.agents/` only and uses nothing
in a project's `.omo/`. A global extension,
[`home/omo/agents-dir.ts`](../home/omo/agents-dir.ts) (installed into
`~/.omo/agent/extensions/`), and the settings around it do this:

| omo by default | Here |
| --- | --- |
| `AGENTS.md` / `CLAUDE.md` in the working directory and every parent go into the system prompt | replaced by `.agents/AGENTS.md` and any other `.md` directly in `.agents/`, from the working directory up to the repository root (the root's first, deeper ones win) |
| a subfolder's `AGENTS.md` is appended to every file read there | dropped |
| the rules engine adds `.omo/rules`, `.claude/rules`, `.cursor/rules`, `AGENTS.md`, `CLAUDE.md`, `~/.claude/CLAUDE.md` … | off (`PI_RULES_DISABLED=1` in the wrapper) |
| a trusted project's `.omo/settings.json`, `mcp.json`, extensions, skills, prompts and `SYSTEM.md` load | projects are never trusted (the extension, and `defaultProjectTrust: "never"`) |
| `.agents/skills` loads for trusted projects | the extension adds it for every project |
| ultrawork, ulw-plan, ulw-execute, ulw-loop, ulw-research, mass-ulw, hyperplan, dag-library, init-deep, frontend, visual-qa, refactor, debugging and lsp-setup write plans, drafts, evidence, ledgers, loops, DAGs, teams and LSP config into `.omo/` | disabled (`disabled_skills` in `omo.jsonc`) |

What can't be stopped:

- A project's `.omo/omo.jsonc` is read before any extension runs and
  overrides `~/.omo/omo.jsonc`, models included. A session in such a
  project starts with a warning naming the file; delete or rename it.
- omo still writes some state there on its own: worktrees for isolated
  tasks (`.omo/wt`), goals and the odd task record. Add `.omo/` to the
  project's `.gitignore`.

Claude Code doesn't read `.agents/` by itself, so a project's `CLAUDE.md`
holds just `@.agents/AGENTS.md`, which imports it.

## MCP servers

omo and Claude Code get the same three servers
([`home/mcp-servers.nix`](../home/mcp-servers.nix)), each pinned to a
release. They connect to the editors on localhost.

| Server | Version | Connects to | One-time setup in the app |
| --- | --- | --- | --- |
| `blender`: [MCP for Blender](https://github.com/ahujasid/mcp-for-blender) | `mcp-for-blender` 2.1.3 | the add-on on `localhost:9876` | none: the add-on is installed and enabled in Blender ([`home/blender-addons.nix`](../home/blender-addons.nix)) and starts its server whenever Blender opens |
| `godot`: [Godot AI](https://github.com/hi-godot/godot-ai) | `godot-ai` 4.3.0 | `godot-mcp-attach`, a `godot-ai attach` bridge to the `godot-ai` service on `localhost:8000` ([below](#the-godot-ai-service)) | install the Godot AI 4.3.0 plugin into your project (under `~/Projects`) and enable it in *Project → Project Settings → Plugins*; the plugin's version has to match the server's |
| `radare2`: [r2mcp](https://github.com/radareorg/radare2-mcp) | 1.8.8 | binaries on this machine | none |

In Claude Code, `/mcp` lists them as user servers; they're merged into
`~/.claude.json` on every switch.

Several clients can share the Godot server, so Claude Code and omo can
both use Godot at once. The Blender add-on accepts one client at a time.

Blender's add-ons folder (`BLENDER_USER_SCRIPTS`) is the copied one (it also holds the free-model add-ons, [blender.md](blender.md)), so an add-on installed with *Install from Disk* lands there and is replaced on the next rebuild; extensions from the Blender extensions platform aren't affected.

uv downloads the Blender and Godot servers from PyPI the first time they
start; after that they start from uv's cache. r2mcp is built from source
by Nix ([`pkgs/r2mcp.nix`](../pkgs/r2mcp.nix)).

To update a server, bump its version in `home/mcp-servers.nix` and the
add-on or plugin to match.

## The godot-ai service

godot-ai (since v4) authenticates the editor with a private record the
server writes to `~/.config/godot-ai`, which the editor has to be able to
read. So the server runs as a user service, `godot-ai`, on
`localhost:8000`, with the plugin's WebSocket on `localhost:9500`. It starts
at login, so it's up before the editor opens: the plugin adopts it rather
than starting its own, and the editor, omo and Claude Code share one
server. Its first start downloads it, so give it a minute after the first
login.

```sh
systemctl --user status godot-ai
```

Port 8000 is Godot's, which is why the Nike CyberChef tunnel uses 8001.

## Skills

Claude Code's skills are in `~/.claude/skills`, and omo reads them
there too (next to its own built-in ones): the game dev ones from [`home/gamedev/skills/`](../home/gamedev/skills)
([gamedev.md](gamedev.md#what-the-agents-are-told)) and three for the Rust
command-line tools from [`home/skills/`](../home/skills): `rust-search`,
`rust-edit` and `rust-inspect` ([rust-tools.md](rust-tools.md)).

## Coming from Zelus

Claude Code and opencode (since replaced by omo) used to run in Zelus, a microVM on harmonia and
cadmus; it has been removed. `sudo harmonia-cleanup` lists what it left
behind and `--apply` removes it: `/var/lib/microvms/zelus`,
`/var/lib/zelus`, `/var/lib/vm-firewall/zelus`, and `~/zelus-share` if it's
empty. Zelus's `/home` and `/var` images (your work and the Claude Code login
there) and a non-empty `~/zelus-share` go only with `--user-files`.
`~/Projects` is kept.
