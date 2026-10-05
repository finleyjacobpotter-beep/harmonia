# Laptop bits: Wi-Fi, suspend on lid close, power profiles.
#
# Wi-Fi goes through NetworkManager (enabled in hosts/base.nix, with
# wpa_supplicant behind it): Super+o n opens nmtui to pick a network, and
# `nmcli device wifi connect <SSID> --ask` does the same from a shell. Saved
# networks live in /etc/NetworkManager/system-connections and survive
# rebuilds. The bar's network module shows the Wi-Fi icon when the default
# route is wireless.
{ pkgs, ... }:
{
  # Firmware for Wi-Fi and Bluetooth cards (Intel iwlwifi, Realtek, MediaTek,
  # Atheros): without it most laptop wireless chips don't come up at all.
  hardware.enableRedistributableFirmware = true;
  # Lets the card use the channels and transmit power allowed where you are.
  hardware.wirelessRegulatoryDatabase = true;

  # Close the lid: suspend, also on mains power; docked (external display
  # connected): keep running. swayidle locks the screen before sleeping
  # (home/sway.nix).
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  # Power saver / balanced / performance, switched with `powerprofilesctl`.
  services.power-profiles-daemon.enable = true;

  environment.systemPackages = with pkgs; [
    # `iw dev`, `iw dev wlan0 link`: what the card sees and its signal.
    iw
    # `sudo powertop`: what is using the battery.
    powertop
  ];
}
