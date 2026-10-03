# Zelus

Zelus is a small NixOS VM for development with
[Claude Code](https://github.com/anthropics/claude-code), built with
[microvm.nix](https://github.com/microvm-nix/microvm.nix) on QEMU/KVM like
[Nike](nike.md). The guest is [`zelus/default.nix`](../zelus/default.nix);
the host side (network, shared folders, `ssh zelus`) is
[`modules/nixos/zelus.nix`](../modules/nixos/zelus.nix).

| | |
| --- | --- |
| Packages | Claude Code, bash, neovim, tmux, ranger, git, ripgrep, fd, jq, curl, wget, unzip, btop, make, gcc, python3, uv, nodejs, openssh |
| MCP servers | Blender and Godot, the same pinned ones opencode uses ([opencode.md](opencode.md#mcp-servers)) |
| Login | user `c`, no password (in `wheel`; `sudo` doesn't ask either) |
| Resources | 4 vCPUs, 6 GiB RAM |
| Address | `10.20.1.2`, host side `10.20.1.1` on the `vm-zelus` tap |
| Shared folders | `~/zelus-share` on the host is `~/share` on Zelus; `~/Projects` is `~/Projects` on both. Both read-write |
| Persistent | `/home` (32 GiB) and `/var` (4 GiB) images in `/var/lib/microvms/zelus` |

The root filesystem is a tmpfs and starts fresh on every boot; Zelus reads
the host's `/nix/store` read-only.

## Using it

It doesn't start at boot:

```sh
sudo systemctl start microvm@zelus    # stop / restart / status work too
ssh zelus                              # no password
claude                                 # /login the first time
```

`Super+o z` opens a terminal with `ssh zelus`. Claude Code's login is kept in
`~/.claude` on the `/home` volume.

bash, tmux, neovim and ranger are the host's home-manager configs with cyan
as the primary colour and pink as the second one
([`zelus/palette.nix`](../zelus/palette.nix)), so a Zelus shell looks like
neither the host (pink) nor Nike (orange).

## Blender and Godot

Blender and Godot run on the host, as usual (`Super+o Shift+b`, `Super+o d`),
with the add-ons set up as in [opencode.md](opencode.md#mcp-servers). Claude
Code on Zelus starts the two MCP servers itself, and `ssh zelus` connects
them to the editors:

| | Zelus | Host |
| --- | --- | --- |
| Blender | `blender-mcp` connects to `localhost:9876` | the add-on listens on `localhost:9876` |
| Godot | `godot-ai` listens on `localhost:9500` | the editor plugin connects to `localhost:9500` |

Both forwards are bound to localhost on each side, so nothing is opened to
the network. They exist while an `ssh zelus` session is open (later sessions
share the first one's connection), so start Claude Code from one.

The host's `localhost:9500` can be held by only one Godot MCP server: while
`ssh zelus` is open, opencode's Godot server on the host can't start, and
the other way round (ssh then warns that the forward failed). Use one of them
with Godot at a time. The Blender add-on accepts one client at a time too.

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
