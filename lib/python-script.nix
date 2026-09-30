# Package a Python script as a command: pkgs.writers.writePython3Bin (which
# runs flake8 on it at build time) plus the programs it calls on its PATH.
#
#   pyScript = import ../lib/python-script.nix { inherit pkgs lib; };
#   pyScript "eww-volume" { runtimeInputs = [ pkgs.wireplumber ]; } ./eww/volume.py
#
# The source is a path or a string. `replace` swaps literal strings in it,
# e.g. a placeholder constant for a store path.
{ pkgs, lib }:
name:
{
  runtimeInputs ? [ ],
  libraries ? [ ],
  replace ? { },
}:
source:
pkgs.writers.writePython3Bin name {
  inherit libraries;
  flakeIgnore = [ "E501" ];
  makeWrapperArgs = lib.optionals (runtimeInputs != [ ]) [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath runtimeInputs)
  ];
} (builtins.replaceStrings (lib.attrNames replace) (lib.attrValues replace) (if builtins.isPath source then builtins.readFile source else source))
