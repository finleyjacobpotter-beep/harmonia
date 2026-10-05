# Lutris from Flathub, run inside a tightened flatpak sandbox ("game jail").
#
# Lutris, Wine, every prefix and every game live in
# ~/.var/app/net.lutris.Lutris and ~/Games, and cannot see the rest of your
# home directory. See docs/gaming.md for what the jail does and doesn't stop.
# The Miami Wind theming inside the sandbox is in home/flatpak-theme.nix.
{ username, ... }:
let
  lutris = "net.lutris.Lutris";
in
{
  # Flathub itself and the weekly update timer come from flatpak.nix.
  services.flatpak.packages = [
    {
      appId = lutris;
      origin = "flathub";
    }
    # Graphics inside the sandbox. Flatpak apps use Mesa from the Flathub
    # runtime, not the host's, and pull in the 64-bit build
    # (org.freedesktop.Platform.GL.default) on their own. The 32-bit build
    # (radeonsi + RADV for i386), which 32-bit Windows games and DXVK need,
    # isn't downloaded automatically for Lutris, so install it here. The
    # branch follows the freedesktop runtime under Lutris's GNOME runtime
    # (GNOME 49 = 25.08); bump it with Lutris's runtime
    # (`flatpak info net.lutris.Lutris` shows it).
    {
      appId = "org.freedesktop.Platform.GL32.default//25.08";
      origin = "flathub";
    }
  ];

  # Tighten Flathub's default permissions for Lutris. Anything not listed
  # keeps the manifest default; entries prefixed with "!" revoke a permission.
  services.flatpak.overrides.${lutris} = {
    Context = {
      filesystems = [
        # Flathub gives Lutris your whole home directory. Take it away and
        # give back only ~/Games: the default install location, where to
        # drop installers (GOG .exe/.sh files and the like), and the one
        # directory it shares with Flatpak Steam (steam.nix).
        "!home"
        "~/Games:create"
        # Removable drives, and Flatpak Steam's own data (its logins and
        # config; the games themselves are in ~/Games).
        "!/media"
        "!/run/media"
        "!~/.var/app/com.valvesoftware.Steam"
      ];
      # X11 stays: Wine and most games are X11-only and run under Xwayland.
      # Only other Xwayland windows are visible to them; native Wayland apps
      # (alacritty, Firefox, Element) are not.
      # --device=all also stays: controllers and wheels need the raw
      # hidraw/input devices.
    };
    "Session Bus Policy" = {
      # org.freedesktop.Flatpak lets an app run any command *outside* the
      # sandbox (flatpak-spawn --host). Flathub grants it to Lutris; with it,
      # the jail is no jail at all. It is also how Lutris's built-in Steam
      # runner starts Flatpak Steam, so Steam games are launched through a
      # steam:// link instead (docs/gaming.md).
      "org.freedesktop.Flatpak" = "none";
    };
    "System Bus Policy" = {
      # Wine uses UDisks2 to list (and mount) drives; games don't need it.
      "org.freedesktop.UDisks2" = "none";
    };
  };

  # udev rules so the sandbox can use Steam Controllers, DualShock/DualSense,
  # Switch Pro and Valve Index hardware (MIT; not the unfree steam package).
  hardware.steam-hardware.enable = true;

  # Feral GameMode on the host; sandboxed games reach it through the
  # xdg-desktop-portal GameMode portal. Tick "Enable Feral GameMode" in a
  # game's Lutris system options to use it.
  programs.gamemode.enable = true;
  users.users.${username}.extraGroups = [ "gamemode" ];
}
