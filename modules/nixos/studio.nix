# Blender, Godot and opencode from Flathub, each in a tightened flatpak
# sandbox that shares only ~/Projects with the host ("studio jail").
# ~/Projects itself is created by home/default.nix.
{ lib, ... }:
let
  blender = "org.blender.Blender";
  godot = "org.godotengine.Godot";
  opencode = "ai.opencode.opencode";
  apps = [
    blender
    godot
    opencode
  ];

  # The same filesystem and host-escape rules for all three.
  jail = {
    Context = {
      # Flathub gives Godot the whole host and Blender and opencode the
      # whole home. Projects live in ~/Projects; anything else is opened or
      # saved through the file chooser portal.
      filesystems = [
        "!host"
        "!home"
        "~/Projects"
      ];
    };
    "Session Bus Policy" = {
      # Host-command escape (flatpak-spawn --host); see gaming.nix. Without
      # it opencode's shell tool runs commands inside the sandbox, not on
      # the host.
      "org.freedesktop.Flatpak" = "none";
    };
  };
in
{
  # Flathub itself and the weekly update timer come from flatpak.nix.
  services.flatpak.packages = map (appId: {
    inherit appId;
    origin = "flathub";
  }) apps;

  services.flatpak.overrides = lib.genAttrs apps (_: jail);
}
