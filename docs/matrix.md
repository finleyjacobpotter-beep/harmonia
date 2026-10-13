# Matrix

Matrix runs in the terminal: [iamb](https://iamb.chat), a client with vim
keys, on `Super+o c` (`home/iamb.nix`). Calls go through
[Element Call](https://call.element.io) in Firefox. Every host has both.

## iamb

iamb draws with the terminal's colours, so alacritty's Miami Wind theme
covers it. It sends desktop notifications through mako, so they collect on
the dash's notifications tile and stay quiet while focus is on
([the dash](bar.md#tiles)). It reopens the rooms and splits you had open
last time.

iamb won't start without a profile naming your account, so harmonia writes
its config only once you give it your Matrix ID, in `home/default.nix` (or
`home/dionysus/default.nix`):

```nix
harmonia.matrix.userId = "@you:matrix.org";
```

After a rebuild, `Super+o c` opens iamb, which asks for your password or
single sign-on the first time and then verifies this session like any new
device. Its session and message keys are kept in `~/.local/share/iamb`.

A few keys to start with (`:help` in iamb has the rest):

| Key | |
|---|---|
| `:join #room:server` | join a room |
| `Ctrl+w h j k l` | move between windows, as in vim |
| `i` / `Esc` | write a message / back to normal mode |
| `:rooms`, `:dms` | list rooms, direct messages |
| `:verify request @user:server` | verify another session |
| `:upload <path>` | send a file |
| `:quit` | quit |

## Calls: Element Call in Firefox

For voice and video calls, open [call.element.io](https://call.element.io)
(or a call link someone sends you) in Firefox. Firefox's sandbox already
lets it use the microphone and camera (`modules/nixos/flatpak.nix`), behind
its own per-site prompt, and it shares a screen or window through sway's
screen-sharing portal. While a call is recording, the dash's sound tile
says so in red.

## Coming from Element

The Element Flatpak and its theme are gone from the config. Its data, which
holds your session and the keys to old encrypted messages, stays in
`~/.var/app/im.riot.Riot` until you remove it. Before that, export the keys
in Element (Settings, Security & Privacy, **Export E2E room keys**) and
import them in iamb with `:keys import <file> <passphrase>`, or verify iamb
from another session that has them. Then

```sh
sudo harmonia-cleanup --apply --user-files
```

uninstalls the Flatpak and deletes its data, along with the other leftovers
it knows about (without `--user-files` it removes the app but keeps the
data).
