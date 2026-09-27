# Zen browser from Flathub, run inside a tightened flatpak sandbox ("browser jail").
{ lib, ... }:
let
  zen = "app.zen_browser.zen";

  # Flathub OSTree commit to pin Zen to; null follows the latest Flathub build.
  # Read the current one on an installed machine with
  #   flatpak remote-info flathub app.zen_browser.zen   (the "Commit:" line)
  # A pinned app is never auto-updated; bump this by hand.
  zenCommit = null;
in
{
  services.flatpak = {
    enable = true;
    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];
    packages = [
      (
        {
          appId = zen;
          origin = "flathub";
        }
        // lib.optionalAttrs (zenCommit != null) { commit = zenCommit; }
      )
    ];
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };

    # Tighten Flathub's default permissions for Zen. Anything not listed keeps
    # the manifest default; entries prefixed with "!" revoke a permission.
    overrides.${zen} = {
      Context = {
        # No host / home access at all. The only host directory the browser can
        # touch is ~/Downloads/zen (created on demand).
        filesystems = [
          "!host"
          "!home"
          "!xdg-download"
          "xdg-download/zen:create"
        ];
        # Wayland only — no X11 socket to snoop on other clients.
        sockets = [
          "wayland"
          "pulseaudio"
          "!x11"
          "!fallback-x11"
          "!pcsc"
          "!cups"
        ];
        # Flathub grants --device=all (webcams, FIDO keys, ...). Only allow the
        # GPU. Remove "!all" here if you need a webcam or hardware security key.
        devices = [
          "!all"
          "dri"
        ];
      };
      Environment = {
        MOZ_ENABLE_WAYLAND = "1";
        GTK_THEME = "Adwaita:dark";
      };
    };
  };
}
