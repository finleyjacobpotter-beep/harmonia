# Element

[Element](https://element.io/), the Matrix client, comes from Flathub
(`im.riot.Riot`) and runs in a locked-down Flatpak sandbox. Start it with
`Super+o c` or from fuzzel.

## The jail

Flathub's Element is already tight: no host or home directory access at all
(files are opened and saved through the portal's file picker, one file at a
time), and only the GPU as a device. On top of that,
[`modules/nixos/element.nix`](../modules/nixos/element.nix) revokes:

- the X11 socket: Element runs as a native Wayland app, so it can't see other
  windows and X11 apps can't see it
- the shared IPC namespace (only X11 needs it)
- the Ubuntu launcher badge API

It keeps network, audio, the GPU and the keyring socket (Element stores its
login there, so you stay signed in). Cameras and screen sharing for calls go
through the portal and ask first.

Check the effective permissions with
`flatpak info --show-permissions im.riot.Riot`.

## Theme

[`home/element.nix`](../home/element.nix) writes a `config.json` into the
sandbox that defines a **Miami Wind** theme (palette colours and
DepartureMono) and makes it the default. Element follows the system's dark
mode until you pick a theme yourself, so the first time, open
*Settings → Appearance* and choose **Miami Wind**. It sticks after that.
