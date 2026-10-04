# Blender and Godot from Flathub, each in a tightened flatpak sandbox that
# shares only ~/Projects with the host ("studio jail"). ~/Projects itself is
# created by home/default.nix. opencode, which drives them over MCP, runs on
# Zelus (modules/nixos/zelus.nix, home/opencode.nix).
{ lib, ... }:
let
  blender = "org.blender.Blender";
  godot = "org.godotengine.Godot";

  # Flathub gives Godot the whole host and Blender the whole home. Projects
  # live in ~/Projects; anything else is opened or saved through the file
  # chooser portal.
  filesystems = [
    "!host"
    "!home"
    "~/Projects"
  ];
in
{
  # Flathub itself and the weekly update timer come from flatpak.nix.
  services.flatpak.packages =
    map
      (appId: {
        inherit appId;
        origin = "flathub";
      })
      [
        blender
        godot
      ];

  services.flatpak.overrides =
    lib.genAttrs
      [
        blender
        godot
      ]
      (_: {
        Context.filesystems = filesystems;
        # Host-command escape (flatpak-spawn --host); see gaming.nix.
        "Session Bus Policy"."org.freedesktop.Flatpak" = "none";
      });
}
