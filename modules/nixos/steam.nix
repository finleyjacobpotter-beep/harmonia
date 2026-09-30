# Steam from Flathub, locked down as far as it will still run games.
#
# Steam, Proton and its prefixes live in ~/.var/app/com.valvesoftware.Steam.
# The only host directory it can see is ~/Games, which it shares with Lutris
# (gaming.nix) so a Steam library there can be launched from Lutris too.
# See docs/gaming.md.
{ ... }:
let
  steam = "com.valvesoftware.Steam";
in
{
  # Flathub itself and the weekly update timer come from flatpak.nix. The
  # manifest pulls in the runtime's 64- and 32-bit Mesa on its own.
  services.flatpak.packages = [
    {
      appId = steam;
      origin = "flathub";
    }
  ];

  # Anything not listed keeps the manifest default; "!" revokes.
  services.flatpak.overrides.${steam} = {
    Context = {
      filesystems = [
        # The one shared directory: put a Steam library at ~/Games/SteamLibrary.
        "~/Games:create"
        # Everything else Flathub hands out on top of Steam's own data dir:
        "!xdg-music"
        "!xdg-pictures"
        "!/mnt"
        "!/media"
        "!/run/media"
        "!xdg-run/app/com.discordapp.Discord"
        "!xdg-config/MangoHud"
        "!xdg-run/speech-dispatcher"
        # The PipeWire socket reaches cameras and screen capture without the
        # portal asking. Audio still works over the PulseAudio socket; Steam
        # game recording and Remote Play streaming don't.
        "!xdg-run/pipewire-0"
      ];
      # Raw Bluetooth sockets; Bluetooth controllers pair through the host
      # and show up as normal input devices.
      features = [ "!bluetooth" ];
      # Kept, because Steam breaks without them: network, X11 (the client and
      # most Proton games run under Xwayland), --device=all (controllers,
      # wheels, VR), /run/udev (controller hotplug), multiarch and devel
      # (32-bit games, Proton's own pressure-vessel container).
    };
    "System Bus Policy" = {
      # Wine uses UDisks2 to list (and mount) drives; games don't need it.
      "org.freedesktop.UDisks2" = "none";
    };
  };
}
