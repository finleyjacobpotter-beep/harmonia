# Dionysus's home: the same Sway desktop as harmonia (../base.nix) plus its
# native dev tools (./dev.nix). The flatpak-only pieces (the flatpak theme
# sync and the flatpak opencode launcher) are left out, because Dionysus runs
# its dev tools natively and must build on aarch64 as well as x86_64.
{ lib, system, ... }:
let
  output = "dionysus" + lib.optionalString (system == "aarch64-linux") "-aarch64";
in
{
  imports = [
    ../base.nix
    ./dev.nix
  ];

  # Both architectures are called dionysus, so a bare `--flake ~/harmonia`
  # always picks the x86_64 output; name this machine's output instead.
  programs.bash.shellAliases.rebuild = "sudo nixos-rebuild switch --flake ~/harmonia#${output}";

  # This machine's git identity (git itself is enabled system-wide by
  # modules/nixos/git-lfs.nix).
  programs.git = {
    enable = true;
    settings.user = {
      name = "Dionysus";
      email = "dionysus@localhost.local";
    };
  };
}
