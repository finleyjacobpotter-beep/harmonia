# Blender and Godot from Flathub, each in a tightened flatpak sandbox that
# shares only ~/Projects with the host ("studio jail"). ~/Projects itself is
# created by home/default.nix. opencode, which drives them over MCP, runs on
# Zelus (modules/nixos/zelus.nix, home/opencode.nix).
{ username, ... }:
let
  blender = "org.blender.Blender";
  godot = "org.godotengine.Godot";

  # Flathub gives Godot the whole host and Blender the whole home. Projects
  # live in ~/Projects; anything else is opened or saved through the file
  # chooser portal.
  sandbox = {
    Context.filesystems = [
      "!host"
      "!home"
      "~/Projects"
    ];
    # Host-command escape (flatpak-spawn --host); see gaming.nix.
    "Session Bus Policy"."org.freedesktop.Flatpak" = "none";
  };
in
{
  harmonia.apps = {
    ${blender} = {
      name = "blender";
      key = "Shift+b";
      sandbox = sandbox // {
        # The MCP for Blender add-on and the script that enables it
        # (home/blender-mcp.nix); the copy is pinned, so no self-update.
        Environment = {
          BLENDER_USER_SCRIPTS = "/home/${username}/.var/app/${blender}/config/blender/harmonia-scripts";
          BLENDERMCP_NO_UPDATE_CHECK = "1";
        };
      };
    };
    ${godot} = {
      name = "godot";
      key = "d";
      inherit sandbox;
    };
  };
}
