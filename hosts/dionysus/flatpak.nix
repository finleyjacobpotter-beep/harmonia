# Flatpak apps for Dionysus: Element everywhere, Zen on x86_64 only.
#
# Element (im.riot.Riot) ships both x86_64 and aarch64 builds on Flathub, so
# it works on either architecture — the sandbox tightening lives in the shared
# modules/nixos/element.nix (imported by hosts/dionysus/default.nix).
#
# Zen (app.zen_browser.zen) has no aarch64 build (upstream has no ARM64 Linux
# release and Flathub only carries x86_64), so it is added on x86_64 only; the
# aarch64 build falls back to the native Firefox in home/dionysus/dev.nix. The
# Zen tightening below mirrors modules/nixos/flatpak.nix on harmonia.
{ lib, pkgs, ... }:
let
  zen = "app.zen_browser.zen";
  onX86 = pkgs.stdenv.hostPlatform.isx86_64;
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
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };

    packages = lib.optionals onX86 [
      {
        appId = zen;
        origin = "flathub";
      }
    ];

    # Tighten Flathub's default permissions for Zen (x86_64 only).
    overrides = lib.optionalAttrs onX86 {
      ${zen} = {
        Context = {
          # No host / home access at all. The only host directory the browser
          # can touch is ~/Downloads/zen (created on demand).
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
          # Flathub grants --device=all (webcams, FIDO keys, ...). Only allow
          # the GPU. Remove "!all" here if you need a webcam or hardware key.
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
