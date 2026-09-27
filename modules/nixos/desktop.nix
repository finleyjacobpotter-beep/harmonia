# Sway session, login, audio, portals and system-wide Miami Wind bits.
{
  pkgs,
  palette,
  ...
}:
let
  p = palette;
in
{
  # The sway binary, PAM (swaylock), polkit and the wlr portal come from the
  # NixOS module; the sway *config* lives in home/sway.nix.
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      swaylock
      swayidle
      wl-clipboard
      grim
      slurp
      brightnessctl
      playerctl
      pavucontrol
    ];
  };

  # tuigreet on the console, coloured with the palette's ANSI slots.
  services.greetd = {
    enable = true;
    settings.default_session = {
      user = "greeter";
      command = builtins.concatStringsSep " " [
        "${pkgs.tuigreet}/bin/tuigreet"
        "--time"
        "--remember"
        "--asterisks"
        "--greeting 'harmonia'"
        "--theme 'border=magenta;text=white;prompt=cyan;time=magenta;action=blue;button=yellow;container=black;input=cyan'"
        "--cmd sway"
      ];
    };
  };

  # Virtual console palette = Miami Wind ANSI colours.
  console.colors = map p.strip p.ansi;

  security.polkit.enable = true;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  hardware.graphics.enable = true;
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.upower.enable = true;

  # Portals: wlr for screen sharing (enabled by programs.sway), gtk for file
  # pickers / settings — required for flatpak apps such as Zen.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  programs.dconf.enable = true;
  services.gnome.gnome-keyring.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };
}
