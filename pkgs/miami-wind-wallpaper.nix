# Recolours an image to the Miami Wind palette with lutgen, which builds a
# colour lookup table from the palette and maps every pixel through it.
#
# Every plain "#rrggbb" colour in theme/miami-wind.nix is used, so tweaking
# the palette re-tints the wallpaper on the next rebuild.
{
  lib,
  runCommand,
  lutgen,
  palette,
  src,
}:
let
  colours = lib.unique (
    lib.filter (v: builtins.isString v && builtins.match "#[0-9a-fA-F]{6}" v != null) (
      lib.attrValues palette
    )
  );
in
runCommand "miami-wind-wallpaper.png" { nativeBuildInputs = [ lutgen ]; } ''
  # lutgen wants writable config/cache dirs
  export HOME=$TMPDIR
  lutgen apply -o $out ${src} -- ${lib.escapeShellArgs colours}
''
