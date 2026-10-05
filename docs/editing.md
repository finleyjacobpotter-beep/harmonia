# Editing: EditorConfig and JSON/YAML in Neovim

## EditorConfig

Every machine (harmonia, Cadmus, Dionysus, and the Nike and Zelus microVMs)
gets the same EditorConfig from `modules/nixos/editorconfig.nix`. It is
written to `/etc/editorconfig` and linked to `/.editorconfig`, the top of the
directory tree, so it applies to every file on the system:

| Files | Indent |
| --- | --- |
| everything | 4 spaces (tabs shown 4 wide) |
| YAML and JSON: `*.yml`, `*.yaml`, `*.json`, `*.jsonc`, `*.json5`, `*.jsonl`, `*.ndjson`, `*.geojson`, `*.topojson`, `*.webmanifest`, `*.har`, plus `flake.lock`, `.prettierrc`, `.babelrc`, `.eslintrc`, `.jshintrc`, `.swcrc`, `.clang-format`, `.clang-tidy`, `.clangd` | 2 spaces |
| Make: `Makefile`, `makefile`, `GNUmakefile`, `BSDmakefile`, `Makefile.*`, `makefile.*`, `*.mk`, `*.mak`, `*.make` | tabs |

Neovim applies it on its own (built-in EditorConfig support), as do most
editors and prettier. A project's own `.editorconfig` takes precedence for
files inside that project.

## JSON and YAML in Neovim

Commands work on the whole buffer, or on a range or visual selection (for
JSON pasted into another file). They replace the text in place; after a
whole-buffer conversion the filetype switches, and `:saveas name.yaml`
saves it under the new extension.

| Command | Keys | Does |
| --- | --- | --- |
| `:JsonPretty` | `<leader>jp` | Serialized or minified JSON to indented JSON. Also unwraps stringified JSON, with or without the outer quotes (`"{\"a\":1}"` or `{\"a\":1}`), however many times it was stringified |
| `:JsonMinify` | `<leader>jm` | JSON to one line |
| `:JsonSerialize` | `<leader>js` | JSON to a one-line JSON string (`"{\"a\":1}"`) |
| `:JsonToYaml` | `<leader>jy` | JSON to YAML |
| `:YamlToJson` | `<leader>jj` | YAML to JSON |
| `:Prettier` | `<leader>jf` | Format with prettier (JSON, YAML, Markdown, JS, CSS, HTML, …) |

Key order and large numbers are kept. `jq` does the JSON work and `yq`
(mikefarah's) the YAML conversion, since prettier formats but cannot
convert or unminify (it keeps a minified object on one line if it fits).
All three tools are on Neovim's PATH only. Errors show as a message and
leave the text untouched.
