# Package a Python script as a command: pkgs.writers.writePython3Bin (which
# runs flake8 on it at build time) plus the programs it calls on its PATH.
#
#   pyScript = import ../lib/python-script.nix { inherit pkgs lib; };
#   pyScript "eww-volume" { runtimeInputs = [ pkgs.wireplumber ]; } ./eww/volume.py
#
# The source is a path or a string. `wrapperArgs` are more makeWrapper
# arguments, e.g. GI_TYPELIB_PATH for a GTK window. Several scripts that
# share modules are lib/python-app.nix.
{ pkgs, lib }:
name:
{
  runtimeInputs ? [ ],
  libraries ? [ ],
  wrapperArgs ? [ ],
}:
source:
pkgs.writers.writePython3Bin name {
  inherit libraries;
  flakeIgnore = [ "E501" ];
  makeWrapperArgs =
    lib.optionals (runtimeInputs != [ ]) [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath runtimeInputs)
    ]
    ++ wrapperArgs;
} (if builtins.isPath source then builtins.readFile source else source)
