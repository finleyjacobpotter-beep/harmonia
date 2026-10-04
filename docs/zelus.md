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
| Packages | Claude Code, opencode, bash, neovim, tmux, ranger, git, ripgrep, fd, jq, curl, wget, unzip, btop, make, gcc, python3, uv, nodejs, openssh, podman + Mythic C2 ([below](#mythic-c2)) |
| MCP servers | Blender and Godot, for both Claude Code and opencode ([opencode.md](opencode.md#mcp-servers)) |
| Firewall | permissive, lockdown or local inference, switched from the bar ([below](#firewall-modes)) |
| Login | user `c`, no password (in `wheel`; `sudo` doesn't ask either) |
| Resources | 4 vCPUs, 8 GiB RAM |
| Address | `10.20.1.2`, host side `10.20.1.1` on the `vm-zelus` tap |
| Shared folders | `~/zelus-share` on the host is `~/share` on Zelus; `~/Projects` is `~/Projects` on both. Both read-write |
| Persistent | `/home` (32 GiB) and `/var` (32 GiB, also holds podman's images) in `/var/lib/microvms/zelus` |

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
([`zelus/palette.nix`](../zelus/palette.nix)), so a Zelus shell looks like
neither the host (pink) nor Nike (orange).

## Blender and Godot

Blender and Godot run on the host, as usual (`Super+o Shift+b`, `Super+o d`),
with the add-ons set up as in [opencode.md](opencode.md#mcp-servers). Claude
Code or opencode on Zelus starts the two MCP servers itself, and `ssh zelus`
connects them to the editors:

| | Zelus | Host |
| --- | --- | --- |
| Blender | `blender-mcp` connects to `localhost:9876` | the add-on listens on `localhost:9876` |
| Godot | `godot-ai` listens on `localhost:9500` | the editor plugin connects to `localhost:9500` |

Both forwards are bound to localhost on each side, so nothing is opened to
the network. They exist while an `ssh zelus` session is open (later sessions
share the first one's connection), so start Claude Code from one.

Port 9500 can be held by only one Godot MCP server, so run Claude Code and
opencode with Godot one at a time (the second one's Godot server fails to
start). The Blender add-on accepts one client at a time too. The two forwards
come with `ssh zelus`, not the network, so they work in every firewall mode.

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

## Mythic C2

Zelus can run [Mythic](https://github.com/its-a-feature/Mythic), an
open-source command-and-control framework, as a lab for red-team / OSCP
practice: start the server here and implants from your lab call back to it. It
runs on rootless **podman** (with `podman-compose`, and a `docker` alias), the
same way Nike's lab containers do, as a `systemctl`-controlled service
([`zelus/labs.nix`](../zelus/labs.nix)):

```sh
sudo systemctl start mythic     # bring Mythic up (first run clones and builds)
sudo systemctl stop mythic      # take it down
```

Unlike a plain stack such as BloodHound, Mythic ships no static compose file:
its own `mythic-cli` generates the compose project and drives it. So the
service calls the `mythic` helper ([`zelus/mythic.py`](../zelus/mythic.py)),
which clones the repo into `/var/lib/mythic`, builds `mythic-cli` once, and
runs `mythic-cli start` / `stop`. The first start pulls and builds the images,
which takes a while (`journalctl -u mythic -f` to watch it).

You can also run `mythic` by hand over `ssh zelus` for anything else:
`mythic status` (shows the admin URL and password), `mythic logs mythic_server`,
`mythic install github <url>` to add an agent, and so on. Set `MYTHIC_REF` to
pin a tag or commit. Podman keeps its images and volumes under `/var`.

Reach the UI over an SSH tunnel: `ssh -L 7443:127.0.0.1:7443 zelus`, then
<https://localhost:7443>.

The stack listens inside Zelus only. Nothing on your LAN reaches the VM: the
host NATs its egress and forwards no port in, so to catch callbacks from
elsewhere you bring the targets onto Zelus's network yourself (a tunnel, or a
forward you add on the host). Pulling and building the images needs the
internet, so keep the firewall in **Permissive** the first time (the bar's
Zelus panel, [below](#firewall-modes)).

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
[`modules/nixos/zelus.nix`](../modules/nixos/zelus.nix) and
[`modules/nixos/vm-firewall.nix`](../modules/nixos/vm-firewall.nix).

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
