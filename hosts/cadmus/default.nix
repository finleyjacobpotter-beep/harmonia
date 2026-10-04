# cadmus, the laptop: a Lenovo ThinkPad E14 Gen 2 with harmonia's setup (same
# desktop, apps and microVMs), plus Wi-Fi, lid and power handling and
# ThinkPad fan control.
{ inputs, ... }:
let
  # The E14 Gen 2 came with either an Intel (Core i5-1135G7 / i7-1165G7) or
  # an AMD (Ryzen 5 4500U / 7 4700U) CPU. Set this to yours: `lscpu` says.
  cpu = "intel";
in
{
  imports = [
    ./hardware-configuration.nix
    ../common.nix
    ../../modules/nixos/laptop.nix
    ../../modules/nixos/thinkpad.nix
    # nixos-hardware's E14 Gen 2 profile: CPU microcode and graphics driver,
    # TrackPoint, SSD trim and native backlight control.
    {
      intel = inputs.nixos-hardware.nixosModules.lenovo-thinkpad-e14-intel-gen2;
      # The AMD profile is the Gen 2's (Ryzen 4000); it also keeps the IOMMU in
      # software mode, which amdgpu needs on BIOS versions before 1.13.
      amd = inputs.nixos-hardware.nixosModules.lenovo-thinkpad-e14-amd;
    }
    .${cpu}
  ];
}
