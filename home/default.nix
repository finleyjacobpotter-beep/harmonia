# The home for harmonia and cadmus: the shared home (./base.nix) plus the
# flatpak theme sync and the Rust tools.
{ pkgs, ... }:
{
  imports = [
    ./base.nix
    ./flatpak-theme.nix
    ./rust-tools.nix
    ./blender-addons.nix
  ];

  # Python package manager; provides `uv` and `uvx` (run a tool from PyPI
  # without installing it).
  home.packages = [ pkgs.uv ];

  # Your Matrix account, for iamb's profile (home/iamb.nix).
  harmonia.matrix.userId = "@fj:iojoi.cc";

  # Your Bitwarden server, for bw and the Firefox add-on (home/secrets.nix).
  harmonia.bitwarden.server = "https://vault.iojoi.cc";

  # Your git identity (home/dionysus/default.nix sets Dionysus's).
  programs.git.settings.user = {
    name = "fj";
    email = "fj@iojoi.cc";
  };
}
