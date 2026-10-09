# Rust tools

[`home/rust-tools.nix`](../home/rust-tools.nix) installs Rust replacements
for the classic commands on the host and [Nike](nike.md),
and your interactive bash on both aliases the classics to them:

| Command | Runs |
| --- | --- |
| `grep` | `rg` (ripgrep) |
| `find` | `fd` |
| `cat` | `bat --paging=never --style=plain` |
| `ls`, `ll`, `la`, `tree` | `eza` |
| `du` | `dust` |
| `df` | `dysk` |
| `top` | `btm` (bottom; `btop` is still there by name) |
| `ps` | `procs` |
| `diff` | `difft` (difftastic) |
| `cd` | zoxide (`cd proj` jumps to the best match) |

The flags differ from the originals (`find . -name x` is `fd x`), so the old
command is still there as `command grep` or `\grep`. `git diff`, `log` and
`show` page through delta, and bat and delta use the terminal's Miami Wind
colours (each machine's own accent).

Also installed, without aliases: `sd` (find and replace, like `sed s///`),
`ast-grep` (structural search and rewrite), `jaq` (jq), `xh` (HTTP),
`hyperfine` (benchmarks), `tokei` (lines of code), `watchexec` (rerun on
changes), `just` (task runner), `ouch` (archives), `choose` (pick fields) and
`tldr`. `sed` and `curl` keep their names, since `sd` and `xh` take different
arguments.

The aliases are skipped in shells started by Claude Code or opencode
(`CLAUDECODE` or `OPENCODE` set), which expect the classic tools. On harmonia
those agents get three skills that say when to use which Rust tool instead:
`rust-search` (rg, fd, ast-grep), `rust-edit` (sd, ast-grep rewrites, jaq,
difft) and `rust-inspect` (tokei, dust, procs, hyperfine, xh, just, ouch).
They're in [`home/skills/`](../home/skills), installed into
`~/.claude/skills` by [`home/gamedev.nix`](../home/gamedev.nix); opencode
reads them there too.
