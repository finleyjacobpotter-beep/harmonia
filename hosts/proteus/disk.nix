# Proteus's disk, for disko: GPT on /dev/vda with a 1 MiB BIOS boot
# partition for GRUB, a 512 MiB ESP (unused under BIOS, but lets the same
# disk boot if the droplet is ever moved to UEFI) and ext4 for the rest.
# nixos-anywhere wipes the disk and creates this before installing.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/vda";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02"; # BIOS boot, for GRUB's core image
        };
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
