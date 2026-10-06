# Zelus

Zelus is a small NixOS VM for development with
[Claude Code](https://github.com/anthropics/claude-code) and
[opencode](opencode.md), built with
[microvm.nix](https://github.com/microvm-nix/microvm.nix) on QEMU/KVM like
[Nike](nike.md). The guest is [`zelus/default.nix`](../zelus/default.nix);
the host side (network, shared folders, `ssh zelus`) is
[`modules/nixos/zelus.nix`](../modules/nixos/zelus.nix).

| | |
| --- | --- |
| Packages | Claude Code, opencode, bash, neovim, tmux, ranger, git, ripgrep, fd, jq, curl, wget, unzip, btop, make, gcc, python3, uv, nodejs, openssh |
| MCP servers | Blender and Godot, for both Claude Code and opencode ([opencode.md](opencode.md#mcp-servers)) |
| Firewall | permissive, lockdown or local inference, switched from the bar ([below](#firewall-modes)) |
| Login | user `c`, no password (in `wheel`; `sudo` doesn't ask either) |
| Resources | 4 vCPUs, 6 GiB RAM |
| Address | `10.20.1.2`, host side `10.20.1.1` on the `vm-zelus` tap |
| Shared folders | `~/zelus-share` on the host is `~/share` on Zelus; `~/Projects` is `~/Projects` on both. Both read-write |
| Persistent | `/home` (32 GiB) and `/var` (4 GiB) images in `/var/lib/microvms/zelus` |

The root filesystem is a tmpfs and starts fresh on every boot; Zelus reads
the host's `/nix/store` read-only.

## Using it

It doesn't start at boot. Start or stop it with the button in its bar panel
([the bar](bar.md#nike-and-zelus)), or from a terminal:

```sh
sudo systemctl start microvm@zelus    # stop / restart / status work too
ssh zelus                              # no password
claude                                 # /login the first time
```

or `opencode` ([opencode.md](opencode.md)).

`Super+o z` opens a terminal with `ssh zelus`. Claude Code's login is kept in
`~/.claude` on the `/home` volume.

bash, tmux, neovim and ranger are the host's home-manager configs with cyan
as the primary colour and pink as the second one
(`colors` in [`modules/nixos/zelus.nix`](../modules/nixos/zelus.nix)), so a Zelus shell looks like
neither the host (pink) nor Nike (orange).

## Blender and Godot

Blender and Godot run on the host, as usual (`Super+o Shift+b`, `Super+o d`),
with the add-ons set up as in [opencode.md](opencode.md#mcp-servers). Claude
Code and opencode on Zelus reach them through two sockets on the host's end of
Zelus's tap ([`modules/nixos/zelus.nix`](../modules/nixos/zelus.nix)), so they
work from `ssh zelus` and Zelus's console alike, with or without an ssh
session open:

| | Zelus | Host |
| --- | --- | --- |
| Blender | `blender-mcp` connects to `10.20.1.1:19876` | passed on to the add-on on `localhost:9876` |
| Godot | `godot-mcp` pipes MCP to `10.20.1.1:19500` | a `godot-ai attach` bridge per connection, to the `godot-ai` server on `localhost:8000`; the editor plugin connects to its WebSocket on `localhost:9500` |

Godot's server runs on the host because godot-ai (since v4) authenticates the editor
with a private file the server writes, which the editor has to be able to
read. It's a user service, `systemctl --user status godot-ai`, started at
login so it's up before the editor opens: the plugin adopts it rather than
starting its own (which it can't, inside the Flatpak). Its first start
downloads it, so give it a minute after the first login.

In Claude Code, `/mcp` lists both as user servers; they're written into
`~/.claude.json` each time Zelus boots.

Several clients can share the Godot server, so Claude Code and opencode can
both use Godot at once. The Blender add-on accepts one client at a time.

The two sockets are open to Zelus in every firewall mode, Lockdown included:
they reach only the editors on the host, never the internet. Port 8000 on the
host is Godot's, which is why the Nike CyberChef tunnel uses 8001.

## Rust tools and agent skills

Zelus has the same Rust command-line tools and aliases as the host and Nike
([rust-tools.md](rust-tools.md)). The aliases are skipped in Claude Code's and
opencode's shells, which expect the classic tools. Instead, both agents get
three skills that say when to use which tool: `rust-search` (rg, fd,
ast-grep), `rust-edit` (sd, ast-grep rewrites, jaq, difft) and
`rust-inspect` (tokei, dust, procs, hyperfine, xh, just, ouch). They're in
[`zelus/skills/`](../zelus/skills) and installed in `~/.claude/skills`, which
opencode reads too.

## LM Studio

LM Studio runs on the host ([lmstudio.md](lmstudio.md)), and Zelus reaches its
server at `10.20.1.1:1234`: a socket on the host's end of Zelus's tap
(`lmstudio-zelus.socket`) passes each connection on to LM Studio's
`localhost:1234`. opencode's `lmstudio` provider points there. Start the
server in LM Studio's *Developer* tab first.

## Firewall modes

The host decides what Zelus may reach, so nothing inside Zelus (root
included) can change it. Pick a mode in the bar's Zelus panel (the
*Firewall* dropdown), or on the host:

```sh
sudo vm-firewall set zelus local   # permissive | lockdown | local
vm-firewall                        # every VM's current mode
```

| Mode | Internet | Host's LM Studio |
| --- | --- | --- |
| Permissive (default) | yes | yes |
| Lockdown | no | no |
| Local inference | no | yes |

The mode is kept across reboots (`/var/lib/vm-firewall/zelus`). `ssh zelus`
works in every mode, since the host starts it. Claude Code needs the internet
for Anthropic's API, so in lockdown and local inference use opencode with the
local model. uv fetches the MCP servers on their first start, so start each
agent once in permissive mode. The rules are in
[`modules/nixos/zelus.nix`](../modules/nixos/zelus.nix),
[`modules/nixos/microvms.nix`](../modules/nixos/microvms.nix) (Lockdown and
Permissive) and [`modules/nixos/vm-firewall.nix`](../modules/nixos/vm-firewall.nix).

## Bar

The 󰒋 badge is grey while Zelus is stopped and cyan while it runs, followed
by its firewall mode: **open**, **lock** (red) or **local** (purple). Clicking
it opens a panel with Zelus's CPU, memory and disk (from its own status
service, like [Nike's](bar.md#nike-and-zelus)) and the firewall dropdown.

## Root CAs

To trust your own root CA on Zelus, put its `.crt` or `.pem` in `certs/zelus/`
(or `certs/all/` for the host, Nike and Zelus), `git add` it and `rebuild`.
See [certs/README.md](../certs/README.md).

## Changing it

Edit `zelus/default.nix` (packages go in `environment.systemPackages`) and
`rebuild`. To start over with empty disks:

```sh
sudo systemctl stop microvm@zelus
sudo rm /var/lib/microvms/zelus/{home,var}.img
```

Claude Code is unfree; it is allowed in Zelus only (the guest builds its own
package set from the same nixpkgs), so the host still allows nothing but the
Tulasi icons.
