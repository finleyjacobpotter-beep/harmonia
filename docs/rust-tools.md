# Rust tools

[`home/rust-tools.nix`](../home/rust-tools.nix) installs Rust replacements
for the classic commands on the host, [Nike](nike.md) and [Zelus](zelus.md),
and your interactive bash on all three aliases the classics to them:

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
(`CLAUDECODE` or `OPENCODE` set), which expect the classic tools; on Zelus
those agents get skills for the Rust tools instead.
