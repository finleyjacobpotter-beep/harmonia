# Firefox jail

Firefox comes from Flathub via [nix-flatpak](https://github.com/gmodena/nix-flatpak),
on every host (x86_64 and aarch64). On top of the Flathub manifest,
`modules/nixos/flatpak.nix` revokes:

- all host and home filesystem access — the only host path is `~/Downloads/firefox`
- the X11 socket (Wayland only), CUPS and smartcard sockets
- all devices except the GPU (`dri`). Remove `"!all"` if you need a webcam or
  a FIDO/U2F key.

Check the effective permissions with `flatpak info --show-permissions org.mozilla.firefox`.
Open it with `Super+o b`, or `firefox` in a shell.

## What `home/firefox.nix` sets up

- **Vertical tabs**: Firefox's own sidebar tab strip (`sidebar.verticalTabs`),
  always shown.
- **[uBlock Origin](https://github.com/gorhill/uBlock)** for ads and trackers,
  with its default filter lists.
- **[Vimium](https://github.com/philc/vimium)** (keys in
  [keyboard.md](keyboard.md#firefox-vimium)).
- **Miami Wind** on the toolbar, tab strip, menus and `about:` pages, and on
  Vimium's link hints, find bar (HUD) and Vomnibar.

Both add-ons are pinned (`docs/versions.md`) and side-loaded, so they are
enabled without a prompt and update only when the pin is bumped.

All of it is copied into each Firefox profile as `userChrome.css`,
`userContent.css`, `user.js` and `extensions/*.xpi`. Profiles only exist after
Firefox has been started once, so after the first launch run
`flatpak-miami-wind` (it also runs on every rebuild; `firefox-miami-wind` is
the same command) and restart Firefox.
