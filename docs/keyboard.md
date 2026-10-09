# Keyboard

Everything is driven from the keyboard with vim-style keys. Each modifier
belongs to exactly one layer ([`keys.nix`](../keys.nix)), so layers never fight:

| Namespace | Owner | Notes |
| --- | --- | --- |
| `Super` + … | **sway** | nothing else binds Super |
| `Ctrl+Space` … | **tmux** prefix | no prefix-less tmux keys, so every other key reaches the program inside. `Ctrl+Space Ctrl+Space` sends a literal Ctrl+Space |
| `Ctrl+Shift` + … | **alacritty** | its Ctrl+= / Ctrl+- / Ctrl+0 defaults are passed through to programs instead |
| everything else | focused app | Firefox + Vimium, neovim, ranger, bash (vi mode), btop, pulsemixer, bluetuith… |

Firefox and tmux may share keys (only one has focus); CLI tools may never use
Super, Ctrl+Space or Ctrl+Shift. [`home/keymap.nix`](../home/keymap.nix) checks
this at build time: a sway binding without Super, a tmux `bind -n`, or an
alacritty binding outside Ctrl+Shift fails `nixos-rebuild`.

## sway (`Super`)

| Key | Action |
| --- | --- |
| `h` `j` `k` `l` | focus left/down/up/right |
| `Shift` + `h` `j` `k` `l` | move window |
| `Ctrl` + `h` / `l` | focus output left/right (`Ctrl+Shift`: move workspace there) |
| `1`…`0` / `Shift` + `1`…`0` | go to / move to workspace |
| `Tab`, `[`, `]` | last / previous / next workspace |
| `s` / `v` | split below / beside (like vim `:split` / `:vsplit`) |
| `t` / `Shift+t` / `e` | tabbed / stacking / toggle split layout |
| `f` | fullscreen |
| `space` / `Shift+space` | toggle focus tiling↔floating / toggle floating |
| `a` / `Shift+a` | focus parent / child |
| `-` / `Shift+-` | show scratchpad / move to scratchpad |
| `q` | close window |
| `Return` | alacritty |
| `d` | fuzzel launcher (`Ctrl+j`/`Ctrl+k` to move) |
| `n` / `Shift+n` / `Ctrl+n` / `i` | dismiss / dismiss all / restore / act on notification |
| `Shift+s` / `Ctrl+s` | screenshot region / screen to clipboard |
| `Shift+b` | toggle eww bar |
| `Shift+x` | lock |
| `Shift+c` | reload sway |

**Modes** (Esc or Return leaves; the eww bar shows the active mode and its keys):

| Enter | Mode | Keys |
| --- | --- | --- |
| `Super+r` | resize | `h` `j` `k` `l` (`Shift` = bigger steps) |
| `Super+o` | open | `b` Firefox · `f` ranger · `e` nvim · `t` tmux · `s` btop · `a` pulsemixer · `u` bluetuith · `n` nmtui · `v` Nike (ssh) · `g` Lutris · `Shift+g` Steam · `c` Element · `Shift+b` Blender · `d` Godot |
| `Super+m` | media | `j`/`k` volume · `m` mute · `Shift+m` mic · `h`/`l` prev/next · `p` play/pause · `Shift+j`/`Shift+k` brightness |
| `Super+Shift+e` | system | `l` lock · `e` exit sway · `s` suspend · `r` reboot · `Shift+p` power off |

Hardware keys (volume, media, brightness, Print) work as usual.

## tmux (`Ctrl+Space`, then…)

| Key | Action |
| --- | --- |
| `h` `j` `k` `l` / `H` `J` `K` `L` | select / resize pane (repeatable) |
| `s` / `v` | split below / beside |
| `c` / `n` / `p` / `Tab` | new / next / previous / last window |
| `q` / `Q` | kill pane / window |
| `w` / `S` | pick window / session |
| `<` / `>` | move window left/right |
| `z` | zoom pane |
| `Escape` or `[` | copy mode: vim motions, `v` select, `Ctrl+v` block, `y` yank |
| `P` | paste |
| `d` | detach |
| `r` | reload config |

