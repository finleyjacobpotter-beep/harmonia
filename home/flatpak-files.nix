# Files for flatpak sandboxes. Flatpak apps can't see the host's
# ~/.local/share or ~/.config, or follow symlinks into /nix/store, so themes,
# configs and add-ons are *copied* into each app's own data and config dirs
# (~/.var/app/<id>, which GTK in the sandbox uses as XDG_DATA_HOME and
# XDG_CONFIG_HOME). Modules list what they need:
#
#   harmonia.flatpakFiles.".var/app/im.riot.Riot/config/Element/config.json" = configFile;
#   harmonia.firefoxProfileFiles."user.js" = userJs;   # into every Firefox profile
#
# One command, `flatpak-miami-wind` (home/flatpak-files.py), copies them all;
# it runs on every rebuild. Directories are recopied only when their store
# path changes.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  pyScript = import ../lib/python-script.nix { inherit pkgs lib; };

  # A package or a "${pkg}/sub/dir" string.
  storePath = lib.types.coercedTo lib.types.package toString lib.types.str;

  manifest = pkgs.writeText "flatpak-files.json" (
    builtins.toJSON {
      copies = config.harmonia.flatpakFiles;
      firefoxProfile = config.harmonia.firefoxProfileFiles;
    }
  );

  sync = pyScript "flatpak-miami-wind" {
    wrapperArgs = [
      "--add-flags"
      manifest
    ];
  } ./flatpak-files.py;
in
{
  options.harmonia = {
    flatpakFiles = lib.mkOption {
      type = lib.types.attrsOf storePath;
      default = { };
      description = "Store paths to copy, by destination under ~.";
    };
    firefoxProfileFiles = lib.mkOption {
      type = lib.types.attrsOf storePath;
      default = { };
      description = "Store paths to copy into every Firefox profile.";
    };
  };

  config = {
    home.packages = [ sync ];
    # The command's old name.
    programs.bash.shellAliases.firefox-miami-wind = "flatpak-miami-wind";

    home.activation.flatpakMiamiWind = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${sync}/bin/flatpak-miami-wind || true
    '';
  };
}
