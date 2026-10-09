# harmonia

A NixOS flake: the hosts harmonia (desktop), cadmus (laptop) and Dionysus,
with home-manager for the user, all themed Miami Wind. README.md has the
layout; docs/ is the documentation site (mkdocs).

- Read the docs page for whatever you change (docs/<topic>.md, linked from
  README.md) and keep it true: a change isn't done until its docs, README.md
  and docs/layout.md say what the code does.
- Pin everything: flake inputs to a commit (with the branch and date in a
  comment), packages and servers to a release. docs/versions.md lists the
  pins.
- Comments say why, in plain sentences, and name the file that holds the
  other half (`home/gamedev.nix`, `modules/nixos/llama-server.nix`).
- Before committing: `nix fmt`, then
  `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`
  for each host you touched, and `nix build .#docs` when docs changed.
- `hosts/*/hardware-configuration.nix` belong to each machine; don't edit
  or commit them.
- Applying a change takes `sudo nixos-rebuild switch --flake .#<host>`;
  leave that to the user.
- Agent instructions live in `.agents/` (this file); `CLAUDE.md` only
  points here. Nothing goes in `.omo/`.
