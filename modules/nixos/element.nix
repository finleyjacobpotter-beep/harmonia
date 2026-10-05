# Element (Matrix client) from Flathub, run inside a locked-down flatpak
# sandbox ("chat jail"). The Miami Wind theme is in home/element.nix.
{
  # Flathub's Element already has no host or home access, only the GPU, and
  # opens and saves files through the portal. On top of that it is Wayland
  # only (modules/nixos/flatpak.nix):
  harmonia.apps."im.riot.Riot" = {
    name = "element";
    key = "c";
    wayland = true;
    sandbox = {
      Context = {
        sockets = [ "pulseaudio" ];
        # No shared IPC namespace (only X11 needs it).
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
  };
}
