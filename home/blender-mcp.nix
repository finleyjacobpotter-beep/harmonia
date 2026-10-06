# The MCP for Blender add-on, installed and enabled in the Flatpak Blender
# (modules/nixos/studio.nix), so Claude Code and opencode on Zelus can reach
# it (modules/nixos/zelus.nix): flatpak-miami-wind (home/flatpak-files.nix)
# copies it into the sandbox's own config folder, Blender's
# BLENDER_USER_SCRIPTS points there, and a startup script enables the add-on.
# The add-on starts its server (localhost:9876) whenever Blender opens.
#
# It comes from the same release as the MCP server (home/mcp-servers.nix);
# bump both together.
{ pkgs, ... }:
let
  wheel = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/fa/37/f77c0b5f7ae3afdc1653fee46b99f234e722754668121d4888005741ff0d/mcp_for_blender-2.1.3-py3-none-any.whl";
    hash = "sha256-ykvQAbMXAZ/4iIIDF8EOjFM/mjFTL5gDEPgq8wxFCyA=";
  };

  enable = pkgs.writeText "enable_blender_mcp.py" ''
    # Enables MCP for Blender on every start (home/blender-mcp.nix).
    import addon_utils
    import bpy


    def _enable():
        if not addon_utils.check("blender_mcp")[1]:
            addon_utils.enable("blender_mcp", default_set=True, persistent=True)


    def register():
        bpy.app.timers.register(_enable, first_interval=0.1)


    def unregister():
        pass
  '';

  scripts = pkgs.runCommand "blender-mcp-scripts" { nativeBuildInputs = [ pkgs.unzip ]; } ''
    unzip -q ${wheel} 'blender_mcp/bundled/addon.py'
    install -Dm644 blender_mcp/bundled/addon.py $out/addons/blender_mcp.py
    install -Dm644 ${enable} $out/startup/enable_blender_mcp.py
  '';
in
{
  harmonia.flatpakFiles.".var/app/org.blender.Blender/config/blender/harmonia-scripts" = scripts;
}
