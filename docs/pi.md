# pi and Claude Code

[pi](https://pi.dev) and [Claude Code](https://github.com/anthropics/claude-code)
run on harmonia in containers ([below](#the-containers)), configured by
[`home/ai.nix`](../home/ai.nix) (pi) and
[`home/gamedev.nix`](../home/gamedev.nix) (Claude Code), with the
containers in [`home/agents.nix`](../home/agents.nix).
They're harmonia only: cadmus, Dionysus and Nike have no AI agents. Both
are on their own defaults, with no global rules from this repo: a project's
instructions live in its own `.agents/AGENTS.md`
([below](#instructions-come-from-agents); [gamedev.md](gamedev.md) has
templates for games). The one thing added to their system prompt is where
they run ([below](#what-the-agents-are-told-about-the-container)).

```sh
cd ~/Projects/agon/agon
pi          # /login the first time, or set a provider's API key
claude      # /login the first time
```

## The containers

`claude` and `pi` aren't the agents themselves but launchers: each starts
the agent in a new rootless podman container for the folder you're in,
named `<agent>-<folder>-<uuid>` (`claude-agon-3f2c…`), and removes it when
the agent exits. They show on the dash's virtualization tile with a 󰚩 and
the folder they work in ([the dash](bar.md#tiles)). Neither agent is
installed on the host any more.

The image is built by Nix and loaded into podman the first time you run
an agent after a rebuild that changed it (about half a minute):

- **Debian 13 (trixie-slim)**, pinned by digest, as the system;
- **Nix** with flakes, single-user and owned by you inside, so `nix shell
  nixpkgs#…`, `nix develop` and `nix build` work. It has its own store,
  separate from the host's (your user is a trusted Nix user, so sharing the
  host's daemon would hand the agent root); its builds run without Nix's
  sandbox, which needs namespaces the container doesn't allow;
- **Claude Code** and **pi**, the same builds as before, and the **MCP
  servers** (the same builds the configs name);
- **Godot** and **Blender**, headless (`godot --headless`, `blender -b`);
- git, ripgrep, fd, jq, curl, uv, Python and the usual shell tools.

Each container sees only:

| In the container | From the host |
| --- | --- |
| `~/workdir` (read-write, where the agent starts) | the folder you ran `claude` or `pi` in |
| `~/.claude` (Claude Code) | `~/.claude`: settings, login, sessions, skills; `.claude.json` lives in it now (`CLAUDE_CONFIG_DIR`), moved there from `~/.claude.json` once |
| `~/.pi` and `~/.claude/skills` read-only (pi) | the same |
| `~/.cache` | `~/.cache/harmonia-agents` (uv's and Nix's caches, so MCP servers start fast) |
| `~/.config/godot-ai/capabilities`, read-only | the godot-ai record ([below](#the-godot-ai-service)) |

Everything else in the container's home is a private tmpfs, gone when it
exits, and so is anything installed into its Nix store. It runs as your
uid (`--userns=keep-id`) with every capability dropped, no-new-privileges
and no sudo or setuid programs, so there is no way to root; it has a
process limit. It reaches the internet, but of the host's own services only
Blender's add-on (9876) and godot-ai (8000, 9500), which pasta forwards to
the container's localhost; everything else on the host's localhost is
refused. Commits carry your git name and email (passed in, since
`~/.config/git` isn't mounted); pushing over SSH has no keys inside, so
push from the host.

### What the agents are told about the container

Both start with `--append-system-prompt`: that they run in a rootless
container with Nix and flakes and headless Godot and Blender, that only
`~/workdir` and their configuration are there and only Blender and Godot
of the host's services, to use `nix shell` for missing tools, to tell you
when a request needs something outside the container rather than work
around it, and not to probe or test the container, or run a project's
tests unless the change calls for them.

## pi

pi is the upstream release build, pinned in [`pkgs/pi.nix`](../pkgs/pi.nix)
(1.1.0) and patched for NixOS; nixpkgs' `pi-coding-agent` (0.87) predates
pi's built-in MCP client. To update, bump the version and the hashes there
(from the release's `SHA256SUMS`) and rebuild. The wrapper turns off its
install telemetry (`PI_TELEMETRY=0`) and its version check
(`PI_SKIP_VERSION_CHECK=1`).

pi is one agent: no subagents or task categories. The repo sets no
provider or model: `/login` to one (or set its API key) and pick a model
with `/model`, which pi remembers.

pi keeps its state in `~/.pi/agent` (sessions included; nothing in the
project). On every switch the repo merges its settings into the files
there; what it sets wins, and whatever else you add with `/mcp`,
`/settings` or by hand stays:

| File | What the repo puts in it |
| --- | --- |
| `~/.pi/agent/models.json` | nothing; it only takes out the `local` provider older versions put there |
| `~/.pi/agent/mcp.json` | the Blender, Godot and radare2 MCP servers (below) |
| `~/.pi/agent/settings.json` | `~/.claude/skills` as a skill path, projects never trusted, telemetry off; it takes out the `local/ai` startup model older versions set |
| `~/.pi/agent/extensions/agents-dir.ts` | the `.agents/` extension (below), copied (a link into the host's Nix store would dangle in the container) |

omo (oh-my-openagent), which this replaced, kept its state in `~/.omo`;
delete that folder once you don't need its sessions.

## Instructions come from .agents/

pi reads a project's instructions from `.agents/` only and uses nothing in
a project's `.pi/`. A global extension,
[`home/pi/agents-dir.ts`](../home/pi/agents-dir.ts), and the settings
around it do this:

| pi by default | Here |
| --- | --- |
| `AGENTS.md` / `CLAUDE.md` in the working directory and every parent go into the system prompt | replaced by `.agents/AGENTS.md` and any other `.md` directly in `.agents/`, from the working directory up to the repository root (the root's first, deeper ones win) |
| a trusted project's `.pi/settings.json`, `mcp.json`, extensions, skills, prompts and `SYSTEM.md` load | projects are never trusted (the extension, and `defaultProjectTrust: "never"`) |
| `.agents/skills` loads for trusted projects | the extension adds it for every project |

Claude Code doesn't read `.agents/` by itself, so a project's `CLAUDE.md`
holds just `@.agents/AGENTS.md`, which imports it.

## MCP servers

pi and Claude Code get the same three servers
([`home/mcp-servers.nix`](../home/mcp-servers.nix)), each pinned to a
release. They connect to the editors on localhost.

| Server | Version | Connects to | One-time setup in the app |
| --- | --- | --- | --- |
| `blender`: [MCP for Blender](https://github.com/ahujasid/mcp-for-blender) | `mcp-for-blender` 2.1.3 | the add-on on `localhost:9876` | none: the add-on is installed and enabled in Blender ([`home/blender-addons.nix`](../home/blender-addons.nix)) and starts its server whenever Blender opens |
| `godot`: [Godot AI](https://github.com/hi-godot/godot-ai) | `godot-ai` 4.3.0 | `godot-mcp-attach`, a `godot-ai attach` bridge to the `godot-ai` service on `localhost:8000` ([below](#the-godot-ai-service)) | install the Godot AI 4.3.0 plugin into your project (under `~/Projects`) and enable it in *Project → Project Settings → Plugins*; the plugin's version has to match the server's |
| `radare2`: [r2mcp](https://github.com/radareorg/radare2-mcp) | 1.8.8 | binaries on this machine | none |

In Claude Code, `/mcp` lists them as user servers; they're merged into
`~/.claude/.claude.json` on every switch. The containers run the servers
themselves, from the same builds; Blender's and Godot's ports are
forwarded from the host ([above](#the-containers)), and radare2 analyses
binaries in `~/workdir`.

Several clients can share the Godot server, so Claude Code and pi can
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
than starting its own, and the editor, pi and Claude Code share one
server. Its first start downloads it, so give it a minute after the first
login.

```sh
systemctl --user status godot-ai
```

Port 8000 is Godot's, which is why the Nike CyberChef tunnel uses 8001.

## Skills

Claude Code's skills are in `~/.claude/skills` (copied there on every
switch, not linked, so the containers can read them), and pi reads them
there too: the game dev ones from [`home/gamedev/skills/`](../home/gamedev/skills)
([gamedev.md](gamedev.md#what-the-agents-are-told)) and three for the Rust
command-line tools from [`home/skills/`](../home/skills): `rust-search`,
`rust-edit` and `rust-inspect` ([rust-tools.md](rust-tools.md)).

## Coming from Zelus

Claude Code and opencode (since replaced by pi) used to run in Zelus, a microVM on harmonia and
cadmus; it has been removed. `sudo harmonia-cleanup` lists what it left
behind and `--apply` removes it: `/var/lib/microvms/zelus`,
`/var/lib/zelus`, `/var/lib/vm-firewall/zelus`, and `~/zelus-share` if it's
empty. Zelus's `/home` and `/var` images (your work and the Claude Code login
there) and a non-empty `~/zelus-share` go only with `--user-files`.
`~/Projects` is kept.
