# opencode and Claude Code

[opencode](https://opencode.ai/) and
[Claude Code](https://github.com/anthropics/claude-code) run natively on
harmonia, from nixpkgs, configured by [`home/gamedev.nix`](../home/gamedev.nix).
They're harmonia only: cadmus, Dionysus and Nike have no AI agents.
[gamedev.md](gamedev.md) covers the game dev workflow, the agents and the
model each one runs on; this page covers what's around them: the provider,
the MCP servers, the `godot-ai` service and the skills.

```sh
opencode    # or `claude`, then /login the first time
```

Both run on the host with your user's access.

## Provider

opencode offers one provider, the local model server
([llama-server.md](llama-server.md)): `local/ai`, Ornith 1.5 9B at
`http://127.0.0.1:1235/v1`. Start it from the bar first. opencode lists no
other provider (`enabled_providers`), even with a key set; for Claude, use
Claude Code.

[oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) is loaded
as an opencode plugin, pinned to 5.1.21; opencode downloads it on first
start. Its config is `~/.omo/omo.jsonc`, with telemetry and self-updates off
([gamedev.md](gamedev.md#config-files)).

## MCP servers

opencode and Claude Code get the same three servers
([`home/mcp-servers.nix`](../home/mcp-servers.nix)), each pinned to a
release. They connect to the editors on localhost.

| Server | Version | Connects to | One-time setup in the app |
| --- | --- | --- | --- |
| `blender`: [MCP for Blender](https://github.com/ahujasid/mcp-for-blender) | `mcp-for-blender` 2.1.3 | the add-on on `localhost:9876` | none: the add-on is installed and enabled in Blender ([`home/blender-addons.nix`](../home/blender-addons.nix)) and starts its server whenever Blender opens |
| `godot`: [Godot AI](https://github.com/hi-godot/godot-ai) | `godot-ai` 4.3.0 | `godot-mcp-attach`, a `godot-ai attach` bridge to the `godot-ai` service on `localhost:8000` ([below](#the-godot-ai-service)) | install the Godot AI 4.3.0 plugin into your project (under `~/Projects`) and enable it in *Project → Project Settings → Plugins*; the plugin's version has to match the server's |
| `radare2`: [r2mcp](https://github.com/radareorg/radare2-mcp) | 1.8.8 | binaries on this machine | none |

In Claude Code, `/mcp` lists them as user servers; they're merged into
`~/.claude.json` on every switch.

Several clients can share the Godot server, so Claude Code and opencode can
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
than starting its own, and the editor, opencode and Claude Code share one
server. Its first start downloads it, so give it a minute after the first
login.

```sh
systemctl --user status godot-ai
```

Port 8000 is Godot's, which is why the Nike CyberChef tunnel uses 8001.

## Skills

Claude Code's skills are in `~/.claude/skills`, and opencode reads them
there too: the game dev ones from [`home/gamedev/skills/`](../home/gamedev/skills)
([gamedev.md](gamedev.md#what-the-agents-are-told)) and three for the Rust
command-line tools from [`home/skills/`](../home/skills): `rust-search`,
`rust-edit` and `rust-inspect` ([rust-tools.md](rust-tools.md)).

## Coming from Zelus

Claude Code and opencode used to run in Zelus, a microVM on harmonia and
cadmus; it has been removed. `sudo harmonia-cleanup` lists what it left
behind and `--apply` removes it: `/var/lib/microvms/zelus`,
`/var/lib/zelus`, `/var/lib/vm-firewall/zelus`, and `~/zelus-share` if it's
empty. Zelus's `/home` and `/var` images (your work and the Claude Code login
there) and a non-empty `~/zelus-share` go only with `--user-files`.
`~/Projects` is kept.
