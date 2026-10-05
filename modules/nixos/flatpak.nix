# Firefox from Flathub, run inside a tightened flatpak sandbox ("browser jail"),
# on every host and both architectures (Flathub ships x86_64 and aarch64).
# Its theme and add-ons are in home/firefox.nix.
{ lib, ... }:
let
  firefox = "org.mozilla.firefox";

  # Flathub OSTree commit to pin Firefox to; null follows the latest Flathub
  # build. Read the current one on an installed machine with
  #   flatpak remote-info flathub org.mozilla.firefox   (the "Commit:" line)
  # A pinned app is never auto-updated; bump this by hand.
  firefoxCommit = null;
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
          appId = firefox;
          origin = "flathub";
        }
        // lib.optionalAttrs (firefoxCommit != null) { commit = firefoxCommit; }
      )
    ];
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };

    # Tighten Flathub's default permissions for Firefox. Anything not listed
    # keeps the manifest default; entries prefixed with "!" revoke a permission.
    overrides = {
      ${firefox} = {
        Context = {
          # No host / home access at all. The only host directory the browser can
          # touch is ~/Downloads/firefox (created on demand).
          filesystems = [
            "!host"
            "!home"
            "!xdg-download"
            "xdg-download/firefox:create"
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
  };
}
