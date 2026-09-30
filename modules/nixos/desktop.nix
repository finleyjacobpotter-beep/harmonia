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

  # Mesa: radeonsi (OpenGL) and RADV (Vulkan) for AMD, plus Intel and
  # nouveau. enable32Bit adds the i686 builds, which 32-bit native Linux
  # games and Wine need. Flatpak apps don't use these: they bring their own
  # Mesa (see modules/nixos/gaming.nix).
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.upower.enable = true;

  # Portals: wlr for screen sharing (enabled by programs.sway), gtk for file
  # pickers / settings — required for flatpak apps such as Zen.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # vulkaninfo / vkcube and glxinfo / eglinfo, to check the drivers.
  environment.systemPackages = with pkgs; [
    vulkan-tools
    mesa-demos
  ];

  programs.dconf.enable = true;
  services.gnome.gnome-keyring.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };
}
