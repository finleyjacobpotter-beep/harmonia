# The Flathub apps, each declared once with its sandbox and launcher key:
#
#   harmonia.apps."im.riot.Riot" = {
#     name = "element";  # its word in the open mode's hint on the bar
#     key = "c";         # Super+o, then c, opens it (home/open-mode.nix)
#     wayland = true;    # no X11 socket (Wayland only)
#     sandbox = { ... }; # flatpak overrides on top; "!" revokes
#   };
#
# Each becomes a services.flatpak package and override (nix-flatpak), and
# sway's open mode and the bar's hint are built from the same list, so a
# host only gets keys for the apps it installs. Flathub itself and the
# weekly update timer are here too. Native programs get open-mode keys the
# same way, without the Flatpak parts:
#
#   harmonia.launchers.blender = { key = "Shift+b"; exec = "blender"; };
#
# Firefox, on every host and both architectures (Flathub ships x86_64 and
# aarch64), runs in a tightened sandbox ("browser jail"). Its theme and
# add-ons are in home/firefox.nix.
{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.harmonia.apps;

  # `wayland = true`: no X11 socket to snoop on (or be snooped by) other
  # clients.
  waylandSockets = [
    "wayland"
    "!x11"
    "!fallback-x11"
  ];

  # Flathub OSTree commit to pin Firefox to; null follows the latest Flathub
  # build. Read the current one on an installed machine with
  #   flatpak remote-info flathub org.mozilla.firefox   (the "Commit:" line)
  # A pinned app is never auto-updated; bump this by hand.
  firefoxCommit = null;
in
{
  options.harmonia.apps = mkOption {
    default = { };
    description = "Flathub apps by app ID.";
    type = types.attrsOf (
      types.submodule {
        options = {
          name = mkOption { type = types.str; };
          key = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Its key in sway's open mode (Super+o).";
          };
          commit = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          wayland = mkOption {
            type = types.bool;
            default = false;
          };
          sandbox = mkOption {
            # Lists (sockets, filesystems, ...) from several modules add up.
            type = types.attrsOf (types.attrsOf (types.either (types.listOf types.str) types.str));
            default = { };
          };
        };
      }
    );
  };

  options.harmonia.launchers = mkOption {
    default = { };
    description = "Native programs in sway's open mode (Super+o), by name.";
    type = types.attrsOf (
      types.submodule {
        options = {
          key = mkOption { type = types.str; };
          exec = mkOption { type = types.str; };
        };
      }
    );
  };

  config = {
    services.flatpak = {
      enable = true;
      remotes = [
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
      ];
      packages = lib.mapAttrsToList (
        appId: app:
        {
          inherit appId;
          origin = "flathub";
        }
        // lib.optionalAttrs (app.commit != null) { inherit (app) commit; }
      ) cfg;
      update.auto = {
        enable = true;
        onCalendar = "weekly";
      };
      overrides = lib.mapAttrs (
        _: app:
        app.sandbox
        // lib.optionalAttrs app.wayland {
          Context = app.sandbox.Context or { } // {
            sockets = waylandSockets ++ app.sandbox.Context.sockets or [ ];
          };
        }
      ) (lib.filterAttrs (_: app: app.wayland || app.sandbox != { }) cfg);
    };

    harmonia.apps."org.mozilla.firefox" = {
      name = "firefox";
      key = "b";
      commit = firefoxCommit;
      wayland = true;
      # Tighten Flathub's default permissions. Anything not listed keeps the
      # manifest default.
      sandbox = {
        Context = {
          # No host / home access at all. The only host directory the browser can
          # touch is ~/Downloads/firefox (created on demand).
          filesystems = [
            "!host"
            "!home"
            "!xdg-download"
            "xdg-download/firefox:create"
          ];
          sockets = [
            "pulseaudio"
            "!pcsc"
            "!cups"
          ];
          # All devices, as Flathub ships it: Firefox reaches a YubiKey or
          # other FIDO2/U2F security key through /dev/hidraw*, and flatpak has
          # no narrower device class that includes it. Set explicitly so it
          # replaces the "!all" earlier builds wrote. Webcams and microphones
          # are still behind Firefox's own per-site permission prompts.
          devices = [ "all" ];
        };
        Environment = {
          MOZ_ENABLE_WAYLAND = "1";
          GTK_THEME = "Adwaita:dark";
          # Open profiles.ini's default profile, which flatpak-miami-wind
          # makes and themes before the first start (home/flatpak-files.py),
          # instead of a fresh per-install one it hasn't seen.
          MOZ_LEGACY_PROFILES = "1";
        };
      };
    };
  };
}
