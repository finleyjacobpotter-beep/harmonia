# Fan control. The AMD GPU's fan curve is software (LACT); case and CPU fans
# belong to the motherboard, so set their curves in the BIOS (docs/fans.md).
{ pkgs, ... }:
{
  # LACT: a daemon plus GUI (`lact`) for AMD GPU fan curves, clocks and power
  # limits. Set a curve in the GUI's Thermals tab; the daemon saves it to
  # /etc/lact/config.yaml and reapplies it on every boot. To make it part of
  # this flake instead, copy that file's contents into `services.lact.settings`
  # (the file then becomes read-only).
  services.lact.enable = true;

  # RDNA 3 and newer (RX 7000/9000) only allow a custom fan curve with the
  # amdgpu overdrive bit set. Sets amdgpu.ppfeaturemask; the kernel reports
  # itself as tainted with it, which is harmless.
  hardware.amdgpu.overdrive.enable = true;

  # `sensors` to read temperatures and fan speeds.
  environment.systemPackages = [ pkgs.lm_sensors ];
}
