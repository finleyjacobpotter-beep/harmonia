# opencode

[opencode](https://opencode.ai/) comes from Flathub (`ai.opencode.opencode`,
installed by [`modules/nixos/studio.nix`](../modules/nixos/studio.nix)) and is
configured by [`home/opencode.nix`](../home/opencode.nix). Start it with
`Super+o o`, or run `opencode` in a terminal.

## Providers

| Provider | Model | Needs |
| --- | --- | --- |
| LM Studio (default) | `lmstudio/ornith-small` | LM Studio's local server running (*Developer* tab, `localhost:1234`) with the model loaded |
| Anthropic (Claude) | any `anthropic/...` model | an API key in pass |

The LM Studio model key must match the model's API identifier in LM Studio.
If LM Studio shows a different identifier (for example `ornith-1.0-9b`),
either set the identifier to `ornith-small` in LM Studio's model settings or
change the key in `home/opencode.nix`.

## API keys in pass

The `opencode` command reads the key from pass and hands it to the app as
`ANTHROPIC_API_KEY`; no key is written to disk. Store it once:

```sh
pass insert opencode/anthropic-api-key
```

`Super+o o` opens a terminal for this so pinentry can ask for your gpg
passphrase, then closes it once opencode is running. Without the entry,
opencode still starts with LM Studio only. Don't add keys through opencode's
own `/connect`: that saves them in plain text in the app's data directory.

## MCP servers

Both servers run on the host, started by opencode with `flatpak-spawn --host`
(which is why opencode, unlike Blender and Godot, keeps that permission), and
are pinned to a release:

| Server | Version | One-time setup in the app |
| --- | --- | --- |
| [MCP for Blender](https://github.com/ahujasid/mcp-for-blender) | `mcp-for-blender` 2.1.3 | install the add-on file from the repository (its README says which) with *Edit → Preferences → Add-ons → Install from Disk*, enable *Interface: MCP for Blender* and click *Connect* in its sidebar tab (port 9876) |
| [Godot MCP](https://github.com/bebabinlarsson-blip/Godot-MCP) | v5.0.9 | copy `addons/godot_ai` and `addons/godot_omni` from the v5.0.9 release zip into your project (under `~/Projects`), then enable *Godot MCP Core* and *Godot MCP Omni* in *Project → Project Settings → Plugins* (WebSocket on port 8000) |

`uvx mcp-for-blender install-addon` won't work here: it installs into the
host's Blender config, and the Flatpak Blender reads
`~/.var/app/org.blender.Blender/config/blender` instead.

To update a server, bump its version in `home/opencode.nix` and the add-on
to match.
