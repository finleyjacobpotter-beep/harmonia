# Element (Matrix client) from Flathub, run inside a locked-down flatpak
# sandbox ("chat jail"). The Miami Wind theme is in home/element.nix.
{ ... }:
let
  element = "im.riot.Riot";
in
{
  # Flathub itself and the weekly update timer come from flatpak.nix.
  services.flatpak.packages = [
    {
      appId = element;
      origin = "flathub";
    }
  ];

  # Flathub's Element already has no host or home access, only the GPU, and
  # opens and saves files through the portal. On top of that:
  services.flatpak.overrides.${element} = {
    Context = {
      # Wayland only: no X11 socket to snoop on (or be snooped by) other
      # clients, and no shared IPC namespace (only X11 needs it).
      sockets = [
        "wayland"
        "pulseaudio"
        "!x11"
        "!fallback-x11"
      ];
      shared = [
        "network"
        "!ipc"
      ];
      # Keep the manifest's "dri" (GPU only). Cameras for calls go through
      # the PipeWire camera portal and ask first.
      devices = [ "dri" ];
    };
    "Session Bus Policy" = {
      # Ubuntu launcher badge API; nothing on sway uses it.
      "com.canonical.Unity" = "none";
    };
    Environment = {
      # element.sh only picks Wayland when this says so; greetd doesn't set it.
      XDG_SESSION_TYPE = "wayland";
    };
  };
}
