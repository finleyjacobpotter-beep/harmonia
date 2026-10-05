# Package a directory of Python scripts as commands that share one Python,
# one PATH and their common modules: every *.py in `src`, flake8-checked at
# build time like pyScript (lib/python-script.nix), with one command per
# entry in `commands` (command name -> script name without .py). The
# commands also find each other on PATH.
#
#   pyApp = import ../lib/python-app.nix { inherit pkgs lib; };
#   pyApp {
#     name = "harmonia-bar";
#     src = ./eww;
#     commands = { eww-volume = "volume"; };
#     runtimeInputs = [ pkgs.wireplumber ];
#   }
{ pkgs, lib }:
{
  name,
  src,
  commands,
  libraries ? [ ],
  runtimeInputs ? [ ],
  wrapperArgs ? [ ],
}:
let
  python = pkgs.python3.withPackages (_: libraries);
in
pkgs.runCommand name
  {
    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.python3Packages.flake8
    ];
  }
  ''
    mkdir -p $out/bin $out/lib/${name}
    cp ${src}/*.py $out/lib/${name}/
    flake8 --ignore E501 $out/lib/${name}
    ${lib.concatStrings (
      lib.mapAttrsToList (command: script: ''
        makeWrapper ${python}/bin/python3 $out/bin/${command} \
          --add-flags $out/lib/${name}/${script}.py \
          --prefix PATH : ${lib.makeBinPath runtimeInputs}:$out/bin \
          ${lib.escapeShellArgs wrapperArgs}
      '') commands
    )}
  ''
