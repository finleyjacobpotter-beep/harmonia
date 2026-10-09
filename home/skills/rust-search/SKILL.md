---
name: rust-search
description: Find files and code fast with ripgrep (rg), fd and ast-grep. Use when searching a codebase for text, symbols, call sites or files by name, type or age, or when grep/find would be slow or noisy.
---

# Searching with rg, fd and ast-grep

These are installed here. The shell aliases (`grep` → `rg`, `find` → `fd`) only exist in the user's interactive shell, so call the tools by their own names.

## Text: `rg` (ripgrep)

Respects `.gitignore`, skips hidden and binary files, searches recursively by default.

```sh
rg 'TODO|FIXME'                      # in the current tree
rg -n -C2 'fn parse' src/            # line numbers, 2 lines of context
rg -t rust -t toml 'serde'           # by file type (rg --type-list)
rg -g '*.gd' -g '!addons/**' 'signal' # by glob, with exclusions
rg -l 'unwrap\(\)'                   # file names only
rg -c 'import' --sort path           # count per file
rg -F 'a.b(c)'                       # fixed string, no regex
rg -uu 'secret'                      # include ignored and hidden files
rg --json 'pattern' | jaq -c 'select(.type=="match") | .data.path.text'
```

## Files: `fd`

```sh
fd config                    # names containing "config"
fd -e py -e pyi              # by extension
fd -t d build                # directories only
fd -H -E .git '^\.env'       # include hidden files, exclude .git
fd --changed-within 1d       # touched in the last day
fd -e png -x magick {} {.}.webp   # run a command per result ({}, {.}, {/})
```

## Code structure: `ast-grep`

Matches syntax, not text, so formatting and comments don't break a match. `$X` matches one node, `$$$ARGS` any number.

```sh
ast-grep run -l rust -p 'unwrap()'                  # every .unwrap()
ast-grep run -l ts -p 'console.log($$$)'            # calls with any args
ast-grep run -l python -p 'def $F($$$ARGS) -> $R: $$$BODY' --json=compact | jaq -r '.[].metaVariables.single.F.text'   # annotated defs; drop `-> $R` for the rest
```

Use `rg` first for speed. Switch to `ast-grep` when text matches give false positives (strings, comments, similar names) or when the next step is a rewrite (see the rust-edit skill).
