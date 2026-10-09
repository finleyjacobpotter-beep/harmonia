---
name: rust-inspect
description: Inspect and measure on Zelus with tokei, dust, dysk, procs, hyperfine, xh, just, ouch and watchexec. Use to size up a codebase, find what fills a disk, check processes, benchmark commands, call an HTTP API, run project tasks or unpack archives.
---

# Inspecting and measuring

These are installed on Zelus; call them by name.

| Task | Command |
| --- | --- |
| Languages and lines of code | `tokei`, `tokei -o json src/` |
| What's using disk space | `dust -d 2`, `dust -r ~/Projects` |
| Free space per filesystem | `dysk` |
| Processes | `procs`, `procs godot`, `procs --tree` |
| Benchmark commands | `hyperfine --warmup 3 'cmd a' 'cmd b'`, `hyperfine -N --export-json out.json 'cmd'` |
| HTTP APIs | `xh get example.com/api q==term`, `xh post example.com/api key=value`, `xh -b url` (body only) |
| Project tasks | `just --list`, then `just <task>` |
| Archives | `ouch list f.tar.zst`, `ouch decompress f.zip -d out/`, `ouch compress dir out.tar.gz` |
| Pick fields | `procs --no-header \| choose 0 3`, like `cut`/`awk '{print}'` |
| Command examples | `tldr <command>` (run `tldr --update` once) |

`watchexec -e rs,toml -- cargo test` reruns on changes, and `btm` is an interactive monitor. Both run until stopped, so only start them in the background or in a tmux window the user can see, never as a blocking command.

The host's local model server is at `http://10.20.1.1:1234/v1` from Zelus (`xh :1234` won't reach it; use the full address), and only in the permissive and local-inference firewall modes.
