---
name: rust-edit
description: Make bulk or structural edits with sd, ast-grep rewrites and jaq, and review them with difftastic (difft). Use for find-and-replace across many files, renaming a function or call pattern, editing JSON, or checking what an edit changed.
---

# Editing with sd, ast-grep, jaq and difft

These are installed here. Call them by name (the user's `diff` → `difft` alias isn't in agent shells). Preview first, then apply, then review the diff.

## Replace text: `sd`

Like `sed s///`, with normal regex syntax (no escaping of `(`, `+`, `|`) and `$1` for groups. It edits files in place when given paths.

```sh
sd -p 'old_name' 'new_name' src/lib.rs          # preview only
sd 'old_name' 'new_name' $(rg -l old_name)      # apply to every file that matches
sd -F 'a.b(' 'a.c(' file.py                     # fixed strings
sd '(\w+)_v1\b' '${1}_v2' config.toml           # capture groups
echo 'x=1' | sd '=' ': '                        # as a filter
```

## Rewrite code: `ast-grep`

Safer than regex for code: it only touches real syntax nodes.

```sh
ast-grep run -l rust -p '$X.unwrap()' -r '$X?'                 # show the rewrite
ast-grep run -l rust -p '$X.unwrap()' -r '$X?' -U              # apply to all
ast-grep run -l ts -p 'oldFn($$$A)' -r 'newFn($$$A)' src/ -U
```

## JSON: `jaq`

jq's language, faster and stricter.

```sh
jaq '.dependencies | keys' package.json
jaq -c '.items[] | select(.enabled) | {id, name}' data.json
jaq '.version = "1.2.0"' package.json > package.json.new && mv package.json.new package.json
```

## Review: `difft` and `delta`

```sh
difft old.rs new.rs                  # diff by syntax, ignores reformatting
GIT_EXTERNAL_DIFF=difft git diff     # the working tree, structurally
git diff --stat && git diff          # git's own pager here is delta
```

Check the result with the project's own build or tests after any bulk edit.
