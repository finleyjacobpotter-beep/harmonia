# Blender, Godot and opencode from Flathub, each in a tightened flatpak
# sandbox that shares only ~/Projects with the host ("studio jail").
# ~/Projects itself is created by home/default.nix; opencode's config is in
# home/opencode.nix.
{ lib, ... }:
let
  blender = "org.blender.Blender";
  godot = "org.godotengine.Godot";
  opencode = "ai.opencode.opencode";

  # Flathub gives Godot the whole host and Blender and opencode the whole
  # home. Projects live in ~/Projects; anything else is opened or saved
  # through the file chooser portal.
  filesystems = [
    "!host"
    "!home"
    "~/Projects"
  ];
in
{
  # Flathub itself and the weekly update timer come from flatpak.nix.
  services.flatpak.packages = map
    (appId: {
      inherit appId;
      origin = "flathub";
    })
    [
      blender
      godot
      opencode
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
      })
    // {
      # opencode keeps the host-command escape: it starts the Blender and
      # Godot MCP servers on the host with flatpak-spawn --host (they need uv
      # and git, which the sandbox doesn't have). A command run that way can
      # reach the whole home, so for opencode the filesystem rule only limits
      # what the app itself opens directly.
      ${opencode} = {
        Context.filesystems = filesystems;
        "Session Bus Policy"."org.freedesktop.Flatpak" = "talk";
      };
    };
}
