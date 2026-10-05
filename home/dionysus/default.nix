# Dionysus's home: the same Sway desktop as harmonia (../base.nix) plus its
# native dev tools (./dev.nix). The flatpak-only pieces (the flatpak theme
# sync and the flatpak opencode launcher) are left out, because Dionysus runs
# its dev tools natively and must build on aarch64 as well as x86_64.
{
  imports = [
    ../base.nix
    ./dev.nix
  ];

  # Both architectures are called dionysus, so name the x86_64 output.
  programs.bash.shellAliases.rebuild = "sudo nixos-rebuild switch --flake ~/harmonia#dionysus";
}
