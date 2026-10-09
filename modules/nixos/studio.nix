# Blender and Godot from nixpkgs, as native programs: Super+o Shift+b and
# Super+o d open them (harmonia.launchers, modules/nixos/flatpak.nix). They
# work in ~/Projects (created by home/base.nix).
# Blender's add-ons (home/blender-addons.nix) are copied into
# ~/.config/blender/harmonia-scripts, and the wrapper below points Blender
# there. Claude Code and opencode, which drive them over MCP, run on
# harmonia only (home/gamedev.nix).
#
# Plain pkgs.blender: Cycles renders on the CPU, Eevee and the viewport use
# the GPU through OpenGL/Vulkan as usual. pkgs.blender-hip adds Cycles on AMD
# GPUs (HIP), at the cost of a much bigger closure.
{ pkgs, ... }:
let
  blender = pkgs.symlinkJoin {
    name = "blender-harmonia";
    paths = [ pkgs.blender ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # The copies are pinned, so no self-update.
    postBuild = ''
      wrapProgram $out/bin/blender \
        --run 'export BLENDER_USER_SCRIPTS="$HOME/.config/blender/harmonia-scripts"' \
        --set BLENDERMCP_NO_UPDATE_CHECK 1
    '';
  };
in
{
  environment.systemPackages = [
    blender
    pkgs.godot
  ];

  harmonia.launchers = {
    blender = {
      key = "Shift+b";
      exec = "blender";
    };
    godot = {
      key = "d";
      exec = "godot";
    };
  };
}
