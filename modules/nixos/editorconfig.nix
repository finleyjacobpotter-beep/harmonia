# One EditorConfig for the whole machine: hosts, the Dionysus VM and the
# Nike/Zelus microVMs all import this. EditorConfig looks for .editorconfig
# in each parent directory of the file being edited, up to /, so linking it
# at /.editorconfig covers every file on the system. A project's own
# .editorconfig still wins for files inside it (and with `root = true`
# stops the search there).
#
# Neovim reads EditorConfig natively; so do most editors and prettier.
{ ... }:
{
  environment.etc."editorconfig".text = ''
    root = true

    # Everything: spaces, four wide. tab_width keeps literal tabs (Makefiles,
    # Go, files from elsewhere) the same width.
    [*]
    indent_style = space
    indent_size = 4
    tab_width = 4

    # YAML and JSON in all their flavours: two spaces.
    [*.{yml,yaml,json,jsonc,json5,jsonl,ndjson,geojson,topojson,webmanifest,har}]
    indent_style = space
    indent_size = 2

    # Extensionless JSON/YAML files.
    [{.prettierrc,.babelrc,.eslintrc,.jshintrc,.swcrc,flake.lock,.clang-format,.clang-tidy,.clangd}]
    indent_style = space
    indent_size = 2

    # Make needs real tabs.
    [{Makefile,makefile,GNUmakefile,BSDmakefile,Makefile.*,makefile.*,*.mk,*.mak,*.make}]
    indent_style = tab
  '';

  systemd.tmpfiles.rules = [ "L+ /.editorconfig - - - - /etc/editorconfig" ];
}
