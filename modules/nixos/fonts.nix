# Departure Mono (Nerd Font patched) everywhere.
{ pkgs, palette, ... }:
{
  fonts = {
    enableDefaultPackages = false;
    # Exposes /run/current-system/sw/share/X11/fonts (used by flatpak apps).
    fontDir.enable = true;
    packages = with pkgs; [
      nerd-fonts.departure-mono
      noto-fonts-color-emoji # fallback for emoji only
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ palette.font.mono ];
        sansSerif = [ palette.font.name ];
        serif = [ palette.font.name ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
