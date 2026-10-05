# The home for harmonia and cadmus: the shared home (./base.nix) plus the
# flatpak theme sync and the Rust tools.
{ pkgs, ... }:
{
  imports = [
    ./base.nix
    ./flatpak-theme.nix
    ./rust-tools.nix
  ];

  # Python package manager; provides `uv` and `uvx` (run a tool from PyPI
  # without installing it).
  home.packages = [ pkgs.uv ];
}
