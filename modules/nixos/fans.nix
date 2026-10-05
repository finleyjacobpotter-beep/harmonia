# Fan control. The AMD GPU's fan curve is software (LACT); case and CPU fans
# belong to the motherboard, so set their curves in the BIOS (docs/fans.md).
{ pkgs, ... }:
let
  lactApp = "io.github.ilya_zlobintsev.LACT";
in
{
  # LACT's daemon has to run on the host as root to write the GPU's fan
  # curve; it saves what you set to /etc/lact/config.yaml and reapplies it on
  # every boot. To make the curve part of this flake instead, copy that file's
  # contents into `services.lact.settings` (the file then becomes read-only).
  services.lact = {
    enable = true;
    # Daemon and `lact` CLI only: the GUI is the Flatpak below. Dropping the
    # desktop entry keeps a single LACT in fuzzel.
    package = pkgs.symlinkJoin {
      name = "lact-daemon-${pkgs.lact.version}";
      paths = [ pkgs.lact ];
      postBuild = "rm -rf $out/share/applications";
    };
  };

  # The GUI from Flathub, themed like the desktop by home/flatpak-theme.nix.
  # Flathub's build is the same LACT release (0.10.1) as nixpkgs' daemon.
  harmonia.apps.${lactApp} = {
    name = "lact";
    wayland = true;
    # It only needs the daemon's socket (/run/lactd.sock, from the manifest)
    # and the GPU for its info page. Flathub also grants it
    # org.freedesktop.Flatpak, to install the daemon on the host with
    # flatpak-spawn; NixOS runs the daemon, so that escape is revoked.
    sandbox = {
      "Session Bus Policy" = {
        "org.freedesktop.Flatpak" = "none";
      };
      Context.shared = [ "!ipc" ];
    };
  };

  # RDNA 3 and newer (RX 7000/9000) only allow a custom fan curve with the
  # amdgpu overdrive bit set. Sets amdgpu.ppfeaturemask; the kernel reports
  # itself as tainted with it, which is harmless.
  hardware.amdgpu.overdrive.enable = true;

  # `sensors` to read temperatures and fan speeds; `rocm-smi` for the AMD
  # GPU's temperature, fan, clocks, power and VRAM use (MIT; no ROCm runtime
  # needed, it reads the amdgpu driver's sysfs files).
  environment.systemPackages = [
    pkgs.lm_sensors
    pkgs.rocmPackages.rocm-smi
  ];
}
