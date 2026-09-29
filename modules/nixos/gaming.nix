# Steam from Flathub, run inside a tightened flatpak sandbox ("game jail").
#
# Steam, Proton and every game it installs live in
# ~/.var/app/com.valvesoftware.Steam and cannot see the rest of your home
# directory. See docs/gaming.md for what the jail does and doesn't stop.
{ username, ... }:
let
  steam = "com.valvesoftware.Steam";
in
{
  # Flathub itself and the weekly update timer come from flatpak.nix.
  services.flatpak.packages = [
    {
      appId = steam;
      origin = "flathub";
    }
  ];

  # Tighten Flathub's default permissions for Steam. Anything not listed keeps
  # the manifest default; entries prefixed with "!" revoke a permission.
  # The manifest already gives Steam no host or home access: its home is its
  # own ~/.var/app directory. These revoke the extra holes it does punch.
  services.flatpak.overrides.${steam} = {
    Context = {
      filesystems = [
        # Read access to your music and pictures.
        "!xdg-music"
        "!xdg-pictures"
        # Read-write access to removable drives and anything under /mnt.
        # To keep a library on another drive, add just that path back,
        # e.g. "/mnt/games" (see docs/gaming.md).
        "!/mnt"
        "!/media"
        "!/run/media"
        # Discord rich-presence socket.
        "!xdg-run/app/com.discordapp.Discord"
      ];
      # X11 stays: the Steam client and most Proton games are X11-only and
      # run under Xwayland. Only other Xwayland windows are visible to them;
      # native Wayland apps (alacritty, Zen) are not.
      # --device=all also stays: controllers, wheels and VR headsets need
      # the raw hidraw/input devices.
    };
    # Wine uses UDisks2 to list (and mount) drives; games don't need it.
    "System Bus Policy" = {
      "org.freedesktop.UDisks2" = "none";
    };
  };

  # udev rules so the sandbox can use Steam Controllers, DualShock/DualSense,
  # Switch Pro and Valve Index hardware (MIT; not the unfree steam package).
  hardware.steam-hardware.enable = true;

  # Feral GameMode on the host; sandboxed games reach it through the
  # xdg-desktop-portal GameMode portal. Add `gamemoderun %command%` to a
  # game's launch options to use it.
  programs.gamemode.enable = true;
  users.users.${username}.extraGroups = [ "gamemode" ];
}