## alacritty (`Ctrl+Shift`)

`C`/`V` copy/paste · `F`/`B` search · `Space` vi mode (scrollback with hjkl) ·
`O` open a URL by hint · `K`/`J`/`0` font bigger/smaller/reset · `N` new window.

## Apps

- **Firefox**: [Vimium](https://github.com/philc/vimium), see
  [Firefox (Vimium)](#firefox-vimium) below.
- **bash**: readline vi mode (`Esc` for normal mode; cursor is a bar in
  insert mode, a block in normal mode). `Ctrl+r` fzf history, `Ctrl+t` fzf files.
- **neovim**: leader is `Space` (`which-key` shows the rest). `Space f f/g/b`
  telescope, `Space s`/`Space v` split, `Ctrl+w h/j/k/l` between windows.
- **ranger**, **btop**, **pulsemixer**, **bluetuith**, **fzf**, **less**: vim
  keys (`btop` has `vim_keys` turned on).
- **nmtui** is keyboard-driven but doesn't use vim keys.

## Firefox (Vimium)

[Vimium](https://github.com/philc/vimium) is installed into each Firefox profile
with its default bindings (none are remapped). Keys are case-sensitive, and
`?` shows the full list in the browser.

**Scrolling and page**

| Key | Action |
| --- | --- |
| `j` / `k` | scroll down / up |
| `h` / `l` | scroll left / right |
| `d` / `u` | half page down / up |
| `gg` / `G` | top / bottom of the page |
| `r` | reload |
| `yy` | copy the page URL |
| `gs` | view source |
| `gi` | focus the first text input |
| `gu` / `gU` | go up one level in the URL / to the site root |

**Links**

| Key | Action |
| --- | --- |
| `f` / `F` | open a link / open it in a new tab (type the hint letters) |
| `yf` | copy a link's URL |
| `[[` / `]]` | previous / next page (follows "prev"/"next" links) |

**Find**

| Key | Action |
| --- | --- |
| `/` | find on page (`Enter` to confirm) |
| `n` / `N` | next / previous match |

**Opening and history**

| Key | Action |
| --- | --- |
| `o` / `O` | open a URL, bookmark or history entry / in a new tab |
| `b` / `B` | open a bookmark / in a new tab |
| `H` / `L` | back / forward |
| `p` / `P` | open the clipboard URL / in a new tab |

**Tabs**

| Key | Action |
| --- | --- |
| `J` / `K` | previous / next tab (`gT` / `gt` work too) |
| `g0` / `g$` | first / last tab |
| `^` | last visited tab |
| `T` | search open tabs |
| `t` | new tab |
| `yt` | duplicate tab |
| `x` / `X` | close tab / restore closed tab |
| `<<` / `>>` | move tab left / right |
| `alt-p` | pin / unpin tab |

**Modes**

| Key | Action |
| --- | --- |
| `i` | insert mode: keys go to the page until `Esc` |
| `v` / `V` | visual / visual line mode (`y` copies the selection) |
| `Esc` | leave any mode, close the hint or find bar |

Vimium can't run on `about:` pages (new tab, settings). Use Firefox's own keys
there: `Ctrl+L` address bar, `Ctrl+T` new tab, `Ctrl+W` close tab,
`Ctrl+Tab` next tab.

## Mouse

The pointer hides as soon as you type and comes back when the mouse moves
(sway `hide_cursor when-typing`).

## Idle

The screen locks after 10 minutes idle and turns off after 15 (swayidle,
`home/sway.nix`); it also locks before suspend. The coffee cup on the eww bar
is a caffeine toggle: click it to stop swayidle (cup filled, orange), so
nothing locks or blanks, and click again to bring the timers back. While
caffeine is on, suspending doesn't lock either.
