# Zen browser jail

Zen comes from Flathub via [nix-flatpak](https://github.com/gmodena/nix-flatpak).
On top of the Flathub manifest, `modules/nixos/flatpak.nix` revokes:

- all host and home filesystem access — the only host path is `~/Downloads/zen`
- the X11 socket (Wayland only), CUPS and smartcard sockets
- all devices except the GPU (`dri`). Remove `"!all"` if you need a webcam or
  a FIDO/U2F key.

Check the effective permissions with `flatpak info --show-permissions app.zen_browser.zen`.

The browser is themed via `userChrome.css`/`userContent.css`/`user.js` copied
into each Zen profile. Profiles only exist after Zen has been started once, so
after the first launch run `zen-miami-wind` (it also runs on every rebuild) and
restart Zen. The same step installs the Vimium extension.
