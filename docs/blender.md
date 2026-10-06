# Blender

Blender is the Flathub app, jailed with Godot so it sees only `~/Projects`
([`modules/nixos/studio.nix`](../modules/nixos/studio.nix)); `Super+o Shift+b`
opens it. It keeps the network, which the add-ons below need.

## Free models

Three add-ons are installed and enabled on every start, pinned and copied into
the sandbox by [`home/blender-addons.nix`](../home/blender-addons.nix) (with MCP
for Blender, [opencode.md](opencode.md#mcp-servers)). None of them updates
itself; bump the pin to update.

| Source | Add-on | Where | One-time setup |
| --- | --- | --- | --- |
| [Poly Haven](https://polyhaven.com/) (CC0 HDRIs, materials, models) | [Poly Haven Assets](https://github.com/Poly-Haven/polyhavenassets) 1.2.3, Poly Haven's own | Asset Browser, library **Poly Haven** | in the Asset Browser pick the Poly Haven library and press *Fetch Assets* in its header to pull the catalogue |
| [Sketchfab](https://sketchfab.com/) (free-licence downloadable models) | [Sketchfab plugin](https://github.com/sketchfab/blender-plugin) 1.8.0, Sketchfab's official | 3D view sidebar (`N`), **Sketchfab** tab | log in with your API token from [sketchfab.com/settings/password](https://sketchfab.com/settings/password) (free account) |
| [Poly Pizza](https://poly.pizza/) (CC0 and CC-BY low-poly models) | Poly Pizza ([`home/blender/poly_pizza.py`](../home/blender/poly_pizza.py)), harmonia's own | 3D view sidebar (`N`), **Poly Pizza** tab | paste a free API key from [poly.pizza/settings/api](https://poly.pizza/settings/api) into the add-on's preferences |

Downloads stay in `~/Projects/Assets` (Poly Haven and Poly Pizza), so Godot
and Zelus can use them too. The Poly Haven library is created there on first
start, set to *Append* as the add-on wants.

Notes:

- Poly Haven sells its add-on (Superhive, or Patreon) to fund the free
  assets, and publishes the source under GPL-3.0; harmonia builds it from that
  source. If it's useful, consider [supporting them](https://www.patreon.com/polyhaven/overview).
- Poly Pizza has no Blender add-on of its own, so harmonia ships a small one:
  search, browse thumbnails, *Import* puts the model at the 3D cursor. Each
  import is cached as `<id>.glb`, tagged with its attribution
  (`poly_pizza_attribution` custom property), and its credit line is added to
  the **Poly Pizza credits** text in the .blend; CC-BY models need that credit
  wherever you publish them.
- Sketchfab keeps its token in a temporary file and its downloads in the
  system temp folder (both inside the sandbox); change the download folder in
  its preferences to keep models.
- Anything installed with *Install from Disk* lands in the copied add-ons
  folder and is replaced on the next rebuild; add add-ons to
  `home/blender-addons.nix` instead.
