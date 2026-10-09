# Blender add-ons, installed and enabled in Blender (modules/nixos/studio.nix):
# flatpak-miami-wind (home/flatpak-files.nix) copies them into
# ~/.config/blender/harmonia-scripts as real, writable files (the add-ons
# write next to themselves), Blender's wrapper points BLENDER_USER_SCRIPTS
# there, and a startup script enables them. Every copy is pinned, so none of
# them updates itself.
#
#   - MCP for Blender, so Claude Code and opencode on Zelus can drive Blender
#     (modules/nixos/zelus.nix). It starts its server (localhost:9876)
#     whenever Blender opens. It comes from the same release as the MCP server
#     (home/mcp-servers.nix); bump both together.
#   - Free models (docs/blender.md):
#       Poly Haven Assets, Poly Haven's own add-on (GPL, built from source),
#         in the Asset Browser's "Poly Haven" library, ~/Projects/Assets/Poly Haven;
#       Poly Pizza (./blender/poly_pizza.py), in the sidebar's Poly Pizza tab.
{ pkgs, ... }:
let
  mcpWheel = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/fa/37/f77c0b5f7ae3afdc1653fee46b99f234e722754668121d4888005741ff0d/mcp_for_blender-2.1.3-py3-none-any.whl";
    hash = "sha256-ykvQAbMXAZ/4iIIDF8EOjFM/mjFTL5gDEPgq8wxFCyA=";
  };

  polyHaven = pkgs.fetchFromGitHub {
    owner = "Poly-Haven";
    repo = "polyhavenassets";
    rev = "v1.2.3";
    hash = "sha256-hFwdQ1i1pMllb1oeRwS6dNztJ7PtS1lGJIuL7K78pBY=";
  };

  enable = pkgs.writeText "enable_harmonia_addons.py" ''
    # Enables harmonia's add-ons on every start (home/blender-addons.nix).
    import os

    import addon_utils
    import bpy

    ADDONS = ("blender_mcp", "polyhavenassets", "poly_pizza")
    POLY_HAVEN = os.path.expanduser("~/Projects/Assets/Poly Haven")


    def _poly_haven_library(prefs):
        # The add-on downloads into the asset library named exactly "Poly Haven".
        libs = prefs.filepaths.asset_libraries
        lib = next((l for l in libs if l.name.lower() == "poly haven"), None)
        if lib is None:
            os.makedirs(POLY_HAVEN, exist_ok=True)
            bpy.ops.preferences.asset_library_add(directory=POLY_HAVEN)
            lib = next(l for l in libs if os.path.normpath(l.path) == POLY_HAVEN)
            lib.name = "Poly Haven"
            lib.import_method = "APPEND"


    def _enable():
        for name in ADDONS:
            if not addon_utils.check(name)[1]:
                addon_utils.enable(name, default_set=True, persistent=True)
        prefs = bpy.context.preferences
        # Pinned by Nix: no update checks against GitHub.
        ph = prefs.addons.get("polyhavenassets")
        if ph is not None:
            ph.preferences.auto_check_update = False
        _poly_haven_library(prefs)


    def register():
        bpy.app.timers.register(_enable, first_interval=0.1)


    def unregister():
        pass
  '';

  scripts = pkgs.runCommand "blender-addons" { nativeBuildInputs = [ pkgs.unzip ]; } ''
    unzip -q ${mcpWheel} 'blender_mcp/bundled/addon.py'
    install -Dm644 blender_mcp/bundled/addon.py $out/addons/blender_mcp.py
    cp -r --no-preserve=mode ${polyHaven} $out/addons/polyhavenassets
    install -Dm644 ${./blender/poly_pizza.py} $out/addons/poly_pizza.py
    install -Dm644 ${enable} $out/startup/enable_harmonia_addons.py
  '';
in
{
  harmonia.flatpakFiles.".config/blender/harmonia-scripts" = scripts;
}
